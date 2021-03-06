#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use String::Random qw( random_string );

use FindBin;
use lib "$FindBin::Bin/../../../lib";
use Test::WWW::eNom qw( create_api );
use Test::WWW::eNom::Domain qw( create_domain $UNREGISTERED_DOMAIN $NOT_MY_DOMAIN );

subtest 'Enable Auto Renew On Unregistered Domain' => sub {
    my $api = create_api();

    throws_ok {
        $api->enable_domain_auto_renew_by_name( $UNREGISTERED_DOMAIN->name );
    } qr/Domain not found in your account/, 'Throws on unregistered domain';
};

subtest 'Enable Auto Renew On Domain Registered To Someone Else' => sub {
    my $api = create_api();

    throws_ok {
        $api->enable_domain_auto_renew_by_name( $NOT_MY_DOMAIN->name );
    } qr/Domain not found in your account/, 'Throws on domain registered to someone else';
};

subtest 'Enable Auto Renew On Domain With Auto Renew Off' => sub {
    my $api    = create_api();
    my $domain = create_domain( is_auto_renew => 0 );

    my $retrieved_domain;
    lives_ok {
        $retrieved_domain = $api->enable_domain_auto_renew_by_name( $domain->name );
    } 'Lives through enabling auto renew';

    cmp_ok( $domain->is_auto_renew, '==', 0, 'Original domain was not auto renew' );
    cmp_ok( $retrieved_domain->is_auto_renew, '==', 1, 'Domain now correctly auto renew' );
};

subtest 'Enable Auto Renew On Domain With Auto Renew On' => sub {
    my $api    = create_api();
    my $domain = create_domain( is_auto_renew => 1 );

    my $retrieved_domain;
    lives_ok {
        $retrieved_domain = $api->enable_domain_auto_renew_by_name( $domain->name );
    } 'Lives through enabling auto renew';

    cmp_ok( $domain->is_auto_renew, '==', 1, 'Original domain was auto renew' );
    cmp_ok( $retrieved_domain->is_auto_renew, '==', 1, 'Domain now correctly auto renew' );
};

done_testing;
