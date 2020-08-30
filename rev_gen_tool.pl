#!/usr/local/bin/perl
#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#	rev_gen_tool.pl-$Name:  $-$Revision: 1.14 $ $Date: 2002/04/29 19:15:38 $ <$Author: bapril $@freeipdb.org>
######################################################################

# Trial tool to generate Reverse DNS files from IPDB/DNS.
require 'ipdb_httpcgi.pl';
use config;
%config = config::config();

$SIG{__WARN__} = sub {my$d=join('',@_);my$l=$d=~s/ at (.*) line (\d+)(?:, <\w+> chunk \d+)?\.$//?"$1($2): ":'';print"$l$_\n"for split(/\n/,$d)}; 

my $debug = 1;
$force = 0;
$quiet = 0;
foreach $arg (@ARGV){
	if($arg eq "-q"){ $quiet = 1;}
	if($arg eq "-f"){ $force = 1;}
	if($arg eq "-d"){ $debug = 1;} else { $debug = 0;}
	if($arg eq "-?" || $arg eq "-h"){
		print "Usage: rev_gen_tool.pl [-q] [-h]\n";
		print "\t-h this help screen.\n";
		print "\t-q operate queitly (for cron and such).\n";
		exit();
	}
}

unless($config{allowDNS}){
	die("FreeIPdb is not configured for DNS.\n")
}

#Check for DNS dir
open(CONFIG,">$config{dnsdir}/$config{dnsinclude}")|| die "Can't open $config{dnsdir}/$config{dnsinclude} for writing $!";

use DBI;
my $conn = DBI->connect("DBI:Pg:dbname=$config{dbname};host=$config{dbhost};port=$config{dbport}", "$config{dbuser}", "$config{dbpass}",);

#Walk DB for Reverse Files.

my $query = "SELECT ZONE_TABLE.ID,ZONE_TABLE.reverse_block WHERE ZONE_TABLE.reverse_block NOTNULL AND IPDB.ID = ZONE_TABLE.reverse_block AND IPDB.ID NOTNULL AND ZONE_TABLE.OWN = 't' ORDER BY IPDB.block";
my $str = $conn->prepare($query);
my $num = $str->execute;
my @out;
while(@out = $str->fetchrow){
	my $id = $out[0];
	my $rev_zone = $out[1];
	my $zonename = &GetZoneString($conn,$id);
	$zonename =~ s/.$//g;
	my $fileserial = &GetFileSerial("$config{dnsdir}$zonename");
	my $zoneserial = &GetZoneSerial($conn,$rev_zone,1);
	warn "ZONE: $zonename($rev_zone)  Serial file/zone: $fileserial/$zoneserial" if $debug;
	if($fileserial != $zoneserial || $force){
		open(FILE,">$config{dnsdir}$zonename")|| die "Can't open $config{dnsdir}$zonename for writing $!";
		select(FILE);
		&DNSHead($conn,$rev_zone,1);
		# Walk blocks under zone.
		&WalkReverseBlocks($conn,$rev_zone);
		select(STDOUT);
		close(FILE);
		warn "ZONE $zonename" unless $quiet;
		print CONFIG "zone \"$zonename\" in {\n";
		print CONFIG "\ttype master;\n";
		print CONFIG "\tfile \"$config{dnsdir}$zonename\";\n";
		print CONFIG "};\n";
	} else {
		warn "FILE: $fileserial | DB: $zoneserial" if $debug;
	}
}


#Walk DB for Forward File.

$query = "SELECT ID FROM ZONE_TABLE WHERE OWN = 't' AND reverse_block IS NULL";
$str = $conn->prepare($query);
$num = $str->execute;
while(@out = $str->fetchrow){
	my $id = $out[0];
	my $zonename = &GetZoneString($conn,$id);
	$fileserial = &GetFileSerial("$config{dnsdir}$zonename");
	$zoneserial = &GetZoneSerial($conn,$id,0);
	if($fileserial != $zoneserial || $force){
		open(FILE,">$config{dnsdir}$zonename")|| die "Can't open $config{dnsdir}$zonename for writing $!";
		select(FILE);
		# Walk the Zone.
		&DNSHead($conn,$id);
		&WalkZone($conn,$id);
		select(STDOUT);
		close(FILE);
		warn "ZONE $zonename" unless $quiet;
		print CONFIG "zone \"$zonename\" in {\n";
		print CONFIG "\ttype master;\n";
		print CONFIG "\tfile \"$config{dnsdir}$zonename\";\n";
		print CONFIG "};\n";
	}
}


close(CONFIG);
$str->finish;
undef $str;
$conn->disconnect;
