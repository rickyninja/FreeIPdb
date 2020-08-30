#!/usr/bin/perl
#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#	index.cgi-$Name:  $-$Revision: 1.24 $ $Date: 2002/04/29 18:59:02 $ <$Author: bapril $@freeipdb.org>
######################################################################

use strict;
use warnings;
require 'ipdb_httpcgi.pl';

use config;
use CGI qw( :standard :cgi-lib );
use DBI;
$config::config{'_REMOTE_USER'} = $ENV{'REMOTE_USER'};
$config::config{'_REMOTE_ADDR'} = $ENV{'REMOTE_ADDR'};
$config::config{'debug'} = 1;

$| = 1;

my $css = <<EOF;
body
{
  font-family: Verdana,arial,helvetica,sans;
  font-size: 11px;
  color:#330000;
}
th
{
  font: verdana 16px normal bold;
  color: #ffffff;
  background-color: blue;
}
td
{
  font-family: verdana 11px normal;
  color:#000000;
  background-color:#eeeeee;
}
/* end default font*/

/* links */
a         {color:#101010; text-decoration: underline; }
a:visited {color:#101010; }
a:active  {color:#808080; }
a:hover   {color:#ff4040; }
EOF


print
  header,
  start_html
  (
    -head  => meta({ -http_equiv => 'PRAGMA', -content => 'NO-CACHE' }),
    -title => $config::config{ver},
    -style => { -code => [ $css ] },
  );


my $conn = DBI->connect("DBI:Pg:dbname=$config::config{dbname};host=$config::config{dbhost};port=$config::config{dbport}", $config::config{dbuser}, $config::config{dbpass});

my $script = get_cgi($0);
our %FORM = Vars;


if( $FORM{BLOCK} && $FORM{BLOCK} =~ /([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\/([0-9]{1,2})/ )
{
	$FORM{BLOCK} = $1;
	$FORM{BITS} = $2;
}

if( ! $FORM{ACTION} )
{
  goto MAIN;
}
elsif( $FORM{ACTION} eq 'RECLAIM' )
{
	if($config::config{confirm_reclaim}){
		if( $FORM{CONFIRM} ) {
			if( $FORM{CONFIRM} eq $FORM{CONFIRM2} ){
				print "CONFIRM:\n";
				unless(&ClearRevDNS($conn,$FORM{RECLAIM})){
					unless(&ReclaimBlock($conn,$FORM{RECLAIM})){
						print "Reclaim Block ".$FORM{RECLAIM}." CONFIRMED\n <BR>";
					}
				}
			} else {
				print "Confirm Failed\n";
				&ReclaimConfirm($conn,$FORM{RECLAIM});
				&printTail();
				$conn->disconnect;
				exit();
			}
		} else {
			&ReclaimConfirm($conn,$FORM{RECLAIM});
			&printTail();
			$conn->disconnect;
			exit();
		}
	} else {
		#procede to reclaim
		unless(&ClearRevDNS($conn,$FORM{RECLAIM})){
			unless(&ReclaimBlock($conn,$FORM{RECLAIM})){
				print "Reclaim Block ".$FORM{RECLAIM}."\n <BR>";
			}
		}
	}
	goto MAIN;
}
elsif( $FORM{ACTION} eq 'UPDATE' )
{
	&UpdateBlock($conn,$FORM{UPDATE},$FORM{REGION},$FORM{CUSTOMER},$FORM{CUSTDESC});
	print "Block Updated\n";
	$FORM{ACTION} = 'EDIT'; # Show edit form with new values.
	$FORM{EDIT} = $FORM{UPDATE};
	goto MAIN;
}
elsif( $FORM{ACTION} eq 'DNSEDIT' )
{
	if($FORM{'SUB'} =~ /Add A\+PTR/){
		print "Creating Forward and Reverse DNS Record for $FORM{'HOSTNAME'}<BR>\n";
		my $host = &CleanDNSText($FORM{'HOSTNAME'});
		$host =~ s/^([a-zA-Z0-9-]+)\.//;
		my $zone = &GetZone($conn,$host);
		$host = $1;
		&SetFwdDNS($conn,$FORM{'BLOCK'},$zone,$FORM{'INDEX'},$host);
		&SetRevDNS($conn,$FORM{'BLOCK'},$zone,$FORM{'INDEX'},$host);
	} elsif($FORM{'SUB'} =~ /Add A/){
		#Add A Record
		print "Creating Forward DNS Record for $FORM{'HOSTNAME'}<BR>\n";
		my $host = &CleanDNSText($FORM{'HOSTNAME'});
		$host =~ s/^([a-zA-Z0-9-]+)\.//;
		my $zone = &GetZone($conn,$host);
		$host = $1;
		&SetFwdDNS($conn,$FORM{'BLOCK'},$zone,$FORM{'INDEX'},$host);
	} elsif($FORM{'SUB'} =~ /Add CNAME/){
		#Add CNAME
	} elsif($FORM{'SUB'} =~ /Add MX/){
		#Add MX record
	} elsif($FORM{'SUB'} =~ /Add NS/){
		#Add NS Record
	} elsif($FORM{'SUB'} =~ /Add PTR/){
		#Add PTR record.
		print "Creating Reverse DNS Record for $FORM{'HOSTNAME'}<BR>\n";
		my $host = &CleanDNSText($FORM{'HOSTNAME'});
		$host =~ s/^([a-zA-Z0-9-]+)\.//;
		my $zone = &GetZone($conn,$host);
		$host = $1;
		&SetRevDNS($conn,$FORM{'BLOCK'},$zone,$FORM{'INDEX'},$host);
	} elsif($FORM{'SUB'} =~ /Delegate Block/){
		my $host = &CleanDNSText($FORM{'HOSTNAME'});
		if($host ne $FORM{'HOSTNAME'}){&IPDBError(-1,"Hostname supplied for Delegation is illegal");}
		#Delegate full block.
		&DelegateBlock($conn,$FORM{'BLOCK'},$FORM{'HOSTNAME'});
		print "Delegating block to:$FORM{'HOSTNAME'}\n";
	}
	$FORM{'ACTION'} = "EDIT"; # Show edit form with new values.
	$FORM{'EDIT'} = $FORM{'BLOCK'};
	goto MAIN;
}
elsif( $FORM{ACTION} eq 'DELETEDNS' )
{
	&DeleteDNSRecord($conn,$FORM{'ID'});
	print "DNS Record Deleted.";
	$FORM{'ACTION'} = "EDIT"; # Show edit form with new values.
	goto MAIN;
}
elsif( $FORM{ACTION} eq 'EDIT' )
{
	&EditForm($conn,$FORM{'EDIT'},$script);
	if($config::config{allowDNS}){
		&DNSTable($conn,$FORM{'EDIT'},$script);
		&DNSForm($conn,$FORM{'EDIT'},$script);
	}
	&printTail();
	$conn->disconnect;
	exit();
}
elsif( $FORM{ACTION} eq 'CLEARHOLD' )
{
	print "Clear holdtime on block $FORM{'EDIT'}<BR>\n";
	&ClearHoldtime($conn,$FORM{'EDIT'});
	print "Success!\n";
	&printTail();
	$conn->disconnect;
	exit();
}
elsif( $FORM{ACTION} eq 'ASSIGN' )
{
	my @block = &GetBlockFromID($conn,$FORM{'UPDATE'});
	print "Here $FORM{'UPDATE'} $block[0]/$block[1]";
	my $ver = &VersionFromRegion($conn,$FORM{'REGION'});
	my $ip = deci2ip($block[0],$ver);
	my $id = &SetBlockP($conn,$ip,$FORM{'REGION'},$block[1],$FORM{'CUSTDESC'},$FORM{'CUSTOMER'},$ver);
	print "Assigned\n";
	goto MAIN;
}
elsif( $FORM{ACTION} eq 'SUBMIT6' )
{
	print "Reclaim?";
	if($FORM{'ACCEPT'}){
		print "Done!\n";
	}
	if($FORM{'DENY'}){
		&ReclaimBlock($conn,$FORM{'BLOCK'});
	}
	goto MAIN;
}
elsif( $FORM{ACTION} eq 'ZONEED' )
{
	if($FORM{'OPER'} =~ /Toggle State/){
		&ToggleZone($conn,$FORM{'ZONE'});
	} elsif($FORM{'OPER'} =~ /Edit Zone/){
		print "Edit Zone $FORM{'ZONE'}\n";
		&SOAEdit($conn,$FORM{'ZONE'});
		if(&IsReverse($conn,$FORM{'ZONE'})){
			&EditRevZone($conn,$FORM{'ZONE'});
		} else {
			&EditFwdZone($conn,$FORM{'ZONE'});
		}
	} elsif($FORM{'OPER'} =~ /View Zone/){
		print "Zone: $FORM{'ZONE'}\n";
		print "<PRE>\n";
		&DNSHead($conn,$FORM{'ZONE'},0);
		if(&IsReverse($conn,$FORM{'ZONE'})){
			my $block = &GetBlockFromZone($conn,$FORM{'ZONE'});
			&WalkReverseBlocks($conn,$block);
		} else {
			&WalkZone($conn,$FORM{'ZONE'});
		}
		print "</PRE>\n";
		&printTail();
		$conn->disconnect;
		exit();
	} else{
		print "<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>\n";
		&ZoneTable($conn,$script,$FORM{'ZONEPARENT'});
		print "</TABLE>\n";
		&printTail();
		$conn->disconnect;
		exit();
	}
}
elsif( $FORM{ACTION} eq 'DATADUMP' )
{
	my $exit = 0;
	if($FORM{'REGION'} =~ /---/){
		print "<TR><TD><H1>Must Select Region </TD></TR>\n";
		$exit = 1;
	}
	if($FORM{'BLOCK'}){
		if($FORM{'BLOCK'} =~ m/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\/([0-9]{1,2})/){
			$FORM{'BLOCK'} = $1;
			$FORM{'BITS'} = $2;
		} elsif ($FORM{'BLOCK'} =~ m/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/ && $FORM{'BITS'}){
			$FORM{'BLOCK'} = $1;
		} elsif ($FORM{'BLOCK'} =~ m/([0-9A-F]{4}:[0-9A-F]{4}:[0-9A-F]{4}:[0-9A-F]{4}:[0-9A-F]{4}:[0-9A-F]{4}:[0-9A-F]{4}:[0-9A-F]{4})\/([0-9]{1,3})/){
			$FORM{'BLOCK'} = $1;
			$FORM{'BITS'} = $2;
		} else {
			print "<TR><TD><H1>Bad IP block format.</TD></TR>\n";
			#exit = 1;
		}
		if($exit){ 
			print "</TABLE>";
			&printTail();
			$conn->disconnect;exit();
		} # Bail Missing some info.
		&DataDump($conn,$FORM{BLOCK},$FORM{BITS},$FORM{'REGION'});
	} else {
		my @List = &RegionAllocations($conn,$FORM{'REGION'});
		my $i = 0;
		my $ver = &Version($conn,$FORM{'REGION'});
		while($List[$i]){
			my @block = &GetBlockFromID($conn,$List[$i]);
			my $ip = &deci2ip($block[0],$ver);
			&DataDump($conn,$ip,$block[1],$FORM{'REGION'});
			$i++;
		}
	}
	&printTail;
	exit();
}
elsif( $FORM{ACTION} eq 'SEARCHLOG' )
{
	&LogHead();
	&LogSearch($conn,$FORM{'REGION'});
	&printTail;
	exit();
}
elsif( $FORM{ACTION} eq 'REQ' )
{
	print "<table WIDTH=100% COLS=2>\n";
	my $exit = "";
	if($FORM{'REGION'} =~ /---/){
		print "<TR><TD><H1>Please go back and choose a REGION</TD></TR>\n";
		$exit = 1;
	}
	if($FORM{'BITS'} =~ /---/){
		print "<TR><TD><H1>Please go back and choose a Block Size</TD></TR>\n";
		$exit = 1;
	}
	if($FORM{'HOSTNAME'}){
		print "<TR><TD><H1>Can't Sethostname and request a block at the same time </TD></TR>\n";
		$exit = 1;
	}
	if($config::config{'custname_r'} && $config::config{'custname'}){
		if(!$FORM{'CUSTDESC'}){
			print "<TR><TD><H1>No $config::config{'custname_f'}</TD></TR>\n";
			$exit = 1;
		}
	}
	if($config::config{'custnum_r'} && $config::config{'custnum'}){
		if(!$FORM{'CUSTOMER'}){
			print "<TR><TD><H1>No $config::config{'custnum_f'}</TD></TR>\n";
			$exit = 1;
		}
	}
	if($config::config{'allowRwhois'}){
		if($FORM{'ADMINC'} =~ /---/){
			print "<TR><TD><H1>Please Choose an Admin Contact</TD></TR>\n";
			$exit = 1;
		}
		if($FORM{'TECHC'} =~ /---/){
			print "<TR><TD><H1>Please Choose an Tech Contact</TD></TR>\n";
		}
		if($config::config{'requireRwhois'}){
			if(!$FORM{'NETNAME'}){
				print "<TR><TD><H1>No NetName</TD></TR>\n";
				$exit = 1;
			} elsif (!$FORM{'ORG'}) {
				print "Rwhois Form";
				#&RwhoisForm($conn,,$FORM{'NETNAME'});
				$exit = 1;
			}
		}
	}
	if($exit){ 
		print "</TABLE>";
		&printTail();
		$conn->disconnect;
		exit();
	} # Bail Missing some info.
	print "<tr>\n";
	print "<td COLSPAN=2 bgcolor=\"$config::config{'headcolor'}\" color=\"$config::config{'headtextcolor'}\" face=\"Arial,Helvetica\">";
	print "<center><b>Confirm New IP Block Assignment</b></center></font></td>\n";
	print "</tr>\n";
	print "<TR><TD>";
	my $newblock = &GetNewBlock($conn,$FORM{'REGION'},$FORM{'BITS'},$FORM{'CUSTDESC'},$FORM{'CUSTOMER'});
	print "</TD></TR><TR><TD>\n";
	print "<form METHOD=GET ACTION=$script >";
	print "<INPUT TYPE=HIDDEN NAME=ACTION VALUE=SUBMIT6>";
	print "<INPUT TYPE=HIDDEN NAME=BLOCK VALUE=$newblock>";
	print "<INPUT TYPE=SUBMIT NAME=ACCEPT VALUE=\"Confirm Allocation\">";
	print "<INPUT TYPE=SUBMIT NAME=DENY VALUE=\"Cancel Allocation\">";
	print "</TD></TR>";
	print "</TABLE></FORM>";
	&printTail();
	$conn->disconnect;
	exit();
}
elsif( $FORM{ACTION} eq 'SEARCH' )
{
	my $block = "";
	if($FORM{'BLOCK'}){
		$block = &IP2Deci($FORM{'BLOCK'});
	}
	my $region = $FORM{'REGION'};
	my $bits = $FORM{'BITS'};
	my $cust = $FORM{'CUSTOMER'};
	my $custdesc = $FORM{'CUSTDESC'};
	my $hostname = $FORM{'HOSTNAME'};
	my $id = $FORM{'BLOCKID'};
	print "<!-- BLOCK $block REGION $region BITS $bits CUST $cust CUSTDESC $custdesc HOSTNAME $hostname-->\n";
	&AllocatedSearch_Head();
	&AllocatedSearch($conn,$script,1,$id,$block,$bits,$region,$cust,$custdesc,$hostname,1);
	print "</TABLE></FORM>";
        &printTail();
	$conn->disconnect;
        exit();
}
elsif( $FORM{ACTION} eq 'RECURSE' )
{
	my $id1 = $FORM{'CHILDL'};
	my $id2 = $FORM{'CHILDR'};
	&AllocatedSearch_Head();
	&AllocatedSearch($conn,$script,1,$id1);
	&AllocatedSearch($conn,$script,1,$id2);
	print "</TABLE></FORM>";
        &printTail();
	$conn->disconnect;
	exit();
}
elsif( $FORM{ACTION} eq 'LISTFREE' )
{
	print "<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>";
	print "<TR><TH>REGION</TH><TH>Block</TH><TH>Reclaim</TH><TH>ID</TH><TH>Holdtime</TH></TR>\n";
	&FreeList($conn);
	print "</TABLE></FORM>";
	&printTail();
	$conn->disconnect;
	exit();
}
elsif( $FORM{ACTION} eq 'SETDNS' )
{
	# Check for hostname and an IP address.
	my $exit = 0;
	if($FORM{'HOSTNAME'} =~ m/[^A-Za-z0-9\.-]/){
                print "<TR><TD><H1>Hostname contains invalid symbols.</TD></TR>\n";
                $exit = 1;
	}
        if($exit){ 
		print "</TABLE>";
		&printTail();
		$conn->disconnect;
		exit();
	} # Bail Missing some info.
	if($FORM{'BLOCK'} && $FORM{'HOSTNAME'} && ($FORM{'REGION'} !~ m/---/)){
		print "<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>";
		my $fqdn = $FORM{'HOSTNAME'};
		$fqdn =~ m/^([0-9A-Za-z-]*)\.(.*)$/;
		my $hostname = $1;
		$hostname =~ s/[\/:_]/-/g;
		$hostname =~ s/[ ]//g;
		$hostname =~ s/--//g;
		$hostname =~ s/^-//g;
		$hostname =~ s/\.\././g;
		$hostname =~ s/-\././g;
		my $zone = $2;
		$zone =~ s/[\/:_]/-/g;
		$zone =~ s/[ ]//g;
		$zone =~ s/--//g;
		$zone =~ s/^-//g;
		$zone =~ s/\.\././g;
		$zone =~ s/-\././g;
		my $ForZone = &GetZone($conn,$zone);
		#Get Block ID and Offset.
		my $BLK = ip2deci($FORM{'BLOCK'});
		my @blk = &GetBlockIdNM($conn,$BLK,$FORM{'REGION'});
		my $block = $blk[0];
		my $index = $blk[1];
		unless($block){
			print "Block not allocated.(Can't assign DNS)";
		} else {
			#Set the reverse enrty.
			if($FORM{'DNSTYPE'} eq "REV" || $FORM{'DNSTYPE'} eq "BOTH"){
				print "Set Reverse DNS for $FORM{'BLOCK'} to $fqdn { $index }<BR>\n";
				&SetRevDNS($conn,$block,$ForZone,$index,$hostname);
				&SetRevZone($conn,$FORM{'BLOCK'},$FORM{'REGION'});
			}
			#Get/Create the Forward Block ID
			#Set the forward entry.
			if($FORM{'DNSTYPE'} eq "FWD" || $FORM{'DNSTYPE'} eq "BOTH"){
				print "Set Forward DNS for $FORM{'BLOCK'} to $fqdn<BR>\n";
				&SetFwdDNS($conn,$block,$ForZone,$index,$hostname);
			}
		}
		print "</TABLE>";
	} else {
		print "<H1><FONT COLOR=RED>No IP address ,region or hostname set</FONT></H1>\n";
		&printTail();
		$conn->disconnect;
		exit();
	}
}

exit;

MAIN:
print <<EOF;
  <FORM ACTION=$script METHOD=GET>
  <TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>
   <tr>
     <th COLSPAN="2" ALIGN="CENTER">$config::config{'ver'}</td>
   </tr>
   <tr>
     <td>
        Block:
     </td>
     <td>
        <INPUT NAME=BLOCK SIZE=20>
     </td>
   </tr>
   <tr>
     <td>
       Subnet Mask:
     </td>
     <td>
       <select NAME="BITS">
         <option selected>--- Please Choose --
         <option value="32">/32 - 1 IP
         <option value="30">/30 - 4 IPs
         <option value="29">/29 - 8 IPs
         <option value="28">/28 - 16 IPs
         <option value="27">/27 - 32 IPs
         <option value="26">/26 - 64 IPs
         <option value="25">/25 - 128 IPs
         <option value="24">/24 - 256 IPs (1 Class C)
         <option value="23">/23 - 512 IPs (2 Class Cs)
         <option value="22">/22 - 1024 IPs (4 Class Cs)
         <option value="21">/21 - 2048 IPs (8 Class Cs)
         <option value="20">/20 - 4096 IPs (16 Class Cs)
         <option value="19">/19 - 8192 IPs (32 Class Cs)
         <option value="18">/18 - 16384 IPs (64 Class Cs)
         <option value="17">/17 - 32768 IPs (128 Class Cs)
         <option value="16">/16 - (1 Class B)
         <option value="15">/15 - (2 Class Bs)
         <option value="14">/14 - (4 Class Bs)
         <option value="12">/13 - (8 Class Bs)
         <option value="12">/12 - (16 Class Bs)
         <option value="11">/11 - (32 Class Bs)
         <option value="10">/10 - (64 Class Bs)
         <option value="9">/9 - (128 Class Bs)
         <option value="8">/8 - (1 Class A)
EOF

        print "<option value=$_>/$_ - IPV6\n" for 35..128;

	print <<EOF;
        </select>
       </td>
     </tr>
     <tr>
       <td>
        Region:
       </td>
       <td>
        <SELECT NAME=REGION>
         <OPTION> --- Please Choose ---
EOF
&ListRegions($conn);
print <<EOF;
        </SELECT>
       </td>
     </tr>
EOF
if($config::config{'custname'}){
print <<EOF;
      <tr>
       <td>
        <NOBR>
        $config::config{'custname_f'}:
        </NOBR>
       </td>
       <td>
        <INPUT NAME=CUSTDESC SIZE=20>
       </td>
      </tr>
EOF
}
if($config::config{'custnum'}){
print <<EOF;
      <tr>
       <td>
        <NOBR>
        $config::config{'custnum_f'}:
        </NOBR>
       </td>
       <td>
        <INPUT NAME=CUSTOMER SIZE=20>
       </td>
      </tr>
EOF
}
if($config::config{'allowDNS'}){
print <<EOF;
      <TR>
       <TD> 
        Hostname:
       </TD>
       <TD>
        <NOBR>
        <INPUT NAME=HOSTNAME SIZE=20>  
        Set :
        <SELECT NAME=DNSTYPE>
         <OPTION VALUE=BOTH>Both forward and reverse
         <OPTION VALUE=REV>Reverse Only
         <OPTION VALUE=FWD>Forward Only
        </SELECT>
        </NOBR>
       </TD>
      </TR>
EOF
}
if($config::config{'allowRwhois'}){
print <<EOF;
      <TR>
       <TD> 
        Rhowis:
       </TD>
       <TD>
        Net-Name:<INPUT NAME=NETNAME>
	Admin-c:<SELECT NAME=ADMINC>
		<OPTION> --- Please Choose ---
		<OPTION VALUE=ADD> --- Add Contact ---
	</SELECT>
	Tech-c:<SELECT NAME=TECHC>
		<OPTION> --- Please Choose ---
		<OPTION VALUE=ADD> --- Add Contact ---
	</SELECT>
       </TD>

      </TR>
EOF
}

print <<EOF;
      <tr>
       <td>
        Action:
       </td>
       <td>
	<INPUT TYPE=HIDDEN NAME=ZONEPARENT VALUE = 1>
        <SELECT NAME=ACTION>
         <OPTION> --- Please Choose ---
         <OPTION VALUE=REQ>Request Assignment
         <OPTION VALUE=SEARCH>Search for block in database.
         <OPTION VALUE=LISTFREE>List free blocks.
EOF

if($config::config{'allowDNS'}){
print <<EOF;
         <OPTION VALUE=SETDNS>Set DNS Mapping for address.
         <OPTION VALUE=ZONEED>List DNS Zones.
EOF
}
if($config::config{'allowRwhois'}){
print <<EOF;
         <OPTION VALUE=SETRWHOIS>Set Rwhois record.
EOF
}

if($config::config{'allowDump'}){
	print <<EOF;
	<OPTION VALUE=DATADUMP>Block Dump.
EOF
}
	print "<OPTION VALUE=SEARCHLOG>Search Log.\n";

print <<EOF;
        </SELECT>
       </td>
     </tr>
     <TR>
       <TD COLSPAN=2>
        <CENTER><INPUT TYPE=SUBMIT VALUE="Submit Request"><INPUT TYPE=RESET>
        </CENTER></FORM>
      </TD>
    </TR>
  </table>
EOF
&printTail;
$conn->disconnect;
