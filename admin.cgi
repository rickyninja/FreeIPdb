#!/usr/local/bin/perl -w
#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#	admin.cgi-$Name:  $-$Revision: 1.16 $ $Date: 2002/04/16 21:39:00 $ <$Author: bapril $@freeipdb.org>
######################################################################

require 'ipdb_httpcgi.pl';
use config;
%config = config::config();
$config{'_REMOTE_USER'} = $ENV{'REMOTE_USER'};
$config{'_REMOTE_ADDR'} = $ENV{'REMOTE_ADDR'};

printHead("$config{ver}");

print <<EOF;
<center><table BORDER COLS=2>
<tr>
<td BGCOLOR="$config{headcolor}" COLSPAN=2>
<center>
<h1>
<b><font face="Arial,Helvetica" color="$config{headtextcolor}" SIZE=+2>
$config{ver}</font>
</font></b></h1></center>
</td>
</tr>
EOF

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
} else {
	$FORM{'FORM'} = "NULL";
}


if($FORM{'FORM'} =~ /IMPORT/){
	print "Importing IP Blocks<BR>\n";
	my @lines = split('\n',$FORM{'DATA'});
	my $i = 0;
	while($lines[$i]){
		my @line = split(':',$lines[$i]);	
		my $ver = &VersionFromRegion($conn,$FORM{'REGION'});
		my $added = &SetBlockP($conn,$line[0],$FORM{'REGION'},$line[1],$line[2],$line[3],$ver);
		if($added){
			print "Line successfully added Block: $added\n<BR>\n";
		} else {
			print "Line Failed: $lines[$i]<BR>\n";
		}
		$i++;
	}
}

if($FORM{'FORM'} =~ /DELREGION/){
	if($FORM{'REGION'} =~ /---/){
		print "<TR><TD><H1>Please go back and choose a REGION</TD></TR>\n";
		$exit = 1;
	}
	if($exit){ 
		print "</TABLE>\n";
		&printTail();
		$conn->disconnect;
		exit();
	} # Bail Missing some info.
	&DeleteRegion($conn,$FORM{'REGION'});
}

if($FORM{'FORM'} =~ /RECLAIM/){
	#procede to reclaim
	&ReclaimBlock($conn,$FORM{'RECLAIM'});
	print "Reclaim Block $FORM{'RECLAIM'}\n <BR>";
}
if($FORM{'FORM'} =~ /EDIT/){
	&EditForm($conn,$FORM{'EDIT'},$script);
	printTail();
	$conn->disconnect;
	exit();
}

if($FORM{'FORM'} =~ /UPDATE/){
	if($exit){
		printTail();
		$conn->disconnect;
		exit();
	}
	&UpdateBlock($conn,$FORM{'UPDATE'},$FORM{'REGION'},$FORM{'CUSTOMER'},$FORM{'CUSTDESC'});
	print "Updated\n";
}

if($FORM{'FORM'} =~ /SUBMIT4/){
print <<EOF;

<tr>
<td COLSPAN=2 bgcolor="$config{headcolor}" color="$config{headtextcolor}" SIZE=+2 face="Arial,Helvetica"><center><b>Confirm New IP Block 
Assignment</b></center></font></td>
</tr>
EOF
	my $exit = "";
	if($FORM{'REGION'} =~ /---/){
		print "<TR><TD><H1>Please go back and choose a REGION</TD></TR>\n";
		$exit = 1;
	}
	if($FORM{'BITS'} =~ /---/){
		print "<TR><TD><H1>Please go back and choose a Block Size</TD></TR>\n";
		$exit = 1;
	}
	if($exit){ 
		print "</TABLE>";
		&printTail();
		$conn->disconnect;
		exit();
	} # Bail Missing some info.
	print "<TR><TD COLSPAN=2>";
	$ver = &VersionFromRegion($conn,$FORM{'REGION'});
	my $id = &SetBlockP($conn,$FORM{'BLOCK'},$FORM{'REGION'},$FORM{'BITS'},$FORM{'CUSTDESC'},$FORM{'CUSTOMER'},$ver);
	@block = &GetBlockFromID($conn,$id);
	&SetRegion($conn,$id,$FORM{'REGION'},$block[2]);
	if($id){
		print "<H1>Success Your block id $id</H1>\n";
	} else {
		print "<H1>For some reason this request failed</H1>\n";
	}
	print "</TD></TR>";

}
if($FORM{'FORM'} =~ /SUBMIT5/){
	if($FORM{'REGION'} =~ /---/){
		print "<TR><TD><H1>Please go back and set a Region</TD></TR>\n";
		$exit = 1;	
	}
	unless($FORM{'BLOCK'} =~ /[\dA-Fa-f\:\.]+/){
		print "<TR><TD><H1>Please go back and set a Block</TD></TR>\n";
		my $BLK = IP2Deci($FORM{'BLOCK'});
		print "$FORM{'BLOCK'}   $BLK\n";
		$exit = 1;	
	}
	unless($FORM{'BITS'}){
		print "<TR><TD><H1>Please go back and set Bits</TD></TR>\n";
		$exit = 1;	
	}
	if($exit){ 
		print "</TABLE>";
		&printTail();
		$conn->disconnect;
		exit();
	} # Bail Missing some info.
	#my $blk_bits = ip2deci($FORM{'BLOCK'});
	&AddBlock($conn,$FORM{'BLOCK'},$FORM{'BITS'},$FORM{'REGION'},$FORM{'PRIORITY'});
}

