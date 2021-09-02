# HKS3Onleihe

delete from plugin_data where plugin_class  = '<class name>';

delete from plugin_methods where plugin_class  = '<class name>';

# Installation

this plugin requires a new plugin hook in

/usr/share/koha/opac/cgi-bin/opac/opac-detail.pl

 215     #### XXX something here
 216     my @records = Koha::Plugins->call(
 217         'munge_record',
 218         {
 219             patron      => $patron,
 220             interface   => 'opac',
 221             caller      => 'opac-detail',
 222             record      => $record,
 223         }
 224     );
 225     # use Data::Dumper; print Dumper \@records;
 226     $record = $records[0];
 227     #### XXX

and requires configuration namely the

agency_id from onleihe and language

