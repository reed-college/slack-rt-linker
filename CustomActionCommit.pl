## slack-rt-linker
## https://github.com/reed-college/slack-rt-linker

## Script must be Applied to whichever queues you want to integrate
## Invite @RT to whatever slack channels you expect it to post to

use IO::Socket::SSL;
use JSON;
use RT::Queue;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

################################
## Configure required variables:
my $slackURL = 'https://YOUR-SLACK-DOMAIN.slack.com/api/';
my $rtURL = 'https://YOUR-RT-DOMAIN/Ticket/Display.html';

# slack app Bearer token:
my $token = "Bearer YOUR-SLACK-BEARER-TOKEN";

# RT's "slack_timestamp" custom field that you need to create and apply to queues
my $rtSlackTimestampCF = "slack_timestamp";

# get queue of this ticket:
my $queue = $self->TicketObj->QueueObj->Name;
RT::Logger->debug("RTbot Scrip - Action Commit - queue is $queue");

my $requestorEmail = "";
$requestorEmail = eval { $self->TicketObj->Requestors->UserMembersObj->First->EmailAddress };
RT::Logger->debug("RTbot Scrip - Action Commit - Requestor Email is: ".$requestorEmail);

my $ticketID = $self->TicketObj->id;
my $ticketURL = '<'.$rtURL.'?id='.$ticketID.'|#'.$ticketID.'>';
my $ticketSubject = $self->TicketObj->Subject;
my $ticketStatus = $self->TicketObj->Status;
my $requestorName = "";
$requestorName = eval { $self->TicketObj->Requestors->UserMembersObj->First->RealName };
my $owner = $self->TicketObj->OwnerObj->Name;


################################################
## Detect Queue Change
## This is a tricky transaction.  Let's grab the old queue name:
## Get the ID of the old queue from the transaction, create an object, load data into object, get the name.  It's a lot of steps but that's how this works.

my $is_queue_change = 0;
my $field = $self->TransactionObj->Field;
my $type = $self->TransactionObj->Type;
my $oldQueueName = '';

if ( defined($field) && $field eq "Queue" && $type eq "Set" ){
    $is_queue_change = 1;
    RT::Logger->debug("RTbot Scrip - queue change detected.");
    my $oldQueueID = $self->TransactionObj->OldValue;
    my $oldQueueObj = RT::Queue->new($self->TicketObj->CurrentUser);
    $oldQueueObj->Load($oldQueueID);
    $oldQueueName = $oldQueueObj->Name;
    RT::Logger->debug("RTbot Scrip - Action Commit - oldQueueName is $oldQueueName");
}
RT::Logger->debug("RTbot Scrip - queue change NOT detected."); 


#############################################################
## RT is weird about subroutines in scrips, so this is the hack that prevents:
## [warning]: Subroutine _slack_api_call redefined
## and hopefully fixes the race condition/caching issue where on queue
## change the ts is updated when viewed from the web UI, but the scrip
## is using cached info and sees it as null.  Or perhaps the real problem was that I 
## failed to disable the production script so I had two chunks of code trying to do 
## the same thing at the same time

my $slack_api_call = sub {
    my ($endpoint, $payload, $base_url, $auth_token) = @_;
    
    my $post_url = $base_url . $endpoint;
    my $header = ['Content-type' => 'application/json', 'Authorization' => $auth_token];
    my $encoded_data;
    
    eval {
        $encoded_data = encode_json($payload);
    };
    if ($@) {
        RT::Logger->debug("Failed to encode JSON payload for $endpoint: $@");
        return undef;
    }

    my $r = HTTP::Request->new('POST', $post_url, $header, $encoded_data); 
    #RT::Logger->debug("RTbot Scrip - Action Commit - HTTP request is: $post_url $header $payload $encoded_data");
    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts( verify_hostname => 1 );
    $ua->timeout(10); # 10 second timeout

    my $resp = $ua->request($r);

    if ($resp->is_success) {
        my $decoded_resp = $resp->decoded_content;
        
        if (!defined $decoded_resp || $decoded_resp eq '') {
            RT::Logger->debug("Slack API call $endpoint successful with no content.");
            return { ok => 1, ts => undef }; 
        }
        
        my $json_decoded_resp;
        eval {
            $json_decoded_resp = decode_json($decoded_resp);
        };
        if ($@) {
            RT::Logger->debug("Failed to decode JSON response from Slack ($endpoint): $@");
            return undef;
        }
        
        if (exists $json_decoded_resp->{ok} && !$json_decoded_resp->{ok}) {
             RT::Logger->debug("Slack API call $endpoint failed: $json_decoded_resp->{error}");
             return undef;
        }
        
        return $json_decoded_resp; # Success! Return the decoded JSON
        
    } else {
        RT::Logger->debug("Failed post to slack $endpoint, status is:" . $resp->status_line . " | URL was: " . $post_url);
        return undef; # Failure
    }
}; # <-- Note the semicolon here


