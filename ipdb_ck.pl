#!/usr/bin/perl
#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#	ipdb_ck.pl-$Name:  $-$Revision: 1.10 $ $Date: 2002/03/10 03:53:58 $ <$Author: bapril $@freeipdb.org>
######################################################################


use config;
use DBI;
%config = config::config();
require 'ipdb_lib.pl';

my $conn = DBI->connect("DBI:Pg:dbname=$config{dbname};host=$config{dbhost};port=$config{dbport}", "$config{dbuser}", "$config{dbpass}",);

print " /*--------------------- IP Database Consistency Check ---------------------*/\n\n";


$change = 1;
while($change){
	#Check for reclaims that haven't rolled up due to holdtime.
	$now = time;
	$query = "SELECT ID,PARENT,REGION,BITS
		FROM IPDB
		WHERE ( HOLDTIME < $now OR HOLDTIME IS NULL)
			AND ALLOCATED IS NULL 
			AND CHILDL IS NULL
			AND (RECLAIM != 1 OR RECLAIM IS NULL)";
	my $str = $conn->prepare($query);
	my $num = $str->execute;
	$first = 0;
	$change = 0;
	$i = 0;
	my @out;
	while(@out = $str->fetchrow){
		$id = $out[0];
		$parent = $out[1];
		$region = $out[2];
		$bits = $out[3];
		unless($PRTNS[$parent]){
			$FIRST[$parent] = $id;
		}
		$PRTNS[$parent]++;
		if($PRTNS[$parent] == 2){
			unless($first){print "reclaimed pairs that need to be cleared.\n";$first = 1;}
			print "ID $id - $FIRST[$parent] Cleared. $parent\n";
			demoblock($conn,$id) || &IPDBError(-1,"Could not demoblock");
			demoblock($conn,$FIRST[$parent]) || &IPDBError(-1,"Could not demoblock #2");
			clearblock($conn,$parent,1) || &IPDBError(-1,"Could not clearblock #3");
			$change++;
		}
		$i++;
	}
}

# List blocks that are still in holdtime.
$now = time;
$str = $conn->prepare("SELECT BLOCK,BITS,HOLDTIME
	FROM IPDB
	WHERE HOLDTIME > $now 
	AND ALLOCATED IS NULL
	AND CHILDL IS NULL ORDER BY HOLDTIME");
$num = $str->execute;
$first = 0;
$i = 0;
my @out;
while(@out = $str->fetchrow){
	unless($first){print "reclaimed blocks in holdtime.\n";$first = 1;}
	$block = $out[0];
	$bits = $out[1];
	$holdtime = $out[2];
	$diff = $holdtime - $now;
	if($diff > 86400 && $olddiff < 86400){print "---- One Day ----\n";}
	if($diff > 172800 && $olddiff < 172800){print "---- Two Days ----\n";}
	if($diff > 259200 && $olddiff < 259200){print "---- Three Days ----\n";}
	if($diff > 345600 && $olddiff < 345600){print "---- Four Days ----\n";}
	if($diff > 432000 && $olddiff < 432000){print "---- Five Days ----\n";}
	if($diff > 518400 && $olddiff < 518400){print "---- Six Days ----\n";}
	if($diff > 604800 && $olddiff < 604800){print "---- Seven Days ----\n";}
	if($diff > 691200 && $olddiff < 691200){print "---- Eight Days ----\n";}
	if($diff > 775800 && $olddiff < 775800){print "---- Nine Days ----\n";}
	if($diff > 864000 && $olddiff < 864000){print "---- Ten Days ----\n";}
	$olddiff = $diff;
	$block = deci2ip($block,4);
	printf("%20s Time: %s\n ",$block."/".$bits,$diff);
	$i++;
}

# Check for parents with only one child defined.
$str = $conn->prepare("SELECT ID FROM IPDB WHERE (CHILDL IS NULL AND CHILDR NOTNULL) OR (CHILDR IS NULL AND CHILDL NOTNULL)");
$num = $str->execute;
$i = 0;
if($num){print "Blocks that have only one child:\n";}
while(@out = $str->fetchrow){
	$id = $out[0];
	print "\t$id\n";
	$i++;
}

#Starting with the smallest block(s)
	#Gen list of block and thei parrents.
	#walk the list
		#Query parent
			#confirm children are truly related.
			#confirm any siblings.
			#Remove any ok siblings
			#Add parents to the list of bits--
		#
	#
#Incrament blocksize.

$str->finish;
undef $str;
$conn->disconnect;
print "Done\n";

