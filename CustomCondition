my $field = $self->TransactionObj->Field;
my $type = $self->TransactionObj->Type;

RT::Logger->debug("Scrip 103 transactionObj Field & Type are: ".$field." and ".$type);

# On Create
if ( $type eq "Create" ){
    return 1;
}

# On Queue Change
if ( $field eq "Queue" && $type eq "Set" ){
        return 1;
}

# On Owner Change
if ( $field eq "Owner" && $type eq "Set" ){
        return 1;
}
