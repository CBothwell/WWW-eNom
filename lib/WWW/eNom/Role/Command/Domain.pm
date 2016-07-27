package WWW::eNom::Role::Command::Domain;

use strict;
use warnings;

use Moose::Role;
use MooseX::Params::Validate;

use WWW::eNom::Types qw( Bool DomainName );

use WWW::eNom::Domain;

use DateTime::Format::DateParse;
use Mozilla::PublicSuffix qw( public_suffix );
use Try::Tiny;
use Carp;

requires 'submit', 'get_contacts_by_domain_name';

# VERSION
# ABSTRACT: Domain Related Operations

sub get_domain_by_name {
    my $self = shift;
    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );

    return try {
        my $response = $self->submit({
            method => 'GetDomainInfo',
            params => {
                Domain => $domain_name,
            }
        });

        if( $response->{ErrCount} > 0 ) {
            if( grep { $_ eq 'Domain name not found' } @{ $response->{errors} } ) {
                croak 'Domain not found in your account';
            }

            croak 'Unknown error';
        }

        if( !exists $response->{GetDomainInfo} ) {
            croak 'Response did not contain domain info';
        }

        return WWW::eNom::Domain->construct_from_response(
            domain_info   => $response->{GetDomainInfo},
            is_auto_renew => $self->get_is_domain_auto_renew_by_name( $domain_name ),
            is_locked     => $self->get_is_domain_locked_by_name( $domain_name ),
            name_servers  => $self->get_domain_name_servers_by_name( $domain_name ),
            contacts      => $self->get_contacts_by_domain_name( $domain_name ),
            created_date  => $self->get_domain_created_date_by_name( $domain_name ),
        );
    }
    catch {
        croak $_;
    };
}

sub get_is_domain_locked_by_name {
    my $self = shift;
    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );

    return try {
        my $response = $self->submit({
            method => 'GetRegLock',
            params => {
                Domain => $domain_name,
            }
        });

        if( $response->{ErrCount} > 0 ) {
            if( $response->{RRPText} =~ m/Command blocked/ ) {
                croak 'Domain owned by someone else';
            }

            if( $response->{RRPText} =~ m/Object does not exist/ ) {
                croak 'Domain is not registered';
            }

            croak $response->{RRPText};
        }

        if( !exists $response->{'reg-lock'} ) {
            croak 'Response did not contain lock data';
        }

        return !!$response->{'reg-lock'};
    }
    catch {
        croak $_;
    };
}

sub enable_domain_lock_by_name {
    my $self            = shift;
    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );

    return $self->_set_domain_locking(
        domain_name => $domain_name,
        is_locked   => 1,
    );
}

sub disable_domain_lock_by_name {
    my $self            = shift;
    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );

    return $self->_set_domain_locking(
        domain_name => $domain_name,
        is_locked   => 0,
    );
}

sub _set_domain_locking {
    my $self     = shift;
    my ( %args ) = validated_hash(
        \@_,
        domain_name => { isa => DomainName },
        is_locked   => { isa => Bool },
    );

    return try {
        my $response = $self->submit({
            method => 'SetRegLock',
            params => {
                Domain          => $args{domain_name},
                UnlockRegistrar => ( !$args{is_locked} ? 1 : 0 ),
            }
        });

        if( $response->{ErrCount} > 0 ) {
            if( grep { $_ eq 'Domain name not found' } @{ $response->{errors} } ) {
                croak 'Domain not found in your account';
            }

            if( grep { $_ =~ m/domain is already/ } @{ $response->{errors} } ) {
                # NO OP, what I asked for is already done
            }
        }

        return $self->get_domain_by_name( $args{domain_name} );
    }
    catch {
        croak "$_";
    };
}

sub get_domain_name_servers_by_name {
    my $self = shift;
    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );

    return try {
        my $response = $self->submit({
            method => 'GetDNS',
            params => {
                Domain => $domain_name,
            }
        });

        if( $response->{ErrCount} > 0 ) {
            if( grep { $_ eq 'Domain name not found' } @{ $response->{errors} } ) {
                croak 'Domain not found in your account';
            }

            croak 'Unknown error';
        }

        if( !exists $response->{dns} ) {
            croak 'Response did not contain nameserver data';
        }

        return $response->{dns};
    }
    catch {
        croak $_;
    };
}

sub get_is_domain_auto_renew_by_name {
    my $self = shift;
    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );

    return try {
        my $response = $self->submit({
            method => 'GetRenew',
            params => {
                Domain => $domain_name,
            }
        });

        if( $response->{ErrCount} > 0 ) {
            if( grep { $_ eq 'Domain name not found' } @{ $response->{errors} } ) {
                croak 'Domain not found in your account';
            }

            croak 'Unknown error';
        }

        if( !exists $response->{'auto-renew'} ) {
            croak 'Response did not contain renewal data';
        }

        return !!$response->{'auto-renew'};
    }
    catch {
        croak $_;
    };
}

