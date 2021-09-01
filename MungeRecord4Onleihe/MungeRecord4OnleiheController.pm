package Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::MungeRecord4OnleiheController;

use Mojo::Base 'Mojolicious::Controller';

use C4::Context;
use C4::Debug;
use C4::Output qw(:html :ajax pagination_bar);

use HTTP::Request;
use LWP::UserAgent;

use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI;

# use JSON;

my $header = ['Content-Type' => 'application/json; charset=UTF-8'];

use Mojo::JSON qw(decode_json encode_json);

sub status {
    my $c = shift->openapi->valid_input or return;
    my $id = $c->validation->param('id');

    my $patron = { user => 'bla', id => $id};

    return $c->render( status => 200, openapi => {
        id => $id,
    } );
}

sub synccheckouts {
    my $c = shift->openapi->valid_input or return;
    my $patron_id = $c->validation->param('patron_id');
    my $agency_id = $c->validation->param('agency_id');
    return $c->render( status => 200, openapi => {
        id => $patron_id,
    } );
}

1;

