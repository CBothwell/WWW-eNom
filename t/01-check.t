#!/usr/bin/env perl

use Test::Most tests => 1;
use Net::eNom;

my $enom = Net::eNom->new(
	username => 'resellid',
	password => 'resellpw',
	test     => 1
);
my $response = $enom->Check( Domain => 'enom.*1' );
is_deeply(
	$response->{Domain},
	[qw/enom.us/],
	'Domain check returned sensible response.'
);