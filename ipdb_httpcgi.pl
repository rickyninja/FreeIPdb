#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#	ipdb_httpcgi.pl-$Name:  $-$Revision: 1.35 $ $Date: 2002/05/07 23:30:55 $ <$Author: bapril $@freeipdb.org>
######################################################################

use strict;
use warnings;
require 'ipdb_lib.pl';

######################################################################
# sub printHead
#
# prints the HTML header info, taking the title as a parameter
######################################################################
sub printHead {
	etrace(@_);

my $title = shift (@_);

print <<EOM;
Content-type: text/html\n\n
<HTML>
 <HEAD>
  <TITLE>$title</TITLE>
 </HEAD>
 <BODY BGCOLOR=#FFFFFF>
EOM
}

######################################################################
# sub printTail
#
# Prints the end of the HTML page
######################################################################
sub printTail {
	etrace(@_);
print <<EOF;
 </BODY>
</HTML>
EOF
}

sub get_cgi(){
	etrace(@_);
        my $exe = shift;
        $exe =~ s/\/.*\/([^\/]*)$/$1/ ;
        return($exe);
}

sub ClearHoldtime(){
	etrace(@_);
	my $dbh = shift || &IPDBError(-1,"Did not supply DB connection");
	my $block = shift || &IPDBError(-1,"Did not supply Block ID");
	if(!$config::config{clearhold}){ &IPDBError(-1,"Clearing the holdtime on a block is not allowed.");}
	if($block !~ m/[0-9]*/){ &IPDBError(-1,"Block ID is invalid"); }
	my $sth = $dbh->prepare('UPDATE IPDB SET HOLDTIME=NULL WHERE ID=?');
	$sth->execute( $block );
	if($sth->err){
		my $err = $DBI::errstr;
		&IPDBError(-1,"Could not lookup RA:  $err");
	}
	&Log_Event($dbh,12,0,0,0,0,$block);
	$sth->finish;
	undef $sth;
}


sub GetNewBlock(){
	etrace(@_);
	my $dbh = shift;
	my $region = shift;
	my $bits = shift;
	my $CUSTDESC = shift;
	my $CUST = shift;
	my $newblock = &NewBlock($dbh,$region,$bits,$CUSTDESC,$CUST) || &IPDBError(-1,"Could not create Block");
	print "  Your New BlockID is : $newblock\n";
	my $sthing = &ReadBlock($dbh,$newblock);
	print "  <BR>$sthing<BR>";
	return($newblock);
}

sub ReclaimBlock(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	return(&reclaim($dbh,$block));
}

sub ReclaimConfirm(){
	etrace(@_);
	my $dbh = shift;
	my $id = shift;
	my @blk = GetBlockFromID($dbh,$id);
	my $ver = &Version($dbh,$id);
        my $ip = &deci2ip($blk[0],$ver);
	my $block = $ip."/".$blk[1];
	print "<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1><FORM METHOD=GET>\n";
	print "<INPUT TYPE=HIDDEN NAME=ACTION VALUE=RECLAIM>\n";
	print "<INPUT TYPE=HIDDEN NAME=CONFIRM2 VALUE=$block>\n";
	print "<INPUT TYPE=HIDDEN NAME=RECLAIM VALUE=$id>\n";
	print "<TR><TH COLSPAN=2><H2>You have requested $block be reclaimed";
	print "</H2><BR>Please copy the block into the lower window.</TH></TR>\n";
	print "<TR><TH>Copy from here -></TH><TD>$block</TD></TR>\n";
	print "<TR><TH>to here -></TH>";
	print "<TD><INPUT TYPE=text NAME=CONFIRM></TD></TR>\n";
	#print "<TR><TH>Optional hold time override:</TH><TD><INPUT NAME=HOLDTIME>days</TD></TR>\n";
	print "<TR><TH COLSPAN=2><INPUT TYPE=SUBMIT VALUE=\"Click here ";
	print "to confirm reclaim\"></TH></TR>\n";
	print "</FORM></TABLE>\n";
}

sub IP2Deci(){
	etrace(@_);
	my $block = shift;
	my $out = ip2deci($block);
	return($out);
}

sub RegionAllocations(){   
	etrace(@_);
	my $dbh = shift;
	my $region = shift;
	my $sql = 'SELECT ID FROM IPDB WHERE PARENT=0 AND REGION=?';
	my $sth = $dbh->prepare( $sql );
	my $num = $sth->execute( $region );
	my $i = 0;
	my @out;
	my @get;
	while($i != $num){
		@get = $sth->fetchrow;
		$out[$i] = $get[0];
		$i++;
	}  
	return(@out);
}

sub FreeList(){
	etrace(@_);
	my $dbh = shift;
	my $sql = "SELECT i.ID,i.BLOCK,i.BITS,r.name,r.v6,i.reclaim,i.holdtime
		FROM IPDB i,REGIONTABLE r 
		WHERE r.ID = i.REGION 
			AND i.CHILDL IS NULL 
			AND CHILDR IS NULL 
			AND ALLOCATED IS NULL ORDER BY r.name,bits";
	my $sth = $dbh->prepare($sql);
	my $num = $sth->execute;
	my $now = time();
	my $in = 0;
	my @out;
	while(@out = $sth->fetchrow){
		my $id = $out[0];
		my $block = $out[1];
		my $bits = $out[2];
		my $region = $out[3];
		my $reclaim = $out[5];
		my $holdtime = $out[6];
		my $ver = &Version($dbh,$id);
		$block = deci2ip($block,$ver);
		unless($reclaim){	
			$reclaim = "&nbsp;";
		} elsif ($reclaim eq "0") {
			$reclaim = "Child Block";
		} elsif ($reclaim eq "1") {
			$reclaim = "Master Block";
		}
		$in = &Toggle($in);
		print "<TD>$region</TD><TD>$block/$bits</TD><TD>$reclaim</TD><TD>$id</TD>";
		if($config::config{showhold}){
			if($holdtime < $now){
				print "<TD>&nbsp;</TD>";
			} else {
				$holdtime -= $now;
				$holdtime = $holdtime / 86400;
				printf("<TD>%3.1d days",$holdtime);
				if($config::config{clearhold}){
					print "<FORM METHOD=GET><INPUT TYPE=HIDDEN NAME=EDIT VALUE=$id>";
					print "<INPUT TYPE=HIDDEN NAME=ACTION VALUE=CLEARHOLD>";
					print "<INPUT TYPE=Submit VALUE=\"Clear Holdtime\"></FORM>";
				}
				print "</TD>";
			}
		}
		if($config::config{assignfromfree}){
			print "<TD><FORM METHOD=GET><INPUT TYPE=HIDDEN NAME=EDIT VALUE=$id>";
			print "<INPUT TYPE=HIDDEN NAME=ACTION VALUE=EDIT>";
			print "<INPUT TYPE=Submit VALUE=Assign></FORM></TD>";
		}
		print "</TR>\n";
	}
	$sth->finish;
	undef $sth;
}

#--------------------------------------------------------------------------------------
#	AddBlock();
# Takes:
#	A database connection
#	A block (in integer format)
#	A Bitmask (in bits)
# Returns:
#	-1 on error
#	0 on block in use or parent exists
#	ID of block on sucess

sub AddBlock(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $bits = shift;
	my $region = shift;
	my $priority = shift;
	my $newblock = &NewAlloc($dbh,$block,$bits,$region,$priority);
	return($newblock);
}