##################################
## Configure Queue to Channel mapping:
## This allows one set of scrips to function against all of your queues using a single Slack app.
##
## Keys must match your RT Queue names exactly.
## Values are the Slack Channel IDs (e.g., C12345678). 
## You can get a channel ID by right-clicking a Slack channel name > Copy Link.

my %queue_config = (
    # --- Standard Mappings ---
    # Simple 1-to-1 mapping of RT Queue to Slack Channel
    "General" => {
        channel => "C12345678", # #general-help
    },
    "Hardware" => {
        channel => "C87654321", # #it-hardware
    },
    "Software" => {
        channel => "C87654321", # #it-software (Mapped to same channel as hardware)
    },

    # --- Advanced: Custom Text Injection ---
    # Use 'custom_text' to append specific Custom Field values to the Slack message.
    "Change Management" => {
        channel => "C99887766", # #cab-reviews
        custom_text => sub {
            my ($ticket_obj) = @_;
            
            # Example: Grab a custom field for the planned date
            my $cf_value = $ticket_obj->FirstCustomFieldValue('Implementation Date');
            
            if (defined $cf_value && $cf_value ne '') {
                return "| Scheduled: $cf_value |";
            }
            # Return undef so nothing is added if the field is empty
            return undef; 
        }
    },

    # --- Advanced: Dynamic Channel Routing ---
    # Use 'custom_logic' to programmatically decide the destination channel 
    # based on ticket criteria (e.g., Requestor, Priority, Subject).
    "Security" => {
        custom_logic => sub {
            my ($requestor_email) = @_;
            
            # Example: Route automated alerts to a noisy channel, 
            # and human reports to a discussion channel.
            if ($requestor_email eq "alert-bot\@example.com") {
                return { channel => "C11223344" }; # #security-alerts-feed
            } else {
                return { channel => "C55667788" }; # #security-ops
            }
        }
    },
);


#######################################################
## Configure Message

my %status_formatting = (
    'resolved' => { style => 'strike' }, # Puts ~ around text
    'deleted'  => { style => 'strike_skull' }, # Puts ~ around text and skull emoji
    # Add other statuses here, e.g., 'stalled' => { ... }
);

# Set default configuration based on variables at top of script
my $channel  = "";

# Look up the configuration for the current queue
my $config = $queue_config{$queue};

if (defined $config) {
    # Check if this queue uses custom logic
    if (exists $config->{custom_logic} && ref($config->{custom_logic}) eq 'CODE') {
        # Execute the custom logic sub
        # It's expected to return a hash ref, e.g., { channel => "..." }
        my $custom_config = $config->{custom_logic}->($requestorEmail);
        $channel = $custom_config->{channel} if defined $custom_config->{channel};
    } else {
        # Standard config
        $channel = $config->{channel} if exists $config->{channel};
    }

} else {
    RT::Logger->debug("RTbot Scrip - No channel mapping found for queue: $queue. No message will be sent.");
    return 1; 
}

# If, after all that, we don't have a channel, something is wrong.
unless ($channel) {
    RT::Logger->debug("RTbot Scrip - Mapping found for $queue, but no channel was resolved (check custom_logic?). No message will be sent.");
    return 1;
}

# Check for and run any custom text logic
my $customQueueText = '';
if (exists $config->{custom_text} && ref($config->{custom_text}) eq 'CODE') {
    $customQueueText = $config->{custom_text}->($self->TicketObj);
}


################################
## Defang any URLs that might appear in Subjects so that no one in slack clicks on a malicious link.  Feature requested by Pete Halatsis.
## Slack tries to be helpful by turning some text into clickable links:
## 1. Anything ending in a TLD like .com, .net, etc. becomes clickable.
## 2. Anything that includes :// becomes a link.  For example: nonsense://blah is a clickable link in slack.

RT->Logger->debug("Ticket Subject is: ".$ticketSubject);
my $ticketSubjectDefanged = $ticketSubject;

# To avoid uninitialized variable errors I switched from using $1, $2, etc to $&
$ticketSubjectDefanged =~ s/(:\/\/)|(\.edu)|(\.com)|(\.net)|(\.org)|(\.xyz)|(\.co)|(\.us)|(\.shop)|(\.cn)|(\.ru)|(\.tk)/[$&]/g;

RT->Logger->debug("Ticket Subject Defanged is: ".$ticketSubjectDefanged);


####################################
## Take or Steal

# if not owned, show Take link.  If owned, show Steal link & text
my $stealText = "";
my $rtAction = "";

