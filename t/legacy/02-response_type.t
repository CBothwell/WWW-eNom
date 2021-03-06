#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin/../lib/";
use Test::WWW::eNom qw( check_for_credentials $ENOM_USERNAME $ENOM_PASSWORD );

use Data::Util qw( is_hash_ref is_string );
use XML::Simple qw( XMLin );

use Readonly;
Readonly my $DOMAIN => 'enom.com';

check_for_credentials();

subtest 'Invalid Response Type' => sub {
    throws_ok {
        WWW::eNom->new({
            username => 'username',
            password => 'password',
            test     => 1,
            response_type => 'not_a_valid_response_type',
        });
    } qr/response_type must be one of/, 'Throws on invalid response type';
};

subtest 'XML Response' => sub {
    my $api;
    lives_ok {
        $api = WWW::eNom->new({
            username      => $ENOM_USERNAME,
            password      => $ENOM_PASSWORD,
            response_type => 'xml',
            test          => 1,
        });
    } 'Lives through creation of WWW::eNom Object';

    my $response;
    lives_ok {
        $response = $api->Check( Domain => $DOMAIN );
    } 'Lives through request';

    ok( is_string( $response ), 'Response is a string' );

    my $formated_response;
    lives_ok {
        $formated_response = XMLin( $response );
    } 'Lives through parsing response';

    cmp_ok( $formated_response->{DomainName}, 'eq', $DOMAIN, 'Correct DomainName' );
};

subtest 'XML Simple Response' => sub {
    my $api;
    lives_ok {
        $api = WWW::eNom->new({
            username      => $ENOM_USERNAME,
            password      => $ENOM_PASSWORD,
            response_type => 'xml_simple',
            test          => 1,
        });
    } 'Lives through creation of WWW::eNom Object';

    my $response;
    lives_ok {
        $response = $api->Check( Domain => $DOMAIN );
    } 'Lives through request';

    ok( is_hash_ref( $response ), 'Response appears to be in correct format' );
    cmp_ok( $response->{DomainName}, 'eq', $DOMAIN, 'Correct DomainName' );
};

subtest 'HTML Response' => sub {
    my $api;
    lives_ok {
        $api = WWW::eNom->new({
            username      => $ENOM_USERNAME,
            password      => $ENOM_PASSWORD,
            response_type => 'html',
            test          => 1,
        });
    } 'Lives through creation of WWW::eNom Object';

    my $response;
    lives_ok {
        $response = $api->Check( Domain => $DOMAIN );
    } 'Lives through request';

    ok( is_string( $response ), 'Response is a string' );
    like( $response, qr|DomainName: </STRONG>$DOMAIN<BR />|, 'Correct DomainName' );
};

subtest 'TEXT Response' => sub {
    my $api;
    lives_ok {
        $api = WWW::eNom->new({
            username      => $ENOM_USERNAME,
            password      => $ENOM_PASSWORD,
            response_type => 'text',
            test          => 1,
        });
    } 'Lives through creation of WWW::eNom Object';

    my $response;
    lives_ok {
        $response = $api->Check( Domain => $DOMAIN );
    } 'Lives through request';

    ok( is_string( $response ), 'Response is a string' );
    like( $response, qr|DomainName=$DOMAIN|, 'Correct DomainName' );
};

done_testing;
