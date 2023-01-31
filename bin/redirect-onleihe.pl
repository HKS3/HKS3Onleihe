#!/usr/bin/perl

# Copyright Liblime 2008
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use CGI qw ( -utf8 );

use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Output;

use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI;
use Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe;

my $query = CGI->new();

my $onleihe_url = $query->param('url');

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'opac-mymessages.tt',
        query           => $query,
        type            => 'opac',
        debug           => 1,
    }
);

my $patron = Koha::Patrons->find( $borrowernumber );

my $onleihe = Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe->new();

my $onleihe_id = $onleihe->retrieve_data('OnleiheId');
my $library_data = { Language => 'de', AgencyId => $onleihe->retrieve_data('AgencyId') };
my $urldata = C4::Context->preference('OPACBaseURL') . '/cgi-bin/koha/opac-user.pl';
# XXX if possible check if book is already issued
if ($patron && $patron->categorycode ne 'OA' ) {
    my $onleihe = Koha::Plugin::HKS3Onleihe::MungeRecord4Onleihe::OnleiheAPI->new($patron, $library_data);
    $urldata = $onleihe->get_checkout_url_from_link($onleihe_url);
} else {
    $urldata = 'https://katalog.landesbibliothek.steiermark.at/';
}

print $query->redirect($urldata);
exit;
