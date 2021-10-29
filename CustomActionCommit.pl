## slack-rt-linker
## https://github.com/reed-college/slack-rt-linker

## Script must be Applied to whichever queues you want to integrate
## Invite @RT to whatever slack channels you expect it to post to

use IO::Socket::SSL;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use JSON;

##################################
## Configure required variables:
my $slackURL = 'https://YOUR-SLACK-DOMAIN.slack.com/api/';
my $rtURL = 'https://YOUR-RT-DOMAIN/Ticket/Display.html';

# slack app Bearer token:
my $token = "Bearer YOUR-SLACK-BEARER-TOKEN";

# RT's "slack_timestamp" custom field that you need to create
my $rtSlackTimestampCF = "slack_timestamp";

##################################
## Configure Queue to Channel mapping:
## This allows one set of scrips to function against all of your queues using a single slack app.
## You can get your channel id by visiting slack in a browser and viewing a link to your channel

# get queue of this ticket:
my $queue = $self->TicketObj->QueueObj->Name;

my $channel = "";
if ($queue eq "RT-QUEUE1") {
    $channel = "SLACK-CHANNEL-ID1";
} elsif ($queue eq "RT-QUEUE2") {
    $channel = "SLACK-CHANNEL-ID2";
} elsif ($queue eq "RT-QUEUE3") {
    $channel = "SLACK-CHANNEL-ID3";
} elsif ($queue eq "tis-issues") {
    $channel = "RT-QUEUE4";
}
################################


##########  You should not need to modify anything below this, but obviously feel free to make it your own! ##################

my $ticketID = $self->TicketObj->id;
my $ticketURL = '<'.$rtURL.'?id='.$ticketID.'|#'.$ticketID.'>';
my $ticketSubject = $self->TicketObj->Subject;
my $requestorName = "";
$requestorName = eval { $self->TicketObj->Requestors->UserMembersObj->First->RealName };
my $owner = $self->TicketObj->OwnerObj->Name;

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

my $data = {channel => $channel, text => $requestorName.' ['.$ticketURL.' '.$ticketSubject.'] '.$ticketActionURL.' '.$stealText};

# Are we posting a new message or updating an existing one?
my $slackTimestampCFValue = $self->TicketObj->FirstCustomFieldValue('slack_timestamp');
if ( defined $slackTimestampCFValue ) {
    $slackURL .= "chat.update";
    $data->{'ts'} = $slackTimestampCFValue;
} else { 
    $slackURL .= "chat.postMessage";
}

my $header = ['Content-type' => 'application/json', 'Authorization' => $token];
my $encoded_data = encode_json($data);

my $r = HTTP::Request->new('POST', $slackURL, $header, $encoded_data); 
my $ua = LWP::UserAgent->new;
$ua->timeout(15);

my $resp = $ua->request($r);
if ($resp->is_success) {
    RT::Logger->debug('Posted to slack!');
} else {
    RT::Logger->debug("Failed post to slack, status is:" . $resp->status_line);
}

my $decoded_resp = $resp->decoded_content;
#print $decoded_resp;
my $json_decoded_resp = decode_json($decoded_resp);

# extract slack message timestamp
my $ts = $json_decoded_resp->{'ts'};

# Record the slack timestamp to RT
my ($status, $msg) = $self->TicketObj->AddCustomFieldValue( Field =>$rtSlackTimestampCF, Value => $ts );

return 1;
