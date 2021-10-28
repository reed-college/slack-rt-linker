#clear out the timestamp cf to allow messages to post to new channels when a ticket is moved to a different queue that also has this scrip enabled.
$self->TicketObj->AddCustomFieldValue( Field =>"slack_timestamp", Value => '' );
return 1;
