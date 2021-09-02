package Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;

use Modern::Perl;

use base qw(Koha::Plugins::Base);
use C4::Context;
use Cwd qw(abs_path);

use Koha::Authorities;
use C4::AuthoritiesMarc;

use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI;


use Mojo::JSON qw(decode_json);;

our $VERSION = "0.3";

our $metadata = {
    name            => 'MungeRecord4Onleihe Plugin',
    author          => 'Mark Hofstetter',
    date_authored   => '2021-03-20',
    date_updated    => "2021-08-24",
    minimum_version => '19.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'this plugin changes the Koha Record for Onleihe depending if the user is logged in or not'
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);
    $self->{cgi} = CGI->new();

    return $self;
}

sub api_routes {
    my ( $self, $args ) = @_;
    my $spec_str = $self->mbf_read('openapi.json');
    my $spec = decode_json($spec_str);
    return $spec;
}

sub api_namespace {
    my ( $self ) = @_;
    return 'mungerecord4onleihe';
}

sub munge_record {
    my ( $self, $params ) = @_;
    my $record = $params->{record};
    return $record unless $record->field("003")->data() eq 'DE-Wi27';
    my $patron = $params->{patron};
    my $library_data = { Language => 'de', AgencyId => $self->retrieve_data('AgencyId') };
    my $urldata = C4::Context->preference('OPACBaseURL') . '/cgi-bin/koha/opac-user.pl';
    # use Data::Dumper::Concise; print Dumper $patron;
    # XXX if possible check if book is already issued
    if ($patron) {
        my $onleihe = Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI->new($patron, $library_data);
        $urldata = $onleihe->get_checkout_url($record);
    } else {
        [$record->field("856")]->[2]->update('z' => 'Bitte einloggen zum entlehnen');
    }

    # say $record->field("001")->data();
    [$record->field("856")]->[2]->update('u' => $urldata);

    return $record;
}

sub opac_head {
    my ( $self ) = @_;
}

sub opac_js {
    my ( $self ) = @_;

    my $agency_id = $self->retrieve_data('AgencyId') ;
    my $js = "<script> var agency_id = '$agency_id' \n";
    $js .= <<'JS';
    var lang = 'de';
    var page = $('body').attr('ID');
    var borrowernumber = $('.loggedinusername').data('borrowernumber');
    console.log('opac: ', page, borrowernumber, agency_id);
    $(function(e) {
            var ajaxData = { 'patron_id': borrowernumber,
                             'agency_id': agency_id };
            $.ajax({
              url: '/api/v1/contrib/mungerecord4onleihe/synccheckouts',
            type: 'GET',
            dataType: 'json',
            data: ajaxData,
        })
        .done(function(data) {
            console.log('synced' + data['id']);
        })
        .error(function(data) {
            console.log('sync error');
        });
    });
    </script>
JS

    return $js;
}


sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            Language        => $self->retrieve_data('Language'),
            AgencyId        => $self->retrieve_data('AgencyId'),
        );

        $self->output_html( $template->output() );
    }
    else {
        $self->store_data(
            {
                Language                => $cgi->param('Language'),
                AgencyId                => $cgi->param('AgencyId'),
            }
        );
        $self->go_home();
    }
}
