package Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::MungeRecord4OnleiheController;

use Mojo::Base 'Mojolicious::Controller';

use C4::Context;
use C4::Debug;
use C4::Output qw(:html :ajax pagination_bar);

use HTTP::Request;
use LWP::UserAgent;
use List::MoreUtils qw(any);
use C4::Circulation;
use Koha::Patrons;
use C4::Context;
use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI;
use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;

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

    my $plugin = new Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;
    my $agency_id = $plugin->retrieve_data('AgencyId');

    my $patron = Koha::Patrons->find($patron_id);
    my $branchcode = $plugin->retrieve_data('Branchcode');
    C4::Context->set_userenv(0, $branchcode, 0, $branchcode, $branchcode, $branchcode, $branchcode);
    
    my $pending_checkouts = $patron->pending_checkouts->
        search({ homebranch => $branchcode },
           { order_by => [ { -desc => 'date_due' }, { -asc => 'issue_id' } ] });

    my $datedue;
    my $inprocess = 0;
    my @barcodes;

    while ( my $c = $pending_checkouts->next ) {
        my $issue = $c->unblessed_all_relateds;
        push (@barcodes, $issue->{barcode});
    }

    my $library_data = { Language => 'de', AgencyId => $agency_id };
    my $onleihe = Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI->new($patron, $library_data);
    my $ois = $onleihe->get_user_status();
    
    my $cancelreserve = 1;
    
    # issue if not in checkouts
    my @oi_isbns;
    my @data;
    foreach my $oi (@$ois) {
        my $oi_isbn = $oi->{ISBN};
        # say $oi_isbn;
        push @oi_isbns, $oi_isbn;
        if (scalar @barcodes > 0 && any {$_ eq $oi_isbn} @barcodes) {
            push (@data, sprintf( "[%s] already issued", $oi_isbn) );
            next;
        }
        push (@data, sprintf( "[%s] issueing", $oi_isbn) );
        my $item_object = Koha::Items->find({ barcode => $oi_isbn });
        # print Dumper $item_object;
        my $issue = AddIssue( $patron->unblessed,
            $oi_isbn,
            $datedue,
            $cancelreserve,
            undef,
            undef,
            { onsite_checkout => 'on', auto_renew => 0, switch_onsite_checkout => 'off', }
        );
    }
    
    # remove if not checked out in onleihe
    foreach my $barcode (@barcodes) {
        if (scalar @oi_isbns > 0 && any {$_ eq $barcode} @oi_isbns) {
            push (@data, sprintf( "[%s] checked out in onleihe and koha", $barcode) );
            next;
        }
        push (@data, sprintf( "[%s] removing from koha", $barcode) );
        my $exempt_fine;
        my $returned =  AddReturn( $barcode, $branchcode, $exempt_fine );
        push (@data, sprintf( "[%s] returned", $barcode) ) if $returned;
    }
    

    return $c->render( status => 200, openapi => {
        data => \@data
    } );
}