sub enable_domain_auto_renew_by_name {
    my $self = shift;
    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );

    return $self->_set_domain_auto_renew({
        domain_name   => $domain_name,
        is_auto_renew => 1,
    });
}

sub disable_domain_auto_renew_by_name {
    my $self = shift;
    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );

    return $self->_set_domain_auto_renew({
        domain_name   => $domain_name,
        is_auto_renew => 0,
    });
}

sub _set_domain_auto_renew {
    my $self     = shift;
    my ( %args ) = validated_hash(
        \@_,
        domain_name   => { isa => DomainName },
        is_auto_renew => { isa => Bool },
    );

    return try {
        my $response = $self->submit({
            method => 'SetRenew',
            params => {
                Domain    => $args{domain_name},
                RenewFlag => ( $args{is_auto_renew} ? 1 : 0 ),
            }
        });

        if( $response->{ErrCount} > 0 ) {
            if( grep { $_ eq 'Domain name not found' } @{ $response->{errors} } ) {
                croak 'Domain not found in your account';
            }
        }

        return $self->get_domain_by_name( $args{domain_name} );
    }
    catch {
        croak "$_";
    };

}

sub get_domain_created_date_by_name {
    my $self = shift;
    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );

    return try {
        my $response = $self->submit({
            method => 'GetWhoisContact',
            params => {
                Domain => $domain_name,
            }
        });

        if( $response->{ErrCount} > 0 ) {
            if( grep { $_ eq 'No results found' } @{ $response->{errors} } ) {
                croak 'Domain not found in your account';
            }

            croak 'Unknown error';
        }

        if( !exists $response->{GetWhoisContacts}{'rrp-info'}{'created-date'} ) {
            croak 'Response did not contain creation data';
        }

        return DateTime::Format::DateParse->parse_datetime( $response->{GetWhoisContacts}{'rrp-info'}{'created-date'}, 'UTC' );

    }
    catch {
        croak $_;
    };

}

# This will get uncommented when we actually implement this method
#sub enable_domain_privacy_for_domain_by_name {
#    my $self = shift;
#    my ( $domain_name ) = pos_validated_list( \@_, { isa => DomainName } );
#
#    return try {
#        my $response = $self->submit({
#            method => 'EnableServices',
#            params => {
#                Domain  => $domain_name,
#                Service => 'WPPS',
#            }
#        });
#
#        use Data::Dumper;
#        print STDERR Dumper( $response ) . "\n";
#
#        if( $response->{ErrCount} > 0 ) {
#            if( grep { $_ eq 'Domain name not found' } @{ $response->{errors} } ) {
#                croak 'Domain not found in your account';
#            }
#
#            croak 'Unknown error';
#        }
#
#        return $self->get_domain_by_name( $domain_name );
#    }
#    catch {
#        croak $_;
#    };
#}

1;

__END__

=pod

=head1 NAME

WWW::eNom::Role::Command::Domain - Domain Related Operations

=head1 SYNOPSIS

    use WWW::eNom;
    use WWW::eNom::Domain;

    my $api = WWW::eNom->new( ... );

    # Get a fully formed WWW::eNom::Domain object for a domain
    my $domain = $api->get_domain_by_name( 'drzigman.com' );


    # Check if a domain is locked
    if( $api->get_is_domain_locked_by_name( 'drzigman.com' ) ) {
        print "Domain is Locked!\n";
    }
    else {
        print "Domain is NOT Locked!\n";
    }

    # Lock Domain
    my $updated_domain = $api->enable_domain_lock_by_name( 'drzigman.com' );

    # Unlock Domain
    my $updated_domain = $api->disable_domain_lock_by_name( 'drzigman.com' );


    # Get domain authoritative nameservers
    for my $ns ( $api->get_domain_name_servers_by_name( 'drzigman.com' ) ) {
        print "Nameserver: $ns\n";
    }


    # Get auto renew status
    if( $api->get_is_domain_auto_renew_by_name( 'drzigman.com' ) ) {
        print "Domain will be auto renewed!\n";
    }
    else {
        print "Domain will NOT be renewed automatically!\n";
    }

    # Enable domain auto renew
    my $updated_domain = $api->enable_domain_auto_renew_by_name( 'drzigman.com' );

    # Disable domain auto renew
    my $updated_domain = $api->disable_domain_auto_renew_by_name( 'drzigman.com' );

    # Get Created Date
    my $created_date = $api->get_domain_created_date_by_name( 'drzigman.com' );
    print "This domain was created on: " . $created_date->ymd . "\n";

=head1 REQUIRES

=over 4

=item submit

=item get_contacts_by_domain_name

Needed in order to construct a full L<WWW::eNom::Domain> object.

=back

=head1 DESCRIPTION

Implements domain related operations with the L<eNom|https://www.enom.com> API.

=head2 See Also

=over 4

=item For Domain Registration please see L<WWW::eNom::Role::Command::Domain::Registration>

=item For Domain Availability please see L<WWW::eNom::Role::Command::Domain::Availability>

=back

=head1 METHODS

