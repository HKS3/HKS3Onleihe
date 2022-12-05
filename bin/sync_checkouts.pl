use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::MungeRecord4OnleiheController;

use Data::Dumper;
use C4::Context;
my $plugin = new Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;
my $branchcode = $plugin->retrieve_data('Branchcode');

my $sql = 'select userid, count(*)  from search_history  where time > now() - interval 1 hour  group by userid';
#my $sql = 'select 123855 userid, 1';
my $dbh = C4::Context->dbh;
my $query = $dbh->prepare($sql);
$query->execute();
my $borrowers = $query->fetchall_arrayref({});

# print Dumper $borrowers;
foreach my $borrower (@$borrowers) {
    printf("[%s] borrowernumber \n", $borrower->{userid});
    my $ret = Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::MungeRecord4OnleiheController::synccheckouts4patron($borrower->{userid});
    print Dumper $ret;
}

