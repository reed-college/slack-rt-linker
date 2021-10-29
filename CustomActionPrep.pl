# clear out the timestamp cf to allow messages to post to new channels when a ticket is moved to a different queue that also has this scrip enabled.
# but not if transaction is On Owner Change
my $field = $self->TransactionObj->Field;
my $type = $self->TransactionObj->Type;

# On Owner Change
unless ( $field eq "Owner" && $type eq "Set" ){
    $self->TicketObj->AddCustomFieldValue( Field =>"slack_timestamp", Value => '' );
}

return 1;
