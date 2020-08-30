#!/usr/local/bin/perl -w
#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#       report.pl-$Revision: 1.3 $ $Date: 2002/05/07 23:30:56 $ <$Author: bapril $@freeipdb.org>
######################################################################

require 'ipdb_httpcgi.pl';

use config;
use DBI;
%config = config::config();

my $conn = DBI->connect("DBI:Pg:dbname=$config{dbname};host=$config{dbhost};port=$config{dbport}", "$config{dbuser}", "$config{dbpass}",);

print "\n/----------------------  IP Allocation Utilization  ----------------------/\n";
&UtilDisplay($conn);
print "\n\n";

print "\n/----------------------  IP Region Utilization  ----------------------/\n";
&UtilRegion($conn);
print "\n\n";


if($config{routeview}){
	use Net::Telnet();
	print "\n/----------------------  Reclaimed blocks being announced ----------------------/\n";
	&routeview_report($conn);
}

$conn->disconnect;
