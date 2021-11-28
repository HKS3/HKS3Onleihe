use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::MungeRecord4OnleiheController;

use Data::Dumper;
use C4::Context;
my $plugin = new Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;
my $branchcode = $plugin->retrieve_data('Branchcode');

my $sql = 'select borrowernumber, cardnumber, dateofbirth, debarred, debarredcomment, dateenrolled, dateexpiry, lost, updated_on, anonymized, lastseen from borrowers';
my $dbh = C4::Context->dbh;
my $query = $dbh->prepare($sql);
$query->execute();
my $borrowers = $query->fetchall_arrayref({});

# print Dumper $borrowers;
foreach my $borrower (@$borrowers) {
    print Dumper $borrower;
}

