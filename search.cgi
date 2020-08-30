#!/usr/local/bin/perl -w
#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#	search.cgi-$Name:  $-$Revision: 1.10 $ $Date: 2002/09/05 00:16:50 $ <$Author: bapril $@freeipdb.org>
######################################################################

require 'ipdb_httpcgi.pl';
use config;
%config = config::config();
$config{'_REMOTE_USER'} = $ENV{'REMOTE_USER'};
$config{'_REMOTE_ADDR'} = $ENV{'REMOTE_ADDR'};
printHead("$config{ver}");
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
if($ENV{'CONTENT_LENGTH'}){
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
}
unless($FORM{'ACTION'}){$FORM{'ACTION'} = "NULL"};

print <<EOF;
<center><table BORDER COLS=2>
<tr>
<td BGCOLOR="$config{headcolor}" COLSPAN=2>
<center>
<h1>
<b><font face="Arial,Helvetica" color="$config{headtextcolor}" size=+2>$config{ver}</font>
</font></font></b></h1></center>
</td>
</tr>
</TABLE>
EOF

if($FORM{'ACTION'} =~ /RECURSE/){
        my $id1 = $FORM{'CHILDL'};
        my $id2 = $FORM{'CHILDR'};
        &AllocatedSearch_Head();
        &AllocatedSearch($conn,$script,1,$id1);
        &AllocatedSearch($conn,$script,1,$id2);
        print "</TABLE></FORM>";
        $conn->disconnect;
        exit();
}



if($FORM{'ACTION'} =~ /SUBMIT2/){
        my $block = "";
        if($FORM{'BLOCK'}){
                $block = &IP2Deci($FORM{'BLOCK'});
        }
        my $region = $FORM{'REGION'};
        my $bits = $FORM{'BITS'};
        my $cust = $FORM{'CUSTOMER'};
        my $custdesc = $FORM{'CUSTDESC'};
        &AllocatedSearch_Head();
        &AllocatedSearch($conn,$script,0,0,$block,$bits,$region,$cust,$custdesc,$FORM{'HOSTNAME'});
        print "</TABLE></FORM>";
        printTail();
	$conn->disconnect;
        exit();
}
if($FORM{'ACTION'} =~ /SUBMIT3/){
        print "<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>";
        print "<TR><TH>REGION</TH><TH>Block</TH><TH>Reclaim</TH><TH>ID</TH></TR>\n";
        &FreeList($conn);
        print "</TABLE></FORM>";
        printTail();
	$conn->disconnect;
        exit();
                
}

print <<EOF;
<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>
<TR>
</FORM><FORM ACTION=$script METHOD=POST>
<INPUT TYPE=HIDDEN NAME=ACTION VALUE=SUBMIT2>
<td bgcolor=#000000><font color=#FFFFFF>Search:</font></td>
<td bgcolor=#000000><font color=#FFFFFF>List EVERY available block in ALL regions</font></td>
</tr>
<tr>
<td>Block:<input TYPE=TEXT NAME=BLOCK SIZE=18> Region:<SELECT NAME=REGION>
<option> --- Please Choose --
EOF
ListRegions($conn);
print "</select>\n";
print "Bits: <INPUT NAME=BITS SIZE=4><BR>\n";
if($config{custname}){
	print "$config{custname_f}: <INPUT NAME=CUSTDESC><BR> \n";
}
if($config{custnum}){
	print "$config{custnum_f}:<INPUT NAME=CUSTOMER><BR>\n";
}
if($config{allowDNS}){
	print "Hostname:<INPUT NAME=HOSTNAME><BR>\n";
}
print <<EOF;
<input TYPE=SUBMIT VALUE=Search></td></FORM>
<FORM ACTION=$script METHOD=POST>
<INPUT TYPE=HIDDEN NAME=ACTION VALUE=SUBMIT3>
<td><input TYPE=SUBMIT VALUE="List" NAME=function></td>
</FORM>
</tr>
<tr>

</TABLE>
EOF
&printTail();
$conn->disconnect;
