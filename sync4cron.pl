use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::MungeRecord4OnleiheController;

use Data::Dumper;
use C4::Context;
my $plugin = new Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;

my $branchcode = $plugin->retrieve_data('Branchcode');


my $sql = 'select borrowernumber, count(*) c from issues where branchcode = ? group by borrowernumber';
my $dbh = C4::Context->dbh;
my $query = $dbh->prepare($sql);
$query->execute($branchcode);
my $borrowers = $query->fetchall_arrayref({});

# print Dumper $borrowers;
foreach my $borrower (@$borrowers) {
    printf("[%s] borrowernumber \n", $borrower->{borrowernumber});
    my $ret = Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::MungeRecord4OnleiheController::synccheckouts4patron(62);
    print Dumper $ret;
}