sub AllocatedSearch
{
	etrace(@_);
	my($dbh,$script,$class,$id,$block,$bits,$region,$cust,$custdesc,$hostname,$toggle) = @_;
	my $sql = 'SELECT ID FROM IPDB WHERE ID NOTNULL';
	if($id){
		$sql = $sql." AND ID = $id";
	} else {
		if($custdesc){$sql = $sql." AND CUSTDESC ILIKE '%$custdesc%'";}
		if($cust){$sql = $sql." AND CUSTNUM LIKE '%$cust%'";}
		if($region !~ m/---/){$sql = $sql." AND REGION = $region";}
		if($bits =~ m/^[0-9]+$/){$sql = $sql." AND BITS = $bits";}
		if($block){ $sql = $sql." AND BLOCK = ".$block."::NUMERIC(40,0) "; }
		if($hostname){$sql = $sql." AND ZONE_RECORD_TABLE.hostname ~* '$hostname' AND ZONE_RECORD_TABLE.block = ID";}
	}
	$sql = $sql." ORDER BY BITS ASC";
	print "<!-- $sql-->\n";
	my $sth = $dbh->prepare($sql);
	my $num = $sth->execute;
	my $in = 0;
	print "<TR><TD COLSPAN=7>Direct search</TD></TR>\n";
	my @out;
	while(@out = $sth->fetchrow){
		my $id = $out[0];
		$toggle = &SearchResult($dbh,$id,$toggle,$script,$class);
	}
	#walk the list for eligible parent blocks.
	if($block){
		print "<TR><TD COLSPAN=7>Recurssive search</TD></TR>\n";
		my @sql = (['SELECT ID,BLOCK,BITS,REGION,ALLOCATED,CHILDL,CHILDR FROM IPDB WHERE PARENT=0']);
		$sql = 'SELECT ID,BLOCK,BITS,REGION,ALLOCATED,CHILDL,CHILDR FROM IPDB WHERE PARENT=0';
		if( $region && $region ne '--- Please Choose ---' )
		{
			push @sql, [' AND REGION=?',$region];
			$sql .= qq( AND REGION=$region);
		}
		#if( $bits =~ m/^[0-9]+$/ )
		#{
		#	push @sql, [' AND BITS=?',$bits];
		#	$sql .= " AND BITS=$bits";
		#}
		$sql .= ' AND BLOCK <= '.$block.'::NUMERIC(40,0)'; 
		#push @sql, [' AND BLOCK <= ?',$block];
		push @sql, [' AND BLOCK <= '.$block.'::NUMERIC(40,0)'];
		print "<!-- $sql -->\n";
		print '<!-- '.join('',map{$_->[0]}@sql).'; ('.join(',',map{defined $_->[1]?$_->[1]:()}@sql).") -->\n";
		#my $sth = $dbh->prepare($sql);
		#my $num = $sth->execute;
		my $sth = $dbh->prepare( join('',map{$_->[0]}@sql) );
		my $num = $sth->execute( map{defined $_->[1]?$_->[1]:()}@sql );
		while(@out = $sth->fetchrow){
			#Check of search-block is within parent.
			my $id = $out[0];
			my $start = $out[1];
			my $ver = &Version($dbh,$id);
			my $size = &Addresses($out[2],$ver);
			my $end = $start + $size;
			my $childl = $out[5];
			my $childr = $out[6];
			if(($block >= $start) && ($block <= $end)){
				if($childl){
					&RecBlockSearch($dbh,$childl,$block,$bits,$script,$class);
					&RecBlockSearch($dbh,$childr,$block,$bits,$script,$class);
				} else {
					$toggle = &SearchResult($dbh,$id,$toggle,$script,$class);
				}
			} 
		}
	}
}

sub RecBlockSearch(){
	etrace(@_);
	my $dbh = shift;
	my $id = shift;
	my $block = shift;
	my $bits = shift;
	my $script = shift;
	my $class = shift;
	my $sql = 'SELECT ID,BLOCK,BITS,REGION,ALLOCATED,CHILDL,CHILDR FROM IPDB WHERE ID=?';
	print "<!--$sql-->\n";
	my $sth = $dbh->prepare( $sql );
	my $num = $sth->execute( $id );
	my @out;
	my $toggle;
	while(@out = $sth->fetchrow){
		#Check of search-block is within parent.
		my $id = $out[0];
		my $start = $out[1];
		my $ver = &Version($dbh,$id);
		my $size = &Addresses($out[2],$ver);
		my $end = $start + $size;
		my $childl = $out[5];
		my $childr = $out[6];
		if(($block >= $start) && ($block <= $end)){
			if($childl){
				&RecBlockSearch($dbh,$childl,$block,$bits,$script,$class);
				&RecBlockSearch($dbh,$childr,$block,$bits,$script,$class);
			} else {
				$toggle = &SearchResult($dbh,$id,$toggle,$script,$class);
			}
		} 
	}
}

sub Date(){
	etrace(@_);
	my $in = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($in);
	$mon++;
	$year += 1900;
	my $allocated ;
	$allocated .= $hour.":".$min.":".$sec." " ;
	if($config::config{dateformat} eq "MM/DD/YYYY"){
		$allocated .= $mon."/".$mday."/".$year;
	} elsif ($config::config{dateformat} eq "DD/MM/YYYY"){
		$allocated .= $mday."/".$mon."/".$year;
	} else {
		$allocated .= $mday."/".$mon."/".$year;
	}
	return($allocated);
}


sub SearchResult(){
	etrace(@_);
	my $dbh = shift;
	my $id = shift;
	my $toggle = shift;
	my $script = shift;
	my $class = shift;
	my $sql = 'SELECT BLOCK,BITS,REGION,ALLOCATED,CUSTDESC,CUSTNUM,CHILDL,CHILDR,PARENT FROM IPDB WHERE ID=?';
	print "<!--$sql-->\n";
	my $sth = $dbh->prepare( $sql );
	my $num = $sth->execute( $id );
	$toggle = &Toggle($toggle);
	my @out = $sth->fetchrow;
	my $bits = $out[1];
	my $customer = $out[4];
	my $custdesc = $out[5];
	my $childl = $out[6];
	my $childr = $out[7];
	my $parent = $out[8];
	my $ver = &Version($dbh,$id);
	my $block = &deci2ip($out[0],$ver);
	my $region = &LookupRegion($dbh,$out[2]);
	print "<TD>$id</TD><TD>";
	if($parent == 0){print "* ";}
	print "$block/$bits</TD><TD>$region</TD><TD>";
	if($out[3]){
		my $allocated = &Date($out[3]);
		print "$allocated</TD>";
	} else {
		print "&nbsp;</TD>";
	}
	if($config::config{custnum}){
		if($customer){
			print "<TD>$customer</TD>";
		} else {
			print "<TD>&nbsp;</TD>";
		}
	}
	if($config::config{custname}){
		if($custdesc){
			print "<TD>$custdesc</TD>";
		} else {
			print "<TD>&nbsp;</TD>";
		}
	}
	print "<TD><NOBR>";
	if($class && $out[3]){
		print a({href=>"?RECLAIM=$id&ACTION=RECLAIM"},'[ Reclaim ]'), '&nbsp;', a({href=>"?EDIT=$id&ACTION=EDIT"},'[ Edit ]');
	} elsif($childl){
		print a({href=>"?RECURSE=$id&ACTION=RECURSE&CHILDL=$childl&CHILDR=$childr"},'[ Drill-Down ]');
	} elsif($class){
		print a({href=>"?EDIT=$id&ACTION=EDIT"},'[ Assign ]');
	}
	print "</NOBR></TD></TR>";
        if($config::config{allowDNS}){
                if(&CheckDNS($dbh,$id)){
                        &DNSTable($dbh,$id,$script);
        #                print "<TR><TD><FORM METHOD=GET><INPUT TYPE=HIDDEN NAME=EDIT VALUE=$id>";
        #                print "<INPUT TYPE=HIDDEN NAME=ACTION VALUE=DNSEDIT>";
        #                print "<INPUT TYPE=Submit VALUE=\"Edit DNS\"></FORM></TD></TR>";
                }
        }
	return($toggle);
}

