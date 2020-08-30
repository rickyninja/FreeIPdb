#!/usr/local/bin/perl -w
#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#	auto.cgi-$Name:  $-$Revision: 1.8 $ $Date: 2001/12/30 17:54:46 $ <$Author: bapril $@freeipdb.org>
######################################################################

require 'ipdb_httpcgi.pl';
use config;
%config = config::config();

print "Content-type: text/html\n\n";
use DBI;
my $script = get_cgi($0);
my $conn = DBI->connect("DBI:Pg:dbname=$config{dbname};host=$config{dbhost};port=$config{dbport}", "$config{dbuser}", "$config{dbpass}",);
my $buffer;
my @pairs;
my $pair;
my $name;
my $value;
my %FORM;
my $exit;

#Get Variable Space
read(STDIN,$buffer,$ENV{'CONTENT_LENGTH'});
@pairs = split(/&/,$buffer);
foreach $pair (@pairs){
        ($name,$value) = split(/=/,$pair);
        $name  =~ tr/+/ /;
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $FORM{$name} = $value;
}
$FORM{NULL} = "NULL";

if($FORM{'TYPE'} eq "SERIALREQ"){
	#Get /30 from a serial region
	my $id = &GetNewBlock($conn,$FORM{'REGION'},30,'SERIAL-REQ',1);
	IncReverseSerial($conn1,$id);
	&SetSerialDNS($conn1,$id,$FORM{'CUST'},$FORM{'PORT'},$FORM{'ROUTER'});
}

if($FORM{'TYPE'} eq "SERIALRECLAIM"){
	my $block = ip2deci($FORM{'IP'});
	$block = GetBlockId($conn1,$block,30,$region);
	&ReclaimBlock($conn1,$block);
	&ReclaimSerial($conn1,$block);
}

print "DONE<BR>\n";

