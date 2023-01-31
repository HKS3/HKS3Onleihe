use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::MungeRecord4OnleiheController;

use Data::Dumper;
use C4::Context;
use Text::CSV;
use Net::SFTP::Foreign;
use Modern::Perl;
use Date::Calc qw( Today );

my $plugin = new Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;
my $branchcode = $plugin->retrieve_data('Branchcode');

die "not host data" unless $ENV{ONLEIHE_HOST};

my $date;
my ($y, $m, $d) = Date::Calc::Today();

my $today = sprintf('%04d-%02d-%02d', $y, $m, $d);

$date = $ARGV[0] ? $ARGV[0] : $today;

my $sql = <<'SQL';
with cte_users as ( 
	select borrowernumber, cardnumber, date_format(dateofbirth, "%d.%m.%Y") dob, 0 fsk, 0 status, "D" crud, "STMK" bib, dateexpiry m_date from borrowers 
	union 
	select borrowernumber, cardnumber, date_format(dateofbirth, "%d.%m.%Y"), 0, 3, "I", "STMK", dateenrolled from borrowers where categorycode <> 'OA'
	union
	select borrowernumber, cardnumber, date_format(dateofbirth, "%d.%m.%Y"), 0, 1, "I", "STMK", dateenrolled from borrowers where categorycode = 'OA'
	union
	-- select borrowernumber, cardnumber, date_format(dateofbirth, "%d.%m.%Y"), 0, 3, "U", "STMK", cast(updated_on as date) from borrowers where categorycode <> 'OA'  
        select borrowernumber, cardnumber, date_format(dateofbirth, "%d.%m.%Y"), 0, if(debarred > ?, 1, 3), "U", "STMK", cast(updated_on as date) from borrowers where categorycode <> 'OA'
	union
        select borrowernumber, cardnumber, date_format(dateofbirth, "%d.%m.%Y"), 0, if(debarred > ?, 1, 3), "U", "STMK", debarred from borrowers where categorycode <> 'OA'
	)
select  borrowernumber, cardnumber, dob, fsk, status, crud, bib  from cte_users where m_date = ?
and (borrowernumber not in (select borrowernumber from borrowers where borrowernumber = cte_users.borrowernumber and dateexpiry <= ?) or crud = "D")
SQL

my $dir = $ENV{ONLEIHE_USER_DIR};
my $datename = $date;
$datename =~ s/-//g;
my $filename = sprintf("%s/%s_stmk.csv", $dir, $datename);
print("$filename\n");

my $dbh = C4::Context->dbh;
my $query = $dbh->prepare($sql);
$query->execute($date, $date, $date);
my $borrowers = $query->fetchall_arrayref([]);

# print Dumper $borrowers;
my $csv = Text::CSV->new ({ sep_char => ';', auto_diag => 1 });
open my $fh, ">:encoding(utf8)", $filename;
 # $csv->say ($fh, $_) for @rows;

foreach my $borrower (@$borrowers) {
	#  $csv->combine(@$borrower);
    $csv->say($fh, $borrower);
}

my $host = {
    host => $ENV{ONLEIHE_HOST},
    user => $ENV{ONLEIHE_USER},
    password => $ENV{ONLEIHE_PASSWORD},
};

my $sftp = Net::SFTP::Foreign->new(%$host);

$sftp->put($filename);

