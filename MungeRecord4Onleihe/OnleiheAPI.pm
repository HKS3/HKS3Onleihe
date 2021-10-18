package Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI;

use Modern::Perl;
use Template;
use LWP::UserAgent;
use XML::XPath;
use XML::XPath::XMLParser;

use Scalar::Util qw( blessed looks_like_number );

sub new {
    my ( $class, $patron, $library_data ) = @_;
    my $self = {patron => $patron};
    $self->{library_data} = $library_data;

    bless( $self, $class );
}


sub get_user_status {
    my $self = shift;

    my $xml = $self->_query_onleihe('userstatus', { });
    my $nodes = $xml->find('/NCIPMessage/LookupUserResponse/LoanedItem/');
    my @identifier_types;
    my @identifier_values;
    my @loan_list;
    foreach my $node ($nodes->get_nodelist) {
        # say STDERR  $node->find('ItemId/ItemIdentifierValue');
        my $types = $node->find('Ext/ItemIdentifierType');
        my $values = $node->find('Ext/ItemIdentifierValue');
        foreach my $type ($types->get_nodelist) {
            push @identifier_types, $type->string_value();
        }
        foreach my $value ($values->get_nodelist) {
            push @identifier_values, $value->string_value();
        }
        my %loans;
        @loans{@identifier_types} = @identifier_values;
        $loans{itemid} = $node->find('ItemId/ItemIdentifierValue')->string_value();
        $loans{ISBN} =~ s/-//g;
        push @loan_list, \%loans;
    }

    return \@loan_list;
}

sub get_checkout_url {
    my ($self, $record) = @_;
    my $xml = $self->_query_onleihe('requestitem', { ItemIdentifier => $record->field("001")->data() });
    my $checkout_url = $xml->findvalue('/NCIPMessage/RequestItemResponse/Ext/Locality/');
    return $checkout_url;
}

sub _query_onleihe {
    # my ($patron, $record) = @_;
    my ($self, $query, $add_vars) = @_;

    my $tt = Template->new({
        INTERPOLATE  => 0,
    });

    my $vars = {
        UserID              => $self->{patron}->id,
        CardId              => $self->{patron}->cardnumber,
        DateOfBirth         => $self->{patron}->dateofbirth,
        # ItemIdentifier      => $record->field("001")->data(),
        Language            => $self->{library_data}->{Language},   #  de',
        AgencyId            => $self->{library_data}->{AgencyId},         # '392',
        EmailAddress        => $self->{patron}->email,
    };

    foreach my $k (keys %$add_vars) {
        $vars->{$k} = $add_vars->{$k};
    }

    # use Data::Dumper;
    # print STDERR Dumper $vars;
    my $xml;
    my $request_xml = _get_xml($query);
    $tt->process(\$request_xml, $vars, \$xml)
        || die $tt->error(), "\n";

    my $xml_response;
    my $ua = LWP::UserAgent->new;
    my $host = "https://ncip.onleihe.de/ncip/service/";
    my $response = $ua->post($host, Content_Type => 'application/xml', Content => $xml);
    if ($response->is_success) {
        $xml_response = XML::XPath->new(xml =>  $response->decoded_content);
        # print STDERR $response->decoded_content;
    }
    else {
        $xml_response = 'onleihe not available at the moment';
    }
    return $xml_response;
}



sub _get_xml {
    my $template = shift;

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
,
userstatus => <<'XML',
<NCIPMessage ncip:version="2.0" xmlns:ncip="http://www.niso.org/2008/ncip"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:schemaLocation="http://www.niso.org/2008/ncip
http://www.niso.org/schemas/ncip/v2_0/ncip_v2_0.xsd">
<LookupUser>
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
<AuthenticationInput>
</AuthenticationInput>
<LoanedItemsDesired>true</LoanedItemsDesired>
<RequestedItemsDesired>true</RequestedItemsDesired>
<Ext>
<AgencyId>392</AgencyId>
<Language>de</Language>
</Ext>
</LookupUser>
</NCIPMessage>
XML
,
};

    return $xml_templates->{$template};
}

1;
