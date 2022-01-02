package Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;

use Modern::Perl;

use base qw(Koha::Plugins::Base);
use C4::Context;
use Cwd qw(abs_path);

use Koha::Authorities;
use C4::AuthoritiesMarc;

use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI;

use Mojo::JSON qw(decode_json);;

our $VERSION = "0.31";

our $metadata = {
    name            => 'MungeRecord4Onleihe Plugin',
    author          => 'Mark Hofstetter',
    date_authored   => '2021-03-20',
    date_updated    => "2021-10-24",
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

## sub munge_record {
##     my ( $self, $params ) = @_;
##     my $record = $params->{record};
##     my $onleihe_id = $self->retrieve_data('OnleiheId');
##     return $record unless $record->field("003")->data() eq $onleihe_id;
##     my $patron = $params->{patron};
##     my $library_data = { Language => 'de', AgencyId => $self->retrieve_data('AgencyId') };
##     my $urldata = C4::Context->preference('OPACBaseURL') . '/cgi-bin/koha/opac-user.pl';
##     # use Data::Dumper::Concise; print Dumper $patron;
##     # XXX if possible check if book is already issued
##     if ($patron) {
##         my $onleihe = Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI->new($patron, $library_data);
##         $urldata = $onleihe->get_checkout_url($record);
##         $record->field("856")->update('j' => $urldata);
##     } else {
##         $record->field("856")->update('z' => 'Bitte einloggen zum entlehnen');
##     }
##     
##     # my $field856 = $record->field("856");
##     # $record->delete_field($field856);
##     # $field856 = $record->field("856");
##     # $record->delete_field($field856);
## 
## 
##     return $record;
## }

sub opac_head {
    my ( $self ) = @_;
    return; # explicitly return nothing, to prevent "1" showing up in output
}

sub opac_js {
    my ( $self ) = @_;
    my $agency_id = $self->retrieve_data('AgencyId') ;
    my $js = "<script> var agency_id = '$agency_id' \n";
    $js .= <<'JS';
    var lang = 'de';
    var page = $('body').attr('ID');
    var borrowernumber = $('.loggedinusername').data('borrowernumber');
    if (borrowernumber) {
        $(function(e) {
                var ajaxData = { 'patron_id': borrowernumber };
                $.ajax({
                  url: '/api/v1/contrib/mungerecord4onleihe/synccheckouts',
                type: 'GET',
                // dataType: 'json',
                data: ajaxData,
            })
            .done(function(data) {
                // console.log('synced' + data);
                // console.log(data);
            })
            .error(function(data) {
                console.log('sync error');
            });
        });
    } // run only for logged in user
    else {
        // console.log('no sync');
    }
    
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
            Branchcode      => $self->retrieve_data('Branchcode'),
            OnleiheId       => $self->retrieve_data('OnleiheId'),
        );

        $self->output_html( $template->output() );
    }
    else {
        $self->store_data(
            {
            Language        => $cgi->param('Language'),
            AgencyId        => $cgi->param('AgencyId'),
            Branchcode      => $cgi->param('Branchcode'),
            OnleiheId       => $cgi->param('OnleiheId'),
            }
        );
        $self->go_home();
    }
}