=head2 get_domain_by_name

    my $domain = $api->get_domain_by_name( 'drzigman.com' );

At it's core, this is an Abstraction of the L<GetDomainInfo|https://www.enom.com/api/API%20topics/api_GetDomainInfo.htm> eNom API Call.  However, because this API Call does not return enough information to fully populate a L<WWW::eNom::Domain> object, internally the following additional methods are called:

=over 4

=item L<WWW::eNom::Role::Command::Domain/get_is_domain_auto_renew_by_name>

=item L<WWW::eNom::Role::Command::Domain/get_is_domain_locked_by_name>

=item L<WWW::eNom::Role::Command::Domain/get_domain_name_servers_by_name>

=item L<WWW::eNom::Role::Command::Domain/get_domain_created_date_by_name>

=item L<WWW::eNom::Role::Command::Contact/get_contacts_by_domain_name>

=back

Because of all of these API calls this method can be fairly slow (usually about a second or two).

Given a FQDN, this method returns a fully formed L<WWW::eNom::Domain> object.  If the domain does not exist in your account (either because it's registered by someone else or it's available) this method will croak.

=head2 get_is_domain_locked_by_name

    if( $api->get_is_domain_locked_by_name( 'drzigman.com' ) ) {
        print "Domain is Locked!\n";
    }
    else {
        print "Domain is NOT Locked!\n";
    }

Abstraction of the L<GetRegLock|https://www.enom.com/api/API%20topics/api_GetRegLock.htm> eNom API Call.  Given a FQDN, returns a truthy value if the domain is locked and falsey if it is not.

This method will croak if the domain is owned by someone else or if it is not registered.

=head2 enable_domain_lock_by_name

    my $updated_domain = $api->enable_domain_lock_by_name( 'drzigman.com' );

Abstraction of the L<SetRegLock|https://www.enom.com/api/API%20topics/api_SetRegLock.htm> eNom API Call.  Given a FQDN, enables the registrar lock for the provided domain.  If the domain is already locked this is effectively a NO OP.

This method will croak if the domain is owned by someone else or if it is not registered.

=head2 disable_domain_lock_by_name

    my $updated_domain = $api->disable_domain_lock_by_name( 'drzigman.com' );

Abstraction of the L<SetRegLock|https://www.enom.com/api/API%20topics/api_SetRegLock.htm> eNom API Call.  Given a FQDN, disabled the registrar lock for the provided domain.  If the domain is already unlocked this is effectively a NO OP.

This method will croak if the domain is owned by someone else or if it is not registered.

=head2 get_domain_name_servers_by_name

    for my $ns ( $api->get_domain_name_servers_by_name( 'drzigman.com' ) ) {
        print "Nameserver: $ns\n";
    }

Abstraction of the L<GetDNS|https://www.enom.com/api/API%20topics/api_GetDNS.htm> eNom API Call.  Given a FQDN, returns an ArrayRef of FQDNs that are the authoritative name servers for the specified FQDN.

This method will croak if the domain is owned by someone else or if it is not registered.

=head2 get_is_domain_auto_renew_by_name

    if( $api->get_is_domain_auto_renew_by_name( 'drzigman.com' ) ) {
        print "Domain will be auto renewed!\n";
    }
    else {
        print "Domain will NOT be renewed automatically!\n";
    }

Abstraction of the L<GetRenew|https://www.enom.com/api/API%20topics/api_GetRenew.htm> eNom API Call.  Given a FQDN, returns a truthy value if auto renew is enabled for this domain (you want eNom to automatically renew this) or a falsey value if auto renew is not enabled for this domain.

This method will croak if the domain is owned by someone else or if it is not registered.

=head2 enable_domain_auto_renew_by_name

    my $updated_domain = $api->enable_domain_auto_renew_by_name( 'drzigman.com' );

Abstraction of the L<SetRenew|https://www.enom.com/api/API%20topics/api_SetRenew.htm> eNom API Call.  Given a FQDN, enables auto renew for the provided domain.  If the domain is already set to auto renew this is effectively a NO OP.

This method will croak if the domain is owned by someone else or if it is not registered.

=head2 disable_domain_auto_renew_by_name

    my $updated_domain = $api->disable_domain_auto_renew_by_name( 'drzigman.com' );

Abstraction of the L<SetRenew|https://www.enom.com/api/API%20topics/api_SetRenew.htm> eNom API Call.  Given a FQDN, disables auto renew for the provided domain.  If the domain is already set not to auto renew this is effectively a NO OP.

This method will croak if the domain is owned by someone else or if it is not registered.

=head2 get_domain_created_date_by_name

    my $created_date = $api->get_domain_created_date_by_name( 'drzigman.com' );

    print "This domain was created on: " . $created_date->ymd . "\n";

Abstraction of the L<GetWhoisContact|https://www.enom.com/api/API%20topics/api_GetWhoisContact.htm> eNom API Call.  Given a FQDN, returns a L<DateTime> object representing when this domain registration was created.

This method will croak if the domain is owned by someone else or if it is not registered.

=cut