if($FORM{'FORM'} =~ /AddRegion/){
        if($FORM{'REGIONNAME'} =~ m/^[a-zA-Z0-9-_\.]{1,20}$/){
                if($FORM{'PARENT'} !~ /---/){
			if($FORM{'HOLDTIME'} =~ m/^[0-9]*$/){
				$FORM{'HOLDTIME'} = $FORM{'HOLDTIME'} * 86400;
			} else {
				$FORM{'HOLDTIME'} = "";
			}
                        &AddRegion($conn,$FORM{'REGIONNAME'},$FORM{'v6'},$FORM{'PARENT'},$FORM{'HOLDTIME'});
                } else {
                        print "<H1>Invalid parent selection.</H1>\n";
                }
        } else {
                print "<H1>Invalid Region Name [ ^[a-zA-Z0-9 \.]{1,20}$ ]</H1>\n";
        }
}

if($FORM{'FORM'} =~ /SUBMIT9/){
	$bblock = &ip2deci($FORM{'BLOCK'});
	$id = &GetBlockId($conn,$bblock,$FORM{'BITS'},$FORM{'REGION_START'});
	unless($id){
		print "The block does not exist in the starting region";
		$conn->disconnect;
		exit();
	}
	$ver = &Version($conn,$id);
	#my $added = &SetBlockP($conn,$FORM{'BLOCK'},$FORM{'REGION_END'},$FORM{'BITS'},1,1,$ver);
	#if($added){
	#	print "A parent of that block exists.<BR>\n";
	#	&reclaim($conn,$added);
	#} else {
	#	$newblock = &CheckBlockFree($conn,$bblock,$FORM{'BITS'},$FORM{'REGION_START'});
	#	if($newblock == -1){
	#		print "The block's parent must exist.\n";
	#		$conn->disconnect;
	#		exit();
	#	}
	#	if($newblock == 0){
	#		$ver = &VersionFromRegion($conn,$FORM{'REGION_START'});
	#		$newblock = &MakeParent($conn,$bblock,$FORM{'BITS'},$FORM{'REGION_START'},$bblock,$ver);
	#		unless($newblock){print "Could not find parent block"; }
	#	}
		if(&SetRegion($conn,$id,$FORM{'REGION_END'},$FORM{'REGION_START'})){
			print "Success  $newblock!\n";
		} else {
			print "There was an error\n";
		}
	#}
}

if($FORM{'FORM'} =~ /SUBMITA/){
        $bblock = &ip2deci($FORM{'BLOCK'});
        $id = &CheckBlockFree($conn,$bblock,$FORM{'BITS'},$FORM{'REGION'});
	if($id == -1){
		print "Block's parent must exist\n";
		return(0);
	} elsif ($id == 0){
		print "Block's must exist\n";
		return(0);
	}
	&SetReclaim($conn,$id,1);
}

