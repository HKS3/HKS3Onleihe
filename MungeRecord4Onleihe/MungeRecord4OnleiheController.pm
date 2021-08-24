package Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::MungeRecord4OnleiheController;

use Mojo::Base 'Mojolicious::Controller';

use C4::Context;
use C4::Debug;
use C4::Output qw(:html :ajax pagination_bar);

use HTTP::Request;
use LWP::UserAgent;

# use JSON;

my $header = ['Content-Type' => 'application/json; charset=UTF-8'];

use Mojo::JSON qw(decode_json encode_json);

sub get {
    my $c = shift->openapi->valid_input or return;
    my $gnd_id = $c->validation->param('id');
    my ($wikipedia_url, $wikipedia_title) = gnd_redirect($gnd_id);
    my $content = get_extract($wikipedia_title);
    my $image_url = get_pageimage($wikipedia_title);

    return $c->render( status => 200, openapi => {
        content => $content,
        wikipedia_url => $wikipedia_url,
        image_url => $image_url,
    } );

}

1;
