#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Moose::More;

use WWW::eNom::Role::Command::Domain::Transfer;

use Readonly;
Readonly my $CLASS => 'WWW::eNom::Role::Command::Domain::Transfer';

subtest "$CLASS is a well formed object" => sub {
    meta_ok( $CLASS );
    does_ok( $CLASS, 'WWW::eNom::Role::ParseDomain' );
};

subtest "$CLASS has the correct attributes" => sub {
    has_attribute_ok( $CLASS, 'order_id' );
    has_attribute_ok( $CLASS, 'name' );
    has_attribute_ok( $CLASS, 'status' );
    has_attribute_ok( $CLASS, 'status_id' );
    has_attribute_ok( $CLASS, 'is_locked' );
    has_attribute_ok( $CLASS, 'is_auto_renew' );
    has_attribute_ok( $CLASS, 'use_existing_contacts' );
    has_attribute_ok( $CLASS, 'registrant_contact' );
    has_attribute_ok( $CLASS, 'admin_contact' );
    has_attribute_ok( $CLASS, 'technical_contact' );
    has_attribute_ok( $CLASS, 'billing_contact' );
};

subtest "$CLASS has the correct predicates" => sub {
    has_method_ok( $CLASS, 'has_registrant_contact' );
    has_method_ok( $CLASS, 'has_admin_contact' );
    has_method_ok( $CLASS, 'has_technical_contact' );
    has_method_ok( $CLASS, 'has_billing_contact' );
};

subtest "$CLASS has the correct methods" => sub {
    has_method_ok( $CLASS, 'construct_from_response' );
};

done_testing;