print <<EOF;
<tr>
<td bgcolor=#000000><font color=#FFFFFF>Add a specified Block:</font></td>
<td bgcolor=#000000><font color=#FFFFFF>Add Allocations.</font></td>
</tr>
<TR><FORM ACTION=$script METHOD=POST>
<INPUT TYPE=HIDDEN NAME=FORM VALUE=SUBMIT4>
<TD>
<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>
<TR><TH>Block:</TH><TD><input TYPE=TEXT NAME="BLOCK" SIZE=18></TD></TR>
<TR><TD COLSPAN=2>(e.g. 10.0.0.0 or 0000:0000:0000:0000:0000:0000:0000:0000)</TD></TR>
<TR><TH>Region:</TH><TD><SELECT NAME="REGION">
<option selected>--- Please Choose ---
EOF
ListRegions($conn);
print " </SELECT></TD></TR>";
print <<EOF;
<TR><TH>Bits:</TH><TD><INPUT NAME=BITS SIZE=4></TD></TR>
<TR><TD COLSPAN=2>(e.g. 0-32 or 0-128)</TD></TR>
EOF
if($config{custname}){
print "<TR><TH>$config{custname_f}:</TH><TD><INPUT NAME=CUSTDESC></TD></TR>";
} 
if($config{custnum}){
print "<TR><TH>$config{custnum_f}:</TH><TD><INPUT NAME=CUSTOMER></TD></TR>";
}
print <<EOF;
<TR><TD COLSPAN=2><input TYPE=SUBMIT VALUE=Add Block></TD></TR></FORM>
<TR><TD COLSPAN=2><H2><FONT COLOR=RED>WARNING: This function will override 
the 10 day holding period</FONT></H2></TD></TR>
</TABLE>
</TD><TD>
<FORM ACTION=$script METHOD=POST>
<INPUT TYPE=HIDDEN NAME=FORM VALUE=SUBMIT5>
<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>
<TR><TH>Block:</TH><TD><INPUT NAME=BLOCK></TD></TR>
<TR><TD COLSPAN=2>(e.g. 10.0.0.0 or 0000:0000:0000:0000:0000:0000:0000:0000)</TD></TR>
<TR><TH>Bits:</TH><TD><INPUT NAME=BITS SIZE=4></TD></TR>
<TR><TD COLSPAN=2>(e.g. 0-32 or 0-128)</TD></TR>
<TR><TH>Region:</TH><TD><SELECT NAME=REGION><OPTION SELECTED>--- Please Choose ---
EOF
ListRegions($conn);
print <<EOF;
</SELECT></TD></TR>
<TR><TH>Priority:</TH><TD><INPUT NAME=PRIORITY></TD></TR>
<TR><TD COLSPAN=2>(e.g. lower number = more likely to be used)</TD></TR>
<TR><TD COLSPAN=2><INPUT TYPE=SUBMIT VALUE=Add Block></TD></TR>
</TABLE>
</TD></TR></FORM>
<tr>
<td bgcolor=#000000><font color=#FFFFFF></FONT></TD>
<td bgcolor=#000000><font color=#FFFFFF>Add a Region</FONT></TD>
</TR>
<TR><TD></TD>
<FORM ACTION=$script METHOD=POST>
<INPUT TYPE=HIDDEN NAME=FORM VALUE=AddRegion>
<TD>
<TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>
<TR><TH>Name:</TH><TD><INPUT NAME=REGIONNAME></TD></TR>
<TR><TH>IPv6:</TH><TD><INPUT TYPE=CHECKBOX NAME=v6></TD></TR>
<TR><TH>Holdtime (days): </TH><TD><INPUT NAME=HOLDTIME></TD></TR>
<TR><TH>Parent:</TH><TD><SELECT NAME=PARENT><OPTION> --- None or choose one ---
<OPTION VALUE=ROOT> --- This is a root region ---
EOF
&ListRegions($conn);
print <<EOF;
</SELECT></TD></TR>
<TR><TD COLSPAN=2><INPUT TYPE=SUBMIT VALUE="Add Region"></TD></TR>
</TABLE></TD></FORM>
</TR>
<tr>
 <td bgcolor=#000000>
  <font color=#FFFFFF>
  </FONT>
 </TD>
 <td bgcolor=#000000>
  <font color=#FFFFFF>
   Delete a Region
  </FONT>
 </TD>
</TR>

