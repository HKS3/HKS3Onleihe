# HKS3Onleihe

#### sponsored by Steiermärkische Landesbibliothek/Styrian State Library

### Installation

Install and activate plugin like any other koha-plugin

define Koha Branchcode for onleihe items

copy or better link "proxy" to opac and intranet
```
ln -s /var/lib/koha/libelle/plugins/Koha/Plugin/HKS3Onleihe/redirect-onleihe.pl /usr/share/koha/opac/cgi-bin/opac/redirect-onleihe.pl
ln -s /var/lib/koha/libelle/plugins/Koha/Plugin/HKS3Onleihe/redirect-onleihe.pl /usr/share/koha/intranet/cgi-bin/redirect-onleihe.pl
```

#### Configure

agency_id, language for onleihe 



#### cronjobs

##### sync with onleihe

```
# daily sync returned books right after midnight
7 0 * * *  perl /var/lib/koha/libelle/plugins/Koha/Plugin/HKS3Onleihe/sync4cron.pl >> <logfile> 2>&1
# watch for recently logged in users and sync their checkouts
*/15 * * * perl /var/lib/koha/libelle/plugins/Koha/Plugin/HKS3Onleihe/sync_checkouts.pl  >> <logfile> 2>&1
```

## SQL of Interest

```
delete from plugin_data where plugin_class  = '<class name>';

delete from plugin_methods where plugin_class  = '<class name>';
 
update biblioitems set itemtype = 'HB' where
biblioitemnumber in (
with cte_meta as  (select
biblionumber,
ExtractValue(metadata,'//datafield[@tag="337"]/subfield[@code="a"]') mediatype,             
ExtractValue(metadata,'//controlfield[@tag="001"]') cn
from biblio_metadata)
select bi.biblioitemnumber
from cte_meta cm join biblioitems bi
on  cm.biblionumber = bi.biblionumber
join items i
on bi.biblioitemnumber = i.biblioitemnumber
where
mediatype = 'eaudio'
and itype = 'HB');
```
