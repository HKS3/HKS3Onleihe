package Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;

use Modern::Perl;
use Template;
use LWP::UserAgent;
use XML::XPath;
use XML::XPath::XMLParser;

use base qw(Koha::Plugins::Base);
use C4::Context;
use Cwd qw(abs_path);

use Koha::Authorities;
use C4::AuthoritiesMarc;


use Mojo::JSON qw(decode_json);;

our $VERSION = "0.2";

our $metadata = {
    name            => 'MungeRecord4Onleihe Plugin',
    author          => 'Mark Hofstetter',
    date_authored   => '2021-03-20',
    date_updated    => "2021-03-20",
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
    my ( $self, $record, $params ) = @_;
    return $record unless $record->field("003")->data() eq 'DE-Wi27';
    my $patron = $params->{patron};
    my $urldata = C4::Context->preference('OPACBaseURL') . '/cgi-bin/koha/opac-user.pl';
    # use Data::Dumper::Concise; print Dumper $patron;
    if ($patron) {
        # say $patron->cardnumber;
        # say $patron->dateofbirth;
        # say $patron->email;
        $urldata = _query_onleihe($patron, $record);
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
    my $cgi = $self->{'cgi'};
    return 1;
}

sub _query_onleihe {
    my ($patron, $record) = @_;

    my $tt = Template->new({
        INTERPOLATE  => 0,
    });

    my $vars = {
        UserID              => '3',                     # $patron->id ?
        CardId              => 'LB0000015',             # $patron->cardnumber
        DateOfBirth         => '05.02.1949',            # $patron->dateofbirth
        ItemIdentifier      => $record->field("001")->data(),
        Language            => 'de',
        AgencyId            => '392',
        EmailAddress        => $patron->email,
    };

    my $xml;
    my $request_xml = get_xml('requestitem');
    $tt->process(\$request_xml, $vars, \$xml)
        || die $tt->error(), "\n";

    my $checkout_url;
    my $ua = LWP::UserAgent->new;
    my $host = "https://ncip.onleihe.de/ncip/service/";
    my $response = $ua->post($host, Content_Type => 'application/xml', Content => $xml);
    if ($response->is_success) {
        my $xp = XML::XPath->new(xml =>  $response->decoded_content);
        $checkout_url = $xp->findvalue('/NCIPMessage/RequestItemResponse/Ext/Locality/');
    }
    else {
        $checkout_url = 'onleihe not available at the moment';
    }
    return $checkout_url;
}

sub get_xml {

my $xml_templates = {
requestitem => <<'XML',
<?xml version="1.0"?>
<NCIPMessage xmlns:ncip="http://www.niso.org/2008/ncip" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ncip:version="2.0" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_0/ncip_v2_0.xsd">
<RequestItem>
<AuthenticationInput>
<AuthenticationInputData>[% UserID %]</AuthenticationInputData>
<AuthenticationDataFormatType>text</AuthenticationDataFormatType>
<AuthenticationInputType>UserId</AuthenticationInputType>
</AuthenticationInput>
<AuthenticationInput>
<AuthenticationInputData>[% CardId %]</AuthenticationInputData>
<AuthenticationDataFormatType>text</AuthenticationDataFormatType>
<AuthenticationInputType>CardId</AuthenticationInputType>
</AuthenticationInput>
<AuthenticationInput>
<AuthenticationInputData>[% DateOfBirth %]</AuthenticationInputData>
<AuthenticationDataFormatType>text</AuthenticationDataFormatType>
<AuthenticationInputType>DateOfBirth</AuthenticationInputType>
</AuthenticationInput>
<ItemId>
<ItemIdentifierValue>[% ItemIdentifier %]</ItemIdentifierValue>
</ItemId>
<RequestType>Loan</RequestType>
<Ext>
<Language>[% Language %]</Language>
<AgencyId>[% AgencyId %]</AgencyId>
<UnstructuredAddressType>EmailAddress</UnstructuredAddressType>
<UnstructuredAddressData>[% EmailAddress %]</UnstructuredAddressData>
</Ext>
</RequestItem>
</NCIPMessage>
XML
};

    my $template = shift;
    return $xml_templates->{$template};
}