if ($owner eq "Nobody"){
    $stealText = "";
    $rtAction = "Take";
} else {
    $stealText = "from ".$owner;
    $rtAction = "Steal";
}
my $ticketActionURL = '<'.$rtURL.'?Action='.$rtAction.';id='.$ticketID.'|'.$rtAction.'>';


# Build the final message text
my @message_parts;
push @message_parts, '['.$ticketStatus.']';
push @message_parts, $requestorName if (defined $requestorName && $requestorName ne '');
push @message_parts, '['.$ticketURL.' '.$ticketSubjectDefanged.']';
push @message_parts, $customQueueText if (defined $customQueueText && $customQueueText ne '');
push @message_parts, $ticketActionURL;
push @message_parts, $stealText if (defined $stealText && $stealText ne '');

my $messageText = join(' ', @message_parts);


####################################
## Apply status-based formatting
if (exists $status_formatting{$ticketStatus}) {
    my $style = $status_formatting{$ticketStatus}->{style};
    if ($style eq 'strike') {
        $messageText = '~' . $messageText . '~';
    } elsif ($style eq 'strike_skull') {
        $messageText = ':skull: ~' . $messageText . '~ :skull:';
    } elsif ($style eq 'quote') {
        $messageText = '> ' . $messageText; # Prepend blockquote marker
    }
}

######################################
## Construct the final data payload for Slack
my $data = {
    channel => $channel,
    text => $messageText
};

####################################################
## Detect new post, update, or queue change

# Supposedly this gets us a fresh view of the ticket and not whatever is cached.
# I don't think it actually solved anything and may not be necessary.
$self->TicketObj->Load( $self->TicketObj->id );

my $slackTimestampCFValue = $self->TicketObj->FirstCustomFieldValue('slack_timestamp');
my $json_resp;
if ( $is_queue_change == 1 ) {
    RT::Logger->debug("RTbot Scrip - Queue change detected, posting new message and updating the previous one.");
    
    # Post the new message to the new channel
    $json_resp = $slack_api_call->("chat.postMessage", $data, $slackURL, $token);
    
    # Update the OLD message
    my $old_config = $queue_config{$oldQueueName};
    my $old_ts = $slackTimestampCFValue;
    
    if (defined $old_config && exists $old_config->{channel} && (defined $old_ts && $old_ts ne '')) {
        my $old_channel_id = $old_config->{channel};
        RT::Logger->debug("RTbot Scrip - Attempting to delete old message $old_ts in old channel $old_channel_id");
        
        my $movedText = "~[moved] $ticketURL $ticketSubjectDefanged~";

        my $updateData = {
            channel => $old_channel_id,
            ts      => $old_ts,
            text    => $movedText
        };
        
        # We don't care about the response from this, it's "best effort".
        $slack_api_call->("chat.update", $updateData, $slackURL, $token); 
    }
} elsif ( defined $slackTimestampCFValue && $slackTimestampCFValue ne '' ) {
    RT::Logger->debug("RTbot Scrip - Timestamp already set, updating existing message.");
    $data->{'ts'} = $slackTimestampCFValue;
    $json_resp = $slack_api_call->("chat.update", $data, $slackURL, $token);
    
} else { 
    RT::Logger->debug("RTbot Scrip - Timestamp not set, posting new message.");
    $json_resp = $slack_api_call->("chat.postMessage", $data, $slackURL, $token);
}


#################################
## Process the response from the main API call

# Check if $json_resp is defined (meaning the API call was successful)
if (defined $json_resp) {
    RT::Logger->debug('RTbot Scrip - Main Slack API call successful!');
    
    # extract slack message timestamp
    my $ts = $json_resp->{'ts'};

    # We save the timestamp if:
    # 1. We got a timestamp back
    # 2. AND ( The timestamp field was blank OR this was a queue change )
    if ( $ts && ( !defined $slackTimestampCFValue || $slackTimestampCFValue eq '' || $is_queue_change == 1 ) ) {
        
        RT::Logger->debug("RTbot Scrip - Attempting to save new timestamp $ts to $rtSlackTimestampCF");
        
        # Record the slack timestamp to RT
        my ($status, $msg) = $self->TicketObj->AddCustomFieldValue( Field =>$rtSlackTimestampCF, Value => $ts );
        if (!$status) {
            RT::Logger->debug("RTbot Scrip - Failed to set $rtSlackTimestampCF custom field: $msg");
        } else {
             RT::Logger->debug("RTbot Scrip - Successfully set $rtSlackTimestampCF custom field to $ts");
        }
    } elsif (!$ts) {
        RT::Logger->debug("RTbot Scrip - Slack post successful but no timestamp (ts) was returned.");
    }
    
} else {
    RT::Logger->debug("RTbot Scrip - Main Slack API call failed.");
}

return 1;