<TR>
 <TD>

 </TD>
 <TD>
  <TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>
   <FORM ACTION=$script METHOD=POST>
    <INPUT TYPE=HIDDEN NAME=FORM VALUE=DELREGION>
     <TR>
      <TH>
       Name:
      </TH>
      <TD>
       <SELECT NAME=REGION>
	<OPTION> --- Please Choose a Region ---
EOF
&ListDeleteRegions($conn);
print <<EOF;
       </SELECT>
      </TD>
     </TR>
     <TR>
      <TD COLSPAN=2>
       <INPUT TYPE=SUBMIT VALUE="Delete Region">
      </TD>
     </TR>
    </FORM>
   </TABLE>
  </TD>
 </TR>
<tr>
<td bgcolor=#000000><font color=#FFFFFF>Put a block in a region(Block must exist):</FONT></TD>
<td bgcolor=#000000><font color=#FFFFFF>Set the Reclaim flag on a block(and all children):</FONT></TD>
</TR>
<TR><FORM ACTION=$script METHOD=POST>
<INPUT TYPE=HIDDEN NAME=FORM VALUE=SUBMIT9>
<TD><TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>
<TR><TH>Block:</TH><TD><INPUT NAME=BLOCK></TD></TR>
<TR><TH>Bits:</TH><TD><INPUT NAME=BITS></TD></TR>
<TR><TH>Starting Region:</TH><TD><SELECT NAME=REGION_START>
<OPTION SELECTED>--- Please Choose ---
EOF
ListRegions($conn);
print <<EOF;
</SELECT></TD></TR>
<TR><TH>Ending Region:</TH><TD><SELECT NAME=REGION_END>
<OPTION SELECTED>--- Please Choose ---
EOF
ListRegions($conn);
print <<EOF;
</SELECT></TD></TR>
<TR><TD COLSPAN=2><INPUT TYPE=SUBMIT VALUE="Move Block"></TD></TR>
</TABLE></TD></FORM>
<FORM ACTION=$script METHOD=POST>
<INPUT TYPE=HIDDEN NAME=FORM VALUE=SUBMITA>
<TD><TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>
<TR><TH>Block:</TH><TD><INPUT NAME=BLOCK></TD></TR>
<TR><TH>Bits:</TH><TD><INPUT NAME=BITS></TD></TR>
<TR><TH>Region:(for confirmation)</TH><TD><SELECT NAME=REGION>
<OPTION SELECTED>--- Please Choose ---
EOF
ListRegions($conn);
print <<EOF;
</SELECT></TD></TR>
<TR><TD COLSPAN=2><INPUT TYPE=SUBMIT VALUE="Set Reclaim"></TD></TR>
<TR><TD COLSPAN=2><H1><FONT COLOR=RED>WARNING!!! WARNING!!! DANGER Will Robinson!</FONT></H1>
<H2>This will prevent any blocks that are children of this one from being allocated.</H2></TD></TR>
</TABLE>
</TD></FORM>
</TR>
<tr>
<td bgcolor=#000000 COLSPAN=2><font color=#FFFFFF>Import Blocks:</FONT></TD>
</TR>
<TR><FORM ACTION=$script METHOD=POST>
<INPUT TYPE=HIDDEN NAME=FORM VALUE=IMPORT>
<TD COLSPAN=2><TABLE BORDER=0 BGCOLOR=BLACK CELLPADDING=1 CELLSPACING=1>
<TR><TH>Region:</TH><TD><SELECT NAME=REGION>
<OPTION SELECTED>--- Please Choose ---
EOF
ListRegions($conn);
print <<EOF;
</SELECT></TD></TR>
<TR><TH>Blocks:</TH><TD>
<TEXTAREA COLS=100 ROWS=20 NAME=DATA></TEXTAREA></TD></TR>
<TR><TD COLSPAN=2>Format:<br>
<I>ip address:netmask
EOF
if($config{custname}){
	print ":$config{custname_f}";
}
if($config{custnum}){
	print ":$config{custnum_f}";
}

print <<EOF;
</I></TD></TR>
<TR><TD COLSPAN=2>Parent is required to exist and be availiable.
<INPUT TYPE=SUBMIT VALUE="Import Blocks"></TD></TR>
</TABLE></TD></FORM>
</TR>
</table>
EOF

&printTail;
$conn->disconnect;