sub EditForm(){
	etrace(@_);
	my $dbh = shift;
        my $id = shift;
	my $script = shift;
	my $sql = 'SELECT BLOCK,BITS,REGION,CUSTNUM,CUSTDESC,ALLOCATED FROM IPDB WHERE ID=?';
	my $sth = $dbh->prepare($sql);
	my $num = $sth->execute( $id );
	my $region;
	my $regionid;
	my $block;
	my $bits;
	my $customer = '';
	my $custdesc = '';
	my $allocate;
	$num =~ s/E.*//g;
	if($num){
		my @out = $sth->fetchrow;
		$block = deci2ip($out[0],Version($dbh,$id));
		$bits = $out[1];
		$regionid = $out[2];
		$region = &LookupRegion($dbh,$regionid);
		$customer = $out[3];
		$custdesc = $out[4];
		$allocate = $out[5];
	}
	print "<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1><TR><TH>ID</TH><TH>Block</TH><TH>Region</TH>\n";
	if($config::config{custnum}){
		print "<TH>$config::config{custnum_f}</TH>";
	} 
	if($config::config{custname}){
		print "<TH>$config::config{custname_f}</TH>";
	}
	print "<TH>Function</TH></TR>\n";
	print "<FORM ACTION=$script METHOD=GET>";
	print "<TR><TD>$id</TD><TD>$block/$bits</TD><TD>";
	print "<SELECT NAME=REGION>\n<OPTION VALUE=$regionid> --- No change $region ---\n";
	ListRegions($dbh);
	print "</SELECT>";
	print "</TD>";
	if($config::config{custnum}){
		if($config::config{custnum_ed}){
			print "<TD><INPUT NAME=CUSTOMER VALUE=$customer></TD>\n";
		} else {
			print "<TD>$customer</TD>\n";
		}
	}
	if($config::config{custname}){
		if($config::config{custdesc_ed}){
			print "<TD><INPUT NAME=CUSTDESC VALUE=\"$custdesc\"></TD>\n";
		} else {
			print "<TD>$custdesc</TD>\n";
		}
	}
	print "<TD><INPUT TYPE=HIDDEN NAME=UPDATE  VALUE=$id>\n";
	if($allocate){
		print "<INPUT TYPE=HIDDEN NAME=ACTION VALUE=UPDATE><INPUT TYPE=SUBMIT VALUE=Update>\n";
	} else {
		print "<INPUT TYPE=HIDDEN NAME=ACTION VALUE=ASSIGN><INPUT TYPE=SUBMIT VALUE=Assign>\n";
	}
	print "</FORM>\n";
	print "</TD></TR>\n";
	print "</TABLE>";
}

sub UpdateBlock(){
	etrace(@_);
	my $dbh = shift;
	my $id = shift;
	my $region = shift;
	my $customer = shift;
	my $custdesc = shift;
	my @block = GetBlockFromID($dbh,$id);
	unless($region == $block[2]){
		my $ver = &Version($dbh,$id);
		my $ip = deci2ip($block[0],$ver);
		my $added = &SetBlockP($dbh,$ip,$region,$block[1],1,1,$ver);
		if($added){
			print "A parent of that block exists.<BR>\n";
			&reclaim($dbh,$added);
		} else {
			my $check = &CheckBlockFree($dbh,$block[0],$block[1],$region);
			if($check){
				print "Block is in use<BR>\n";
				return(0);
			} else {
				if(&SetRegion($dbh,$id,$region,$block[2])){
					print "Success  $id!\n";
				} else {
					print "There was an error\n";
				}
			}
		}
	}
	if($custdesc){
		my $sth = $dbh->prepare( 'UPDATE IPDB SET CUSTDESC=? WHERE ID=?' );
		my $num = $sth->execute( $custdesc, $id );
		if($sth->err){
			IPDBError(-1,$DBI::errstr);
		}
		if($config::config{allowJUST}){
			$sth = $dbh->prepare( 'UPDATE JUSTIFICATIONTABLE SET DESCR=? WHERE BLOCK=?' );
			$num = $sth->execute( $custdesc, $id );
			if($sth->err){
				IPDBError(-1,$DBI::errstr);
			}
		}
	}
	if($customer){
		my $sth = $dbh->prepare( 'UPDATE IPDB SET CUSTNUM=? WHERE ID=?' );
		my $num = $sth->execute( $customer, $id );
		if($sth->err){
			IPDBError(-1,$DBI::errstr);
		}
	}
}

sub LogHead(){
	etrace(@_);
	print "<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>\n";
	print "<TR><TH>Date/Time</TH><TH>User/Remote-IP</TH><TH>Action</TH>\n";
	print "<TH>Region</TH><TH>Block/Bits(ID)</TH><TH>Number</TH>\n";
	print "<TH>Text</TH></TR>\n";
}

sub LogSearch(){
	etrace(@_);
	my $dbh = shift;
	my $region = shift;
	my $where = '';
	my $sql = 'SELECT TIME,remote_user,code,region,ip,block,bits,text,number,remote_addr FROM LOG_TABLE';
	if($region !~ /---/){ $where .= ' AND REGION=?';}
	if($where){
		$sql .= " WHERE TIME NOTNULL $where";
	}
	$sql .= ' ORDER BY TIME ASC';
	my $sth = $dbh->prepare( $sql );
	my $num = $sth->execute( $region !~ /---/ ? $region : () );
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
	my @out;
	while(@out = $sth->fetchrow()){
		print "<TR><TD>".&Date($out[0])."</TD><TD>$out[1]/$out[9]</TD><TD>\n";
		if($out[2] == 1){
			print "Add RA";
		} elsif ($out[2] == 2){
			print "Delete RA";
		} elsif ($out[2] == 3){
			print "Add Region";
		} elsif ($out[2] == 4){
			print "Delete Region";
		} elsif ($out[2] == 5){
			print "Add Supernet";
		} elsif ($out[2] == 6){
			print "Move block (to region)";
		} elsif ($out[2] == 7){
			print "Set Priotiry";
		} elsif ($out[2] == 8){
			print "Set Reclaim";
		} elsif ($out[2] == 9){
			print "Allocate block (specified)";
		} elsif ($out[2] == 10){
			print "Allocate Block (auto)";
		} elsif ($out[2] == 11){
			print "Reclaim Block";
		} elsif ($out[2] == 12){
			print "Clear Holdtime";
		} elsif ($out[2] == 13){
		} elsif ($out[2] == 14){
			print "Edit CUSTNUM";
		} elsif ($out[2] == 15){
			print "Edit CUSTDESC";
		} else {
			print "$out[2]";
		}
		print "</TD><TD>";
		if($out[3]){
			&LookupRegion($dbh,$out[3]);
		}
		print 	"</TD><TD>";
		if($out[4] && $out[5]){
			my $ipblock = &deci2ip($out[4],&Version($dbh,$out[5]));
			$ipblock .= "/$out[6]";
			print "$ipblock";
		}
		print "($out[5])</TD><TD>$out[8]</TD><TD>$out[7]</TD>";
		print "</TR>";
	}
	print "</TABLE>\n";
}

sub AllocatedSearch_Head(){
	etrace(@_);
	print "<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>\n";
	print "<TR><TH>Id</TH><TH>Block Bits</TH><TH>Region</TH><TH>Allocated</TH>\n";
	if($config::config{custname}){
		print "<TH>$config::config{custname_f}</TH>";
	}
	if($config::config{custnum}){
        	print "<TH>$config::config{custnum_f}</TH>";
	}
	print "<TH>Functions</TH></TR>\n";
}

#--------------------------------------------------------------------------------------
sub SetRegion(){
	etrace(@_);
	my $dbh = shift;
	my $id = shift;
	my $region = shift;
	my $start = shift;
	my $sth;
	my $num;
	# Make sure we're not overlaping space.
	my @block = &GetBlockFromID($dbh,$id);

	$sth = $dbh->prepare("UPDATE IPDB SET REGION = $region WHERE ID = $id AND REGION = $start");
	$num = $sth->execute;
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
	if($num){
		$sth->finish;
		$sth = $dbh->prepare("SELECT CHILDL,CHILDR FROM IPDB WHERE ID = $id");
		$sth->execute;
		if($sth->err){
			IPDBError(-1,$DBI::errstr);
		}
		my @out = $sth->fetchrow();
		if($out[0]){
			&SetRegion($dbh,$out[0],$region,$start);
			&SetRegion($dbh,$out[1],$region,$start);
		}
	}
	$sth->finish;
	undef $sth;
	return(1);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
sub SetReclaim(){
	etrace(@_);
	my $dbh = shift;
	my $id = shift;
	my $level = shift;
	if($level){
		&Log_Event($dbh,8,0,0,0,0,$id);
	}
	my $sth = $dbh->prepare("UPDATE IPDB SET RECLAIM = $level WHERE ID = $id");
	$sth->execute;
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
	print "Setting reclaim on blockID: $id<BR>\n";
	$sth = $dbh->prepare("SELECT CHILDL,CHILDR FROM IPDB WHERE ID = $id");
	my $num = $sth->execute;
	if($sth->err){		
		IPDBError(-1,$DBI::errstr);
	}
	$num =~ s/E.*//g;
	if($num){
		print "NUM: $num\n";
		my @out = $sth->fetchrow;
		my $childl = $out[0];
		if($childl){
			&SetReclaim($dbh,$childl,0);
		}
		my $childr = $out[1];
		if($childr){
			&SetReclaim($dbh,$childr,0);
		}
	} else {
		print "DeadEnd: $id\n";
	}
	$sth->finish;
	undef $sth;
}

sub ReclaimSerial(){
	etrace(@_);
        my $dbh = shift;
        my $block = shift;
        my $sth = $dbh->prepare("DELETE FROM ZONE_RECORD_TABLE WHERE BLOCK = $block AND TYPE = 2");
	$sth->execute;
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
}

#Get block ID no mask needed (returns the ID of the block of the smallest size matching the criteria.

# Give an IP and a region.
#return the block ID and the off-set.

#Gen list of All blocks that are allocated and the block starts at a lower IP than the entered it.
# Walk the list and gen the last IP.
#Find the one that ends after this block.

sub GetBlockIdNM(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $region = shift;
        my $sql = "SELECT ID,BLOCK,BITS FROM IPDB WHERE 
		BLOCK <= ".$block."::NUMERIC(40,0) 
		AND REGION = $region AND ALLOCATED NOTNULL 
		ORDER BY BLOCK DESC";
        my $sth = $dbh->prepare($sql);
	my $num = $sth->execute;
        if($sth->err){ 
		IPDBError(-1,$DBI::errstr);
	}
	my @out;
	while(@out = $sth->fetchrow){
                my $id = $out[0];
                my $start = $out[1];
               	my $bits = $out[2];
		my $ver = &Version($dbh,$id);
		my $end = $start + &Addresses($bits,$ver);
		if($end >= $block){
			my @foo;
			if($bits == 32 && $ver == 4){
				$foo[1] = 0;
			} else {
				$foo[1] = $block - $start;
			}
			$foo[0] = $id;
			return(@foo);
		}
        }
}

sub SetSerialDNS(){
	etrace(@_);
        my $dbh = shift;
        my $id = shift;
        my $cust = shift;
        my $port = shift;
        my $router = shift;
        my $zone = $router.".somewhere.net";
        my $zoneid = &GetZone($dbh,$zone);
        my $sthing1 = $port;
        my $sthing2 = $cust.".".$port;
        &IncSerial($dbh,$zoneid);
        &SetRevDNS($dbh,$id,$zoneid,1,$sthing1);
        &SetRevDNS($dbh,$id,$zoneid,2,$sthing2);
}

############ HERE ###################

sub SetRevDNS(){
	etrace(@_);
        my $dbh = shift;
        my $block = shift;
        my $zone = shift; # This is the forward zone.
        my $index = shift;
        my $sthing = shift;
        &IncSerial($dbh,$zone);
	my $sth = $dbh->prepare("SELECT HOSTNAME 
		FROM ZONE_RECORD_TABLE 
		WHERE BLOCK = $block AND INDEX = $index AND TYPE = 2");
	my $num = $sth->execute;
	if($sth->err){ 
		IPDBError(-1,$DBI::errstr);
	}
	$sthing = &CleanDNSText($sthing);
	$num =~ s/E.*//g;
	if($num){
		print "<BR>Updating existing entry";
		$sth = $dbh->prepare("UPDATE ZONE_RECORD_TABLE SET HOSTNAME = '$sthing' 
			WHERE BLOCK = $block AND INDEX = $index AND TYPE = 2");
		$sth->execute;
		$sth = $dbh->prepare("UPDATE ZONE_RECORD_TABLE SET ZONE = $zone 
			WHERE BLOCK = $block AND INDEX = $index AND TYPE = 2");
		$sth->execute;
		if($sth->err){
			IPDBError(-1,$DBI::errstr);
		}
	} else {
		print "<BR>Adding new entry";
		$sth = $dbh->prepare("INSERT INTO ZONE_RECORD_TABLE 
			(BLOCK,ZONE,INDEX,HOSTNAME,TYPE) 
			VALUES 
			($block,$zone,$index,'$sthing',2)");
		$sth->execute;
		if($sth->err){
			IPDBError(-1,$DBI::errstr);
		}
	}
}

sub SetFwdDNS(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $zone = shift;
	my $index = shift;
	my $sthing = shift;	
	&IncSerial($dbh,$zone);
	print "<BR>Adding new entry";
	$sthing = &CleanDNSText($sthing);
	$sthing =~ /^(.*)\.(.*)$/;
	my $sql = 'INSERT INTO zone_record_table (ZONE,TYPE,BLOCK,INDEX,HOSTNAME) VALUES (?,?,?,?)';
	my $sth = $dbh->prepare( $sql );
	$sth->execute( $zone, 1, $block, $index, $sthing );
	if($sth->err){ 
		IPDBError(-1,$DBI::errstr);
	}
}

sub ClearRevDNS(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $sth = $dbh->prepare( 'SELECT ID FROM ZONE_TABLE WHERE REVERSE_BLOCK=?' );
	my $num = $sth->execute( $block );
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
	my @out;
	while(@out = $sth->fetchrow){
		my $zone = $out[0];
		&IncSerial($dbh,$zone);
	}
	$sth = $dbh->prepare( 'UPDATE ZONE_TABLE SET own=?,REVERSE_BLOCK=NULL WHERE REVERSE_BLOCK=?' );
	$sth->execute( 'f', $block );
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
	$sth = $dbh->prepare("DELETE FROM ZONE_RECORD_TABLE WHERE BLOCK = $block AND TYPE = 2");
	$sth->execute;
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
	return(0);
}

sub SetRevZone(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $region = shift;
	my @ip = split(/\./,$block);
        my $RevZoneName = "$ip[2].$ip[1].$ip[0].in-addr.arpa";
	my $RevZone = &GetZone($dbh,$RevZoneName);
	my $blockname = "$ip[0].$ip[1].$ip[2].0";
	$block = &ip2deci($blockname);
	my $sql = "SELECT ID FROM IPDB WHERE BLOCK <= ".$block."::NUMERIC(40,0) AND REGION = $region AND BITS = 24 ORDER BY BLOCK DESC";
	my $sth = $dbh->prepare($sql);
	my $num = $sth->execute;
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
	$num =~ s/E.*//g;
	if($num){
		my @out = $sth->fetchrow;
		my $id = $out[0];
		$sth = $dbh->prepare( 'SELECT REVERSE_BLOCK FROM ZONE_TABLE WHERE ID=?' );
		$sth->execute( $RevZone );
		if($sth->err){
			IPDBError(-1,$DBI::errstr);
		}
		@out = $sth->fetchrow;
		unless($out[0]){
			$sth = $dbh->prepare( 'UPDATE ZONE_TABLE SET REVERSE_BLOCK = $id WHERE ID=?' );
			$sth->execute( $RevZone );
			if($sth->err){
				IPDBError(-1,$DBI::errstr);
			}
		}
	} else {
		&IPDBError(-1,"Can't find matching block");
	}
	&IncSerial($dbh,$RevZone);
}

sub DelegateBlock(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $host = shift;
	my @blck = GetBlockFromID($dbh,$block);
	my $ver = &Version($dbh,$block);
	my $addresses = &Addresses($blck[1],$ver);
	my $inip = deci2ip($blck[0],$ver);
	my @ip = split(/\./,$inip);
	my $RevZoneName = "$ip[2].$ip[1].$ip[0].in-addr.arpa";
	my $zone = &GetZone($dbh,$RevZoneName);
	# check for existing:
	my $sql = "SELECT ID FROM ZONE_RECORD_TABLE WHERE 
		TYPE = 6 AND HOSTNAME = '$host' AND BLOCK = $block";
	my $sth = $dbh->prepare($sql);
	my $num = $sth->execute;
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
	$num =~ s/E.*//g;
	if($num){
		&IPDBError(-1,"This block is already delegated to this host. $num");
	}
	$sql = "INSERT INTO ZONE_RECORD_TABLE (ZONE,BLOCK,HOSTNAME,INDEX,TYPE) 
		VALUES ($zone,$block,'$host',$addresses,6)";
	print "<!-- QUERY: $sql -->\n";
	&SetRevZone($dbh,$inip,$blck[2]);
	$sth = $dbh->prepare($sql);
	$num = $sth->execute;
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
}

sub GetZone(){
	etrace(@_);
        my $dbh = shift;
        my $zone = shift;
        my $i = 0;
        my @out;
	$out[0] = 1;
	my $insert = 0;
        my @Array = split(/\./,$zone);
        my @array = reverse(@Array);
	if($array[0] > 255){
		&IPDBError(-1,"Overflow Error: [ $array[0] $array[1] $array[2] $array[3] ]\n");
	}
        while($array[$i] ne "" ){
		my $sth = $dbh->prepare( 'SELECT ID FROM ZONE_TABLE WHERE NAME ~* ? AND PARENT=?' );
		my $num = $sth->execute( $array[$i], $out[0] );
		if($sth->err){
			IPDBError(-1,$DBI::errstr);
		}
		$num =~ s/E.*//g;
                unless($num){
                        $sth = $dbh->prepare( 'INSERT INTO ZONE_TABLE (NAME,PARENT,own) VALUES (?,?,?)' );
			$sth->execute( $array[$i], $out[0], 'f' );
			if($sth->err){
				IPDBError(-1,$DBI::errstr);
			}
                        $sth = $dbh->prepare( 'SELECT ID FROM ZONE_TABLE WHERE NAME=? AND PARENT=?' );
			$sth->execute( $array[$i], $out[0] );
			if($sth->err){
				IPDBError(-1,$DBI::errstr);
			}
			$insert = 1;
		} else {
		}
		@out = $sth->fetchrow;
                $i++;
        }
	#if(($array[0] eq "arpa") && $insert){
	#	$block = $array[2].".".$array[3].".".$array[4].".0";
	#}
        return($out[0]);
}

sub IncSerial(){
	etrace(@_);
        my $dbh = shift;
        my $zone = shift;
        my $sth = $dbh->prepare( 'SELECT SERIAL FROM ZONE_TABLE WHERE ID=?' );
	my $num = $sth->execute( $zone );
	$num =~ s/E.*//g;
        if($num){
		my @out = $sth->fetchrow;
                my $serial = $out[0];
                if($serial){
                        $serial++;
                        $sth = $dbh->prepare( 'UPDATE ZONE_TABLE SET SERIAL=? WHERE ID=?' );
			$sth->execute( $serial, $zone );
			if($sth->err){
				IPDBError(-1,$DBI::errstr);
			}
                } else {
			my $sql = 'UPDATE ZONE_TABLE SET SERIAL=1,REFRESH=?,RETRY=?,EXPIRE=?,TTL=? WHERE ID=?';
			my $sth = $dbh->prepare( $sql );
			$sth->execute( $config::config{DNS_Refresh}, $config::config{DNS_Retry}, $config::config{DNS_Expire}, $config::config{DNS_TTL},$zone);
			if($sth->err){
				IPDBError(-1,$DBI::errstr);
			}
                }
        } else {
		IPDBError(-1,"Could not incrament Serial # for ipdb.id $zone");
        }
}

sub DNSHead(){
	etrace(@_);
        my $dbh = shift;
        my $zone = shift;
	my $rev = shift;
	my $sth;
	if($rev){
		$sth = $dbh->prepare( 'SELECT SERIAL,REFRESH,RETRY,EXPIRE,TTL,ID FROM ZONE_TABLE WHERE REVERSE_BLOCK=? AND OWN = "t"' );
	} else {
		$sth = $dbh->prepare( 'SELECT SERIAL,REFRESH,RETRY,EXPIRE,TTL,ID FROM ZONE_TABLE WHERE ID=?' );
	}
	my $num = $sth->execute( $zone );
	if(my $err = $sth->err){&IPDBError(-1,"Could not get Zone info $err"); }	
	my @out = $sth->fetchrow;
        my $serial = $out[0];
        my $refresh = $out[1];
        my $retry = $out[2];
        my $expire = $out[3];
        my $ttl = $out[4];
        my $id = $out[5];
	print "\$TTL $config::config{DNS_TTL}\n";
	print "@		IN	SOA     $config::config{DNS_Host} $config::config{DNS_Email} (\n";
	printf("\t\t%-8d\t;Serial\n",$serial);
	printf("\t\t%-8d\t;Refresh\n",$refresh);
	printf("\t\t%-8d\t;Retry\n",$retry);
	printf("\t\t%-8d\t;Expire\n",$expire);
	printf("\t\t%-8d)\t;TTL\n",$ttl);
        my $ORIG = GetZoneString($dbh,$id);
        #if($rev){print "\$ORIGIN $ORIG\n";}

	my $sql = 'SELECT ID FROM ZONE_RECORD_TABLE WHERE ZONE=? AND TYPE=4 AND INDEX=255';
	$sth = $dbh->prepare( $sql );
	$num = $sth->execute( $zone );
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}
	my @DELE = $sth->fetchrow;
	unless($DELE[0]){
		print "\$INCLUDE ns\n";
	}

print <<EOF;
;/*---------------------------------------------------*/
;       WARNING WARNING WARNING WARNING WARNING
;
;       This reverse file is auto-generated. Any
;       manual changes WILL be lost. All changes
;       Are to be done via the FreeIPDB tool
;
;/*---------------------------------------------------*/
EOF
}

sub WalkZone(){
	etrace(@_);
	my $dbh = shift;
	my $zone = shift;
	my $sql = "SELECT TYPE,BLOCK,INDEX,HOSTNAME,TEXT,IP FROM zone_record_table WHERE ZONE = $zone";
	my $sth = $dbh->prepare($sql);
	my $num = $sth->execute;
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}	
	my @out;
        #print "\$INCLUDE ns\n";
	while(@out = $sth->fetchrow){
		my $type = $out[0];
		my $block = $out[1];
		my $index = $out[2];
		my $hostname = $out[3];
		my $text = $out[4];
		my $ip = $out[5];
		my @Block = &GetBlockFromID($dbh,$block);
		my $address = deci2ip(($Block[0] + $index),&Version($dbh,$Block[1]));
		if($type == 1){
			print "$hostname		IN	A	$address\n";
		} elsif ($type == 3) {
			print "$text		IN	CNAME	$hostname\n";	
		} elsif ($type == 4) {
			print "$text		IN	NS	$hostname\n";	
		}elsif ($type == 5 ){
			print "$text		IN	MX	$hostname\n";	
		}
	}
}

sub WalkReverseBlocks(){
	etrace(@_);
        my $dbh = shift;
        my $zone = shift;
        my $sth = $dbh->prepare("SELECT BLOCK,CHILDL,CHILDR,CUSTDESC,CUSTNUM,BITS,ALLOCATED FROM IPDB WHERE ID = $zone");
	my $num = $sth->execute;
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}	
	$num =~ s/E.*//g;
        if($num){
		my @out = $sth->fetchrow;
                my $childl = $out[1];
                my $childr = $out[2];
		my $desc = $out[3];
		my $cnum = $out[4];
		my $bits = $out[5];
		my $allocated = $out[6];
                if($childr){
                        &WalkReverseBlocks($dbh,$childl);
                        &WalkReverseBlocks($dbh,$childr);
                } else  {
                        my $block = $out[0];
			my $sth2 = $dbh->prepare( 'SELECT HOSTNAME,INDEX,ZONE,TYPE,TEXT,IP,BLOCK FROM ZONE_RECORD_TABLE WHERE BLOCK=? ORDER BY INDEX ASC,TYPE desc' );
                        my $num = $sth2->execute( $zone );
			my $bip = &deci2ip($block,4);
			if($allocated){
				unless($cnum){$cnum = "";} else {$cnum = "[$cnum]";}
				unless($desc){$desc = "";} else {$desc = " - ".$desc;}
				print "; $bip/$bits $cnum $desc\n";
				while(@out = $sth2->fetchrow){
					my $hostname = $out[0];
					my $index = $out[1];
					my $zone = $out[2];
					my $type = $out[3];
					my $text = $out[4];
					my $zip = $out[5];
					my $block = $out[6];
					my @blk = &GetBlockFromID($dbh,$block);
					my $ip = deci2ip($blk[0] + $index,4);
					if($type == 2){
						$zone = &GetZoneString($dbh,$zone);
						$ip = &LastOctet($ip);
						if($zone eq "."){ $zone = ""; }
						printf("%-3d",$ip);
						print "		IN	PTR	$hostname.$zone\n";
					} elsif ($type == 4){
						print "$text		IN	NS	$hostname\n";
					} elsif ($type == 6){
						if($bits == 24){
							#Assume we don't own the "B";
							print "@	IN	NS	$hostname.\n";
						} else {
							my $ip = deci2ip($blk[0],4);
							my $start = &LastOctet($ip);
							my $end = ($start + &Addresses($bits,4) - 1);
							print "$start-$end	IN	NS	$hostname.\n";
							print "\$GENERATE	$start-$end \$	CNAME	\$.$start-$end\n";
						}
					}
				}
			} else {
				print "; $bip/$bits Un-Allocated\n";
				my $ip = deci2ip($out[0],4);
				my $start = &LastOctet($ip);
				my $end = ($start + &Addresses($bits,4) - 1);
				$ip =~ s/\.[0-9]+$//;
				print "\$";
				print "GENERATE     $start-$end";
				print "\t\$	PTR	ip-$ip.\$.$config::config{DNS_Host}.\n";
			}
                }
        }
}

sub LastOctet(){
	etrace(@_);
        my $in = shift;
        my @array = split(/\./,$in);
        return($array[3]);
}

sub GetZoneString(){
	etrace(@_);
        my $dbh = shift;
        my $block = shift;
        my @out;
	my $zn = "";
	my $foo = "";
        my $sth = $dbh->prepare( 'SELECT NAME,PARENT FROM ZONE_TABLE WHERE ID=?' );
	my $num = $sth->execute( $block );
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}	
	$num =~ s/E.*//g;
        if($num){
		my @out = $sth->fetchrow;
                my $name = $out[0];
                my $parent = $out[1];
                if($parent){
                        $zn = &GetZoneString($dbh,$parent);
                        $foo = $name.".".$zn;
                } else {
                        $foo = $name;
                }
                $foo =~ s/^0$/./g;
		$foo =~ s/\.\././g;
		$sth->finish;
                return($foo);
        }
	return("");
}

sub Toggle(){
	etrace(@_);
	my $in = shift;
        if($in){
                print "   <TR BGCOLOR=$config::config{listcolorA}>";
                return(0);
        } else {
                print "   <TR BGCOLOR=$config::config{listcolorB}>";
                return(1);
        }
}


sub DNSForm(){
	etrace(@_);
        my $dbh = shift;
        my $block = shift;
        my $script = shift;
        print "<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>\n";
	my $delegated = &IsDelegated($dbh,$block);
	my $hasptr = &HasPTR($dbh,$block);
	my @block = &GetBlockFromID($dbh,$block);
	my $bits = $block[1];
	if($bits > 23 && $bits < 32){
		print "<FORM METHOD=GET><INPUT TYPE=HIDDEN NAME=ACTION VALUE=DNSEDIT>\n";
		print "<INPUT TYPE=HIDDEN NAME=BLOCK VALUE=$block>\n";
		unless($delegated){
			print "<FORM METHOD=GET><INPUT TYPE=HIDDEN NAME=ACTION VALUE=DNSEDIT>\n";
			print "<INPUT TYPE=HIDDEN NAME=BLOCK VALUE=$block>\n";
			print "<TR><TH>A</TH><TD>Hostname<INPUT NAME=HOSTNAME></TD><TD>IP:<SELECT NAME=INDEX>";
			&ListIPs($dbh,$block);
			print "</SELECT></TD><TD><INPUT TYPE=SUBMIT NAME=SUB VALUE=\"Add A\"></TD></TR>\n";
			print "</FORM>";
			print "<FORM METHOD=GET><INPUT TYPE=HIDDEN NAME=ACTION VALUE=DNSEDIT>\n";
			print "<INPUT TYPE=HIDDEN NAME=BLOCK VALUE=$block>\n";
			print "<TR><TH>CNAME</TH><TD>Hostname<INPUT NAME=HOSTNAME></TD><TD>Host:<INPUT NAME=AREC>";
			print "</TD><TD><INPUT TYPE=SUBMIT NAME=SUB VALUE=\"Add CNAME\"></TD></TR>\n";
			print "<FORM METHOD=GET><INPUT TYPE=HIDDEN NAME=ACTION VALUE=DNSEDIT>\n";
			print "<INPUT TYPE=HIDDEN NAME=BLOCK VALUE=$block>\n";
			print "<TR><TH>PTR</TH><TD>Hostname<INPUT NAME=HOSTNAME></TD><TD>IP:<SELECT NAME=INDEX>";
			&ListIPs($dbh,$block);
			print "</SELECT></TD><TD><INPUT TYPE=SUBMIT NAME=SUB VALUE=\"Add PTR\"></TD></TR>\n";
			print "</FORM>";
			print "<FORM METHOD=GET><INPUT TYPE=HIDDEN NAME=ACTION VALUE=DNSEDIT>\n";
			print "<INPUT TYPE=HIDDEN NAME=BLOCK VALUE=$block>\n";
			print "<TR><TH>A+PTR</TH><TD>Hostname<INPUT NAME=HOSTNAME></TD><TD>IP:<SELECT NAME=INDEX>";
			&ListIPs($dbh,$block);	
			print "</SELECT></TD><TD><INPUT TYPE=SUBMIT NAME=SUB VALUE=\"Add A+PTR\"></TD></TR>\n";
			print "</FORM>";
		}
		unless($hasptr){
			print "<FORM METHOD=GET><INPUT TYPE=HIDDEN NAME=ACTION VALUE=DNSEDIT>\n";
			print "<INPUT TYPE=HIDDEN NAME=BLOCK VALUE=$block>\n";
			print "<TR><TH>Delegate</TH><TD>Nameserver:<INPUT NAME=HOSTNAME></TD><TD>";
			print "(Must be an A-Record)</TD><TD><INPUT TYPE=SUBMIT NAME=SUB VALUE=\"Delegate Block\"></TD></TR>\n";
			print "</FORM>";
		}

        print "</TABLE></FORM>\n";
	}
}

sub ListIPs(){
	etrace(@_);
	my $dbh = shift;
	my $id = shift;
	my @block = GetBlockFromID($dbh,$id);
	my $ver = &Version($dbh,$id);
	my $count = &Addresses($block[1],$ver);
	my $i = 0;
	while($i != $count){
		my $address = &deci2ip(($block[0] + $i),$ver);
		print "<OPTION VALUE=$i>$address\n";
		$i++;
	}
}

sub DNSTable(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $script = shift;
	print "<TR><TD COLSPAN=7 ALIGN=CENTER><TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1 WIDTH=95%>\n";
	print "<TR><TH>Hostname</TH><TH>IP</TH><TH>Type</TH><TH>Functions</TH></TR>\n";
	my $sql = 'SELECT ID,HOSTNAME,INDEX,ZONE,TYPE FROM ZONE_RECORD_TABLE WHERE BLOCK = ?';
	my $sth = $dbh->prepare( $sql );
	my $num = $sth->execute( $block );
	if($sth->err){
		IPDBError(-1,$DBI::errstr);
	}	
	my @out;
	while(@out = $sth->fetchrow){
		my $id = $out[0];
		my $hostname;
		if($out[4] == 1 || $out[4] == 2){
			$hostname = $out[1].".".&GetZoneString($dbh,$out[3]);
		} else {
			$hostname = $out[1];
		}
		my @info = &GetBlockFromID($dbh,$block);
		my $ver = &VersionFromRegion($dbh,$info[2]);
		my $ip = deci2ip($info[0] + $out[2],$ver);
		my $type;
		if($out[4]){
			if($out[4] == 1){
				$type = "Forward";
			} elsif($out[4] == 2){
				$type = "Reverse";
			} elsif($out[4] == 3){
				$type = "CNAME";
			} elsif($out[4] == 4){
				$type = "NS";
			} elsif($out[4] == 5){
				$type = "MX";
			} elsif($out[4] == 6){
				$type = "Delegate";
			}
		}
		print "<TR><TD>$hostname</TD><TD>$ip</TD><TD>$type</TD><TD>";
		print a({href=>"?ACTION=DELETEDNS&EDIT=$block&ID=$id"},'[ Delete ]');
		print "</TR>\n";
	}
	print "</TABLE></TR>\n";
	$sth->finish;
}

sub ZoneTable(){
	etrace(@_);
	my $dbh = shift;
	my $script = shift;
	my $parent = shift;
	print "<TR><TH>Zone</TH><TH>Type</TH><TH>Serial</TH><TH>Retry/Refresh/";
	print "Expire/TTL</TH><TH>Status</TH><TH>State-change/Edit</TH></TR>\n";
	my $sql = "SELECT ID,OWN,SERIAL,RETRY,REFRESH,EXPIRE,TTL,REVERSE_BLOCK,NAME FROM ZONE_TABLE WHERE PARENT = $parent ORDER BY NAME";
	my $sth = $dbh->prepare($sql);
	if($sth->err){
		my $err = $DBI::errstr;
		&IPDBError(-1,"Could not query zone $err"); 
	}	
	my $num = $sth->execute;
	my @out;
	while(@out = $sth->fetchrow){
		my $id = $out[0];
		my $zone = &GetZoneString($dbh,$id);
		my $serial = $out[2];
		my $type;
		if($out[7]){
			$type = "Reverse";
		} else {
			$type = "Forward";
		}
		if(&CheckZone($dbh,$id) && $out[3] ){
			my $times = $out[3]." / ".$out[4]." / ".$out[5]." / ".$out[6];
			print "<TR><TD>$zone</TD><TD>$type</TD>\n";
			print "<TD>$serial</TD><TD>$times</TD>\n";
			my $status;
			if($out[1]){
				$status = "<TD BGCOLOR=#00FF00>Active</TD>\n";
			} else {
				$status = "<TD BGCOLOR=#FF0000>Disabled</TD>\n";
			}
			print "$status";
			print "<TD>";
			print
			  a({href=>"?ACTION=ZONEED&ZONEPARENT=$parent&ZONE=$id&OPER=Toggle State"},'[ Toggle State ]'), '&nbsp;',
			  a({href=>"?ACTION=ZONEED&ZONEPARENT=$parent&ZONE=$id&OPER=Edit Zone"},'[ Edit Zone ]'), '&nbsp;',
			  a({href=>"?ACTION=ZONEED&ZONEPARENT=$parent&ZONE=$id&OPER=View Zone"},'[ View Zone ]');
			print "</TD></TR>\n";
		}
		if(&ZoneChild($dbh,$id) != 0){
			print "<TR><TD>$out[8]</TD><TD>Parent</TD><TD>$zone</TD>\n";
			print "<TD>&nbsp;</TD><TD>&nbsp;</TD><TD>";
			print a({href=>"?ACTION=ZONEED&ZONEPARENT=$id"},'[ Drill-Down ]');
			print "</TD></TR>\n";
		}
		print "</FORM>\n";
	}
	$sth->finish;
	print "<TR><TD COLSPAN=6>";
	print "<INPUT TYPE=SUBMIT VALUE=\"Change State(s)\">";
	print "</TR>";
	print "</FORM>";
}

sub ToggleZone(){
	etrace(@_);
	my $dbh = shift;
	my $zone = shift;
	#Get current state
	my $sql = "SELECT OWN FROM ZONE_TABLE WHERE ID = $zone";
	my $sth = $dbh->prepare($sql);
	my $num = $sth->execute;
	if($sth->err){
		my $err = $DBI::errstr;
		&IPDBError(-1,"Could not query block's current state $err"); 
	}
	my @out = $sth->fetchrow;
	#Set new state.
	if($out[0]){
		$sql = "UPDATE ZONE_TABLE SET OWN = 'f' WHERE ID = $zone";
	} else {
		$sql = "UPDATE ZONE_TABLE SET OWN = 't' WHERE ID = $zone";
	}
	$sth = $dbh->prepare($sql);
	$num = $sth->execute;
	if($sth->err){
		my $err = $DBI::errstr;
		&IPDBError(-1,"Could not change block's current state $err"); 
	}
}

sub DeleteDNSRecord(){
	etrace(@_);
	my $dbh = shift;
	my $id = shift;
	if($id){
		my $sql = "DELETE FROM ZONE_RECORD_TABLE WHERE ID = $id";
		my $sth = $dbh->prepare($sql);
		my $num = $sth->execute;
		if($sth->err){
			my $err = $DBI::errstr;
			&IPDBError(-1,"Could not Delete record $err"); 
		}
		return(0);
	} else {
		&IPDBError(-1,"No Zone_Record ID to delete");
	}
}

sub RwhoisForm(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $netname = shift;
	# Choose known org || Create New one.
}


sub DataDump(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $bits = shift;
	my $region = shift;
	use Math::BigInt;
	my $ip = Math::BigInt->new(ip2deci($block));
	$ip =~ s/^\+//g;
	my $id = &GetBlockId($dbh,$ip,$bits,$region);
	if($id){
		&DumpHead();
		&BlockDump($dbh,$id);
		print "</PRE>\n";
	} else {
		&IPDBError(-1,"Could not get Block ID");
	}
}

sub DumpHead(){
	etrace(@_);
	print "<PRE>\n";
	print "IP Address:Netmask(bits):Region:$config::config{custnum_f}:$config::config{custname_f}:Allocated Timestamp\n";
	print "==========================================================\n";
}

sub BlockDump(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	# Check if block is child or parent
	my $sql = 'SELECT BLOCK,BITS,REGION,CHILDL,CHILDR,custnum,custdesc,ALLOCATED,ID FROM IPDB WHERE ID=?';
	my $sth = $dbh->prepare( $sql );
	my $num = $sth->execute( $block );
	if($sth->err){
		my $err = $DBI::errstr;
		&IPDBError(-1,"Could not get Block record $err"); 
	}
	my @out;
	if(@out = $sth->fetchrow){
		if($out[3]){
			&BlockDump($dbh,$out[3]);
			&BlockDump($dbh,$out[4]);
		} else {
			my $ver = &Version($dbh,$out[8]);
			my $ip = &deci2ip($out[0],$ver);
			my $region = &LookupRegion($dbh,$out[2]);
			print "$ip:$out[1]:$region:";
			print "$out[5]:$out[6]:$out[7]";
			print "\n";
		}
	
	} else {	
		&IPDBError(-1,"No result for block");
	}
}

sub GetFileSerial(){
	etrace(@_);
        my $filename = shift;
        if(-e $filename){
                open(FILE,"<$filename")|| die "Can't open $filename for reading $!";
                while(<FILE>){
                        if($_ =~ m/^\s*([0-9]*)\s*;Serial\n/){
                                return($1);
                        }
                }
                close(FILE);
        } else {return(0);}
}

sub GetZoneSerial(){
	etrace(@_);
        my $dbh = shift;
        my $zone = shift;
        my $rev = shift;
        my $sth;
        if($rev){
                $sth = $dbh->prepare('SELECT SERIAL,REFRESH,RETRY,EXPIRE,TTL,ID FROM ZONE_TABLE WHERE REVERSE_BLOCK=? AND own="t"');
        } else {
                $sth = $dbh->prepare('SELECT SERIAL,REFRESH,RETRY,EXPIRE,TTL,ID FROM ZONE_TABLE WHERE ID=?');
        }
        my $num = $sth->execute( $zone );
        if(my $err = $sth->err){&IPDBError(-1,"Could not get Zone info $err [$zone]"); }
        my @out = $sth->fetchrow();
        my $serial = $out[0];
        return($serial);
}

sub routeview_report(){
	etrace(@_);
	my $dbh = shift || &IPDBError(-1,"No Database connection provided");
	my $prompt = "/route-views.oregon-ix.net>/";
	my $t = new Net::Telnet (Timeout => 20, Errmode => "return");
	$t->dump_log('/tmp/ipdb_tmp');
	$t->open(Host => "route-views.oregon-ix.net",Source_port => "50000", Source_host => "64.210.24.60");
	$t->waitfor($prompt);
	my @lines = $t->cmd(String => "terminal length 0",Prompt => "/route-views.oregon-ix.net>/");
	my $sql = "SELECT ID,BLOCK,BITS FROM IPDB WHERE ALLOCATED=NULL AND REGION=1";
	my $sth = $dbh->prepare($sql);
	my $num = $sth->execute;
	my $i = 0;
	my @out;
	while($i != $num){
		my @get = $sth->fetchrow;
		my $ip = &deci2ip($get[1],4);
		my $netmask = &deci2ip(makemask($get[2],4),4);
		my $req = "show ip bgp $ip/$get[2]";
		$t->cmd(String =>"",Prompt => "/route-views.oregon-ix.net>/");
		my($lines) = $t->cmd(String => $req,Prompt => "/route-views.oregon-ix.net>/");
		if($lines){
			if($lines !~ m/Network not in table/){
				print "\n---------------------------------------\n";
				printf("--- %15s %15s ---\n",$ip,$netmask);
				print "---------------------------------------\n";
				my @out = $t->cmd(String => $req,Prompt => "/route-views.oregon-ix.net>/");
				print @out;
			}
		}
		$i++;
	}
	$t->close;
}

sub GetBlockFromZone(){
	etrace(@_);
	my $dbh = shift;
	my $zone = shift;
	my $sthing = &GetZoneString($dbh,$zone);
	my @str = split(/\./,$sthing);
	my $ip = "$str[2].$str[1].$str[0].0";
	my $block = ip2deci($ip);
	my $sql = "SELECT ID FROM IPDB WHERE BLOCK = ".$block."::NUMERIC(40,0) AND BITS = 24";
	my $sth = $dbh->prepare($sql);
	my $num = $sth->execute;
	my @out = $sth->fetchrow;
	return($out[0]);
}

sub IsReverse(){
	etrace(@_);
	my $dbh = shift;
	my $zone = shift;
	my $sql = 'SELECT REVERSE_BLOCK FROM ZONE_TABLE WHERE ID=?';
	my $sth = $dbh->prepare( $sql );
	my $num = $sth->execute( $zone );
	my @out = $sth->fetchrow;
	return($out[0]);
}

sub SOAEdit(){
	etrace(@_);
	my $dbh = shift;
	my $zone = shift;
	
}
sub EditRevZone(){
	etrace(@_);
	my $dbh = shift;
	my $zone = shift;
}
sub EditFwdZone(){
	etrace(@_);
	my $dbh = shift;
	my $zone = shift;
}

sub CleanDNSText(){
	etrace(@_);
	my $sthing = shift;
	$sthing =~ s/[\/:_]/-/g;
	$sthing =~ s/,/./g;
	$sthing =~ s/[ ]//g;
	$sthing =~ s/--//g;
	$sthing =~ s/^-//g;
	$sthing =~ s/-$//g;
	$sthing =~ s/\.\././g;
	$sthing =~ s/-\././g;
	if($sthing !~ m/^[a-zA-Z]/){
		&IPDBError(-1,"Hostname must start with a letter! (not |$sthing|");
	}
	return($sthing);
}

sub IsDelegated(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $sql = 'SELECT ID FROM ZONE_RECORD_TABLE WHERE TYPE=6 AND BLOCK=?';
	print "<!-- QUERY:$sql BLOCK:$block -->\n";
	my $sth = $dbh->prepare( $sql );
	my $num = $sth->execute( $block );
	$num =~ s/E.*//g;
	return($num);
}

sub HasPTR(){
	etrace(@_);
	my $dbh = shift;
	my $block = shift;
	my $sql = 'SELECT ID FROM ZONE_RECORD_TABLE WHERE TYPE=2 AND BLOCK=?';
	print "<!-- QUERY:$sql BLOCK:$block -->\n";
	my $sth = $dbh->prepare( $sql );
	my $num = $sth->execute( $block );
	$num =~ s/E.*//g;
	return($num);
}

sub GetNetworkSerial(){
	etrace(@_);
        my $name = shift;
        open(NS,"nslookup -query=soa $name|");
	my $serial;
        while(<NS>){
                my $line = $_;
                if($line =~ m/serial = ([0-9]*)/){
                        $serial = $1;
                        last;
                }
        }
        close(NS);
        return($serial);
}

sub SerialZoneCheck(){
	etrace(@_);
        my $dbh = shift;
        my $in = shift;
        my $text = shift;
        my $sql = "SELECT ID,NAME,SERIAL FROM ZONE_TABLE WHERE OWN = 't'";
        my $sth = $dbh->prepare($sql);
        my $num = $sth->execute;
        my @out;
        my $COMMANDS = "";
        printf("|-------|--------------------------------|------------|------------|\n");
        printf("|  ID   |  Zone Name                     | ipdb       | DNS        |\n");
        printf("|-------|--------------------------------|------------|------------|\n");
        while(@out = $sth->fetchrow){
                my $NAME = &GetZoneString($dbh,$out[0]);
                my $serial = &GetNetworkSerial($NAME);
                if($serial != $out[2]){
                        printf("| %5d | %30s | %10d | %10d |\n",$out[0],$NAME,$out[2],$serial);
                        $serial++;
                        if($serial > $out[2]){
                                $COMMANDS .= "UPDATE ZONE_TABLE SET SERIAL = $serial WHERE ID = $out[0];\n";
                        } else {
                                $COMMANDS .= "--CHECK $NAME not updating\n";
                        }

                }
        }
        printf("|-------|--------------------------------|------------|------------|\n");
        print "$COMMANDS";
}



1;
