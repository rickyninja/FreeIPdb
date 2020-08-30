#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#  ipdb_lib.pl-$Revision: 1.35 $ $Date: 2002/09/05 16:28:05 $ <$Author: bapril $@freeipdb.org>
######################################################################

use strict;
use warnings;
use Math::BigInt;
use Net::IP;
use POSIX 'strftime';

#-------------------------------------------------------------------------------------
#  Log_Event()
# Takes:
#  Database Connection (from pg)
#  The username (or null if non-authed)
#  The EventCode
#  The Region_ID
#  The IP Address. (numeric)
#  The Bits Field.
#  A text field
#  A Numeric Field.

sub Log_Event {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $code = shift or IPDBError(-1,'missing arg');
  my $username = $main::config{'_REMOTE_USER'} if $main::config{'_REMOTE_USER'};
  my $address = $main::config{'_REMOTE_ADDR'} if $main::config{'_REMOTE_ADDR'};
  my $region = shift;
  my $block = shift;
  my $IP = shift;
  my $bits = shift;
  my $text = shift;
  my $number = shift;
  my $sql = 'INSERT INTO LOG_TABLE (TIME'
    .($username ? ',REMOTE_USER' : '')
    .($address ? ',REMOTE_ADDR' : '')
    .(',CODE')
    .($region ? ',REGION' : '')
    .($IP ? ',IP' : '')
    .($bits ? ',BITS' : '')
    .($text ? ',TEXT' : '')
    .($number ? ',NUMBER' : '')
    .($block ? ',BLOCK' : '')
    .(') VALUES(?')
    .($username ? ',?' : '')
    .($address ? ',?' : '')
    .(',?')
    .($region ? ',?' : '')
    .($IP ? ',?' : '')
    .($bits ? ',?' : '')
    .($text ? ',?' : '')
    .($number ? ',?' : '')
    .($block ? ',?' : '')
    .(')');
  my $sth = $dbh->prepare( $sql ) or IPDBError(-1,$DBI::errstr);
  $sth->execute(
    time,
    ($username ? $username : ()),
    ($address ? $address : ()),
    ($code),
    ($region ? $region : ()),
    ($IP ? $IP : ()),
    ($bits ? $bits : ()),
    ($text ? $text : ()),
    ($number ? $number : ()),
    ($block ? $block : ()))
    or IPDBError(-1,$DBI::errstr);
}


#--------------------------------------------------------------------------------------
#   AddRA()
# Takes:
#   Database Connection (from pg)
#  The name of the new RA
# Returns:
#  RA ID on sucess
#  Throws IPDBError on error
#
sub AddRA
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $ra = shift or IPDBError(-1,'missing arg');
  my $sth;
  #
  # is there one by that name?
  #
  unless( LookupRA($dbh,$ra) )
  {
    $sth = $dbh->prepare('INSERT INTO RATABLE (NAME) VALUES (?)')
      or IPDBError(-1,$DBI::errstr);
    $sth->execute( $ra )
      or IPDBError(-1,$DBI::errstr);
    #
    # did we add it?
    #
    my $newid;
    if(!($newid = LookupRA($dbh,$ra)))
    {
      IPDBError(-1,"There has been a error adding this RA");
    }
    else
    {
      print "RA $ra Added\n";
      Log_Event($dbh,1,0,0,0,0,$ra,$newid);
      return(&LookupRA($dbh,$ra));
    }
  }
  else
  {
    IPDBError(-1,"RA allready exists.");
  }
}
#--------------------------------------------------------------------------------------

sub DeleteRA
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $ra = shift or IPDBError(-1,'missing arg');
  if( RAInUse($dbh,$ra) )
  {
    IPDBError(-1,"Could not Delete RA: In use");
  }
  else
  {
    my $sth = $dbh->prepare('DELETE FROM RATABLE WHERE ID=?');
    $sth->execute($ra);
    if($sth->err) {
      IPDBError(-1,$DBI::errstr);
    }
    Log_Event($dbh,2,0,0,0,0,0,$ra);
    return(0);
  }
}

#--------------------------------------------------------------------------------------
#  AddRegion()
# Takes:
#  Database Connection (from pg)
#  ID of the RA to use
#  Name of the new Region
#  IPv6 (If value block is IPV6)
# Returns:
#  -1 on error
#  Region ID on sucess
#
sub AddRegion
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $region = shift or IPDBError(-1,'missing arg');
  my $v6 = shift;
  my $parent = shift;
  my $holdtime = shift;
  my $sth;
  my $out;
  if($region !~ m/^[A-Za-z0-9-_]*$/ ) { IPDBError(-1,"No region defined, or invalid chars [$region]"); }
  if($region !~ m/^[A-Za-z0-9]/) { IPDBError(-1,"Region name must start with a letter or number.");}
  if( LookupRegion($dbh,$region) )
  {
    IPDBError(-1,"The region exists in the database");
  }
  else
  {
    my $qa = "INSERT INTO REGIONTABLE (NAME,PARENT";
    my $qb = ") VALUES ('$region',$parent";
    my $qc = ")";
    if($v6) {
      $qa .= ",V6";
      $qb .= ",'t'";
    }
    if($holdtime) {
      $qa .= ",HOLDTIME";
      $qb .= ",".$holdtime;
    }
    my $query = $qa.$qb.$qc;
    my @result = QueryDB($dbh,$query,"Adding Region");
    FinishDB(@result);
    if($out = LookupRegion($dbh,$region))
    {
      if($v6) { $v6 = 1;}
      #Log_Event($dbh,$config,3,$out,0,0,$v6,$region,0);
      print "REGION $region Added\n";
      return($out);
    }
    else
    {
      IPDBError(-1,"Region not added");
    }
  }
}
#--------------------------------------------------------------------------------------

sub QueryDB
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $query = shift or IPDBError(-1,'missing arg');
  my $text = shift;
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute;
  if($sth->err)
  {
    my $err = $DBI::errstr;
    print "ERR: $err\n";
    IPDBError(-1,"Database Query Error $text $err [$query]");
  }
  $num =~ s/E.*//g;
  return(($sth,$num));
}

#--------------------------------------------------------------------------------------
#       FinishDB()
# Takes:
#       A result from QueryDB
sub FinishDB
{
  etrace(@_);
  my @in = shift;
  if(defined($in[0])) {$in[0]->finish};
  undef $in[0];
}


sub DeleteRegion
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $region = shift or IPDBError(-1,'missing arg');
  my $sth;
  if( RegionInUse($dbh,$region) )
  {
    IPDBError(-1,"Could not Delete Region: In use");
  }
  else
  {
    $sth = $dbh->prepare('DELETE FROM REGIONTABLE WHERE ID = ?')
      or IPDBError(-1,$DBI::errstr);
    $sth->execute( $region )
      or IPDBError(-1,$DBI::errstr);
    Log_Event($dbh,4,$region,0,0,0,0,0);
    return(0);
  }
}

#--------------------------------------------------------------------------------------
#  LookupRegion()
# Takes:
#  Database Connection (from pg)
#  ID or name of region to find
# Returns:
#  -1 on error
#  0 on no record
#  ID or name of region on sucess (opposate of the input)  
#
sub LookupRegion
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $region = shift or IPDBError(-1,'missing arg');
  my $query =
    $region =~ /^\d+$/
    ? 'SELECT NAME FROM REGIONTABLE WHERE ID=?'
    : 'SELECT ID FROM REGIONTABLE WHERE NAME=?';
  my $sth = $dbh->prepare( $query )
    or IPDBError(-1,$DBI::errstr);
  my $num = $sth->execute( $region )
    or IPDBError(-1,$DBI::errstr);
  $num =~ s/E.*//g;
  if($num)
  {
    my @out = $sth->fetchrow;
    $sth->finish;
    undef $sth;
    return($out[0]);
  }
  else
  {
    $sth->finish;
    undef $sth;
    return(0);
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  LookupRA()
# Takes:
#       Database Connection (from pg)
#       ID or name of RA to find
# Returns:
#       -1 on error
#       0 on no RA
#       ID or name of RA on sucess (opposate of the input)
#
#
sub LookupRA
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $ra = shift or IPDBError(-1,'missing arg');
  my $query =
    $ra =~ /^\d+$/
    ? 'SELECT NAME FROM RATABLE WHERE ID=?'
    : 'SELECT ID FROM RATABLE WHERE NAME=?';
  my $sth = $dbh->prepare( $query )
    or IPDBError(-1,$DBI::errstr);
  my $num = $sth->execute( $ra )
    or IPDBError(-1,$DBI::errstr);
  $num =~ s/E.*//g;
  if($num)
  {
    my @out = $sth->fetchrow;
    return($out[0]);
  }
  else
  {
    return(0);
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  GetRAFromRegion()
# Takes:
#  DB connection
#  Region name or ID
# Returns:
#  -1 on error
#  RA ID
#
sub GetRAFromRegion
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $region = shift or IPDBError(-1,'missing arg');
  if($region !~ /^\d+$/)
  {
    $region = LookupRegion($dbh,$region);
  }
  my $sth = $dbh->prepare( 'SELECT RA FROM REGIONTABLE WHERE ID=?' )
    or IPDBError(-1,$DBI::errstr);
  my $num = $sth->execute( $region )
    or IPDBError(-1,$DBI::errstr);
  $num =~ s/E.*//g;
  $num || IPDBError(-1,"No result from database");
  my @out = $sth->fetchrow;
  return($out[0]);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  reclaim()
# Takes:
#  Database Connection (from pg)
#  ID of block to reclaim
# Returns:
#  -1 on error
#  0 on no block to reclaom
#  1 on sucess (no recursion nessary)
#  2 on sucess (recursion needed.)
#
sub reclaim
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $childl;
  my $childr;
  my $region;
  my $parent;
  my $sibling;
  my $parentregion;
  my $sth = $dbh->prepare( 'SELECT PARENT,CHILDL,CHILDR,REGION FROM IPDB WHERE ID=?' );
  my $num = $sth->execute( $id );
  if($sth->err)
  {
    IPDBError(-1,$DBI::errstr);
  }
  $num =~ s/E.*//g;
  if($num)
  {
    my @out = $sth->fetchrow;
    ( $parent, $childl, $childr, $region ) = @out;
    my $num = $sth->execute( $parent );
    if($num)
    {
      my @out = $sth->fetchrow;
      $parentregion = $out[3];
    }
  } 
  else
  {
    IPDBError(-1,"Can't find block in database");
  }
  if(($parent != 0 && !$childl && !$childr) && ($region == $parentregion))
  {
    clearblock($dbh,$id)
      or IPDBError(-1,"Could not clearblock");
    Log_Event($dbh,11,0,$id,0,0,0,0);
    $sibling = getsibling($dbh,$id)
      or IPDBError(-1,"Can't get sibling");
    if(&checksibling($dbh,$sibling) == 1 && !&CheckReclaim($dbh,$id))
    {
      demoblock($dbh,$id)
        or IPDBError(-1,"Could not demoblock");
      demoblock($dbh,$sibling)
        or IPDBError(-1,"Could not demoblock #2");
      clearblock($dbh,$parent)
        or IPDBError(-1,"Error clearing block #1");
      my $oktoreclaim = &CheckReclaim($dbh,$parent);
      if($oktoreclaim) {
        return(0);
      } else {
        &reclaim($dbh,$parent);
      }
      return(0);
    }
  } else {
    if($region != $parentregion) {
      &clearblock($dbh,$id)|| &IPDBError(-1,"Error clearing block #2");
      &Log_Event($dbh,11,0,$id,0,0,0,0);
      print "Did not traverse region boundry\n";
      return(0);
    }
    unless(!$childl || !$childr) {
      &clearblock($dbh,$id)|| &IPDBError(-1,"Error clearing block #3");
      &Log_Event($dbh,11,0,$id,0,0,0,0);
      return(0);
    } else {
      &IPDBError(-1,"Could not clearblock it has children");
    }
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  CheckReclaim()
# Takes:
#  Dabatase connection
#  A block ID
# Returns:
#  -1 on error
#  0 on OK to reclaim
#  1 on DO NOT RECLAIM
sub CheckReclaim {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $blockid = shift or IPDBError(-1,'missing arg');
  my $sth = $dbh->prepare('SELECT RECLAIM FROM IPDB WHERE ID=?');
  my $num = $sth->execute( $blockid );
  if($sth->err) { 
    IPDBError(-1,$DBI::errstr);
  }
  $num =~ s/E.*//g;
  if($num) {
    my @out = $sth->fetchrow;
    my $reclaim = $out[0];
    $sth->finish;
    undef $sth;
    return($reclaim);
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  ReadBlock()
# Takes:
#  Database Connection (from pg) to ipdb
#  A DB conn
#  ID of block to read
# Returns:
#  -1 on an error
#  0 on no block in the database
#  Block information string.
#
sub ReadBlock {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $block = shift or IPDBError(-1,'missing arg');
  my $query = 'SELECT i.BLOCK,i.BITS,r.name,i.ALLOCATED,i.CUSTNUM,i.CUSTDESC FROM IPDB i,REGIONTABLE r WHERE i.ID=?  AND i.REGION=r.ID';
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute( $block );
  if($sth->err) { 
    IPDBError(-1,$DBI::errstr);
  }
  $num =~ s/E.*//g;
  if($num) {
    my @out = $sth->fetchrow;
    my $dblock = $out[0];
    my $bits = $out[1];
    my $region = $out[2];
    my $allocated = $out[3];
    my $customer = $out[4];
    my $custdesc = $out[5];
    my $city;
    my $ipblock = &deci2ip($dblock,&Version($dbh,$block)) || &IPDBError(-1,"Invalid Deci2IP");
    my $v = &Version($dbh,$block)|| &IPDBError(-1,"determine version");
    my $sthing = "$ipblock/$bits from $region To: $customer IPv$v\n";
    $sth->finish;
    undef $sth;
    return($sthing);
  } else {
    &IPDBError(0,"Could not ReadBlock");
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  checksibling()
# Takes:
#  Database Connection (from pg) to ipdb
#  Sibling ID (Does the block with ths ID have any siblings)
# Returns:
#  1 for No children
#  0 for Children
#
sub checksibling {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $sth = $dbh->prepare('SELECT ID FROM IPDB WHERE CHILDL IS NULL AND CHILDR IS NULL AND ALLOCATED IS NULL AND ID=?');
  my $num = $sth->execute( $id );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
        } 
  $sth->finish;
  undef $sth;
  my $oktoreclaim = &CheckReclaim($dbh,$id);
  if($oktoreclaim) {
    return(0);
  } else {
    $num =~ s/E.*//g;
    if($num) { return(1);} else {return(0);}
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  clearblock()
# Takes:
#  Database Connection (from pg) to ipdb
#  Block ID (The block to clear)
# Returns:
#  -1 for error
#  1 for sucess
#
sub clearblock {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  #
  # Get the holdtime for this region or use the default.
  #
  my $sth = $dbh->prepare('SELECT a.HOLDTIME FROM REGIONTABLE a, IPDB b WHERE b.REGION=a.ID AND b.ID=?');
  my $num2 = $sth->execute( $id );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my $hold = $main::config{holdtime};
  if($num2) {
    my @out = $sth->fetchrow;
    if($out[0]) {
      $hold = $out[0];
    } 
  }
  $hold += time;
  #
  # Clear IPDB
  #
  my $sql = 'UPDATE IPDB SET CHILDL=NULL,CHILDR=NULL,CUSTDESC=NULL,ALLOCATED=NULL,CUSTNUM=NULL,HOLDTIME=? WHERE ID=?';
  $sth = $dbh->prepare( $sql );
  $sth->execute( $hold, $id );
  if( $sth->err ) {
    IPDBError(-1,$DBI::errstr);
  }
  #
  # Clear DNS
  #
  $sth = $dbh->prepare('DELETE FROM ZONE_RECORD_TABLE WHERE BLOCK=?');
  $sth->execute( $id );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $sth = $dbh->prepare('DELETE FROM ZONE_TABLE WHERE REVERSE_BLOCK=?');
  $sth->execute( $id );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  #
  # Clear RWHOIS
  #
  $sth = $dbh->prepare('SELECT ID FROM JUSTIFICATIONTABLE WHERE BLOCK=?');
  my $num = $sth->execute( $id );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  if($num) {
    my @out = $sth->fetchrow;
    if($out[0]) {
      $sth = $dbh->prepare('DELETE FROM USETABLE WHERE JUST=?');
      $sth->execute( $out[0] );
      if($sth->err) {
        IPDBError(-1,$DBI::errstr);
      }
      $sth = $dbh->prepare('DELETE FROM JUSTIFICATIONTABLE WHERE ID=?');
      $sth->execute( $out[0] );
      if($sth->err) {
        IPDBError(-1,$DBI::errstr);
      }
    }
  }
  return(1);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  demoblock()
# Takes:
#  Database Connection (from pg) to ipdb
#  Block ID to demo.
# Returns:
#  -1 on error
#  1 on sucess
#
sub demoblock {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $sth = $dbh->prepare('DELETE FROM IPDB WHERE ID=?');
  $sth->execute( $id );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  return 1;
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  getsibling()
# Takes:
#  Database Connection (from pg) to ipdb
#  Block ID to return sibling infor for.
# Returns:
#  -1 on error
#  ID of sibling on sucess.
#
sub getsibling {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $parent;
  my $childr;
  my $childl;
  my $sth = $dbh->prepare('SELECT PARENT FROM IPDB WHERE ID=?')
    or IPDBError(-1,$DBI::errstr);
  my $num = $sth->execute( $id )
    or IPDBError(-1,$DBI::errstr);
  $num =~ s/E.*//g;
  if($num) {
    my @out = $sth->fetchrow;
    $parent = $out[0];
  } else {
    IPDBError(-1,"Child ID $id has no parent.");
  }
  my $sth2 = $dbh->prepare('SELECT CHILDL,CHILDR FROM IPDB WHERE ID=?')
    or IPDBError(-1,$DBI::errstr);
  my $num2 = $sth2->execute( $parent )
    or IPDBError(-1,$DBI::errstr);
  $num2 =~ s/E.*//g;
  if($num2) {
    my @out2 = $sth2->fetchrow;
    $childl = $out2[0];
    $childr = $out2[1];
  } else {
    IPDBError(-1,"No child information for ID $id.");
  }
  $sth2->finish;
  undef $sth2;
  if($childl == $id) {
    return($childr);
  }
  elsif($childr == $id) {
    return($childl);
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  NewBlock()
# Takes:
#  Database Connection (from pg) to ipdb  
#  A region ID
#  The size of the new block (in bits)
#  A req #
#  A customer code.
# Returns:
#  -1 on error
#  0 on No Free Space
#  ID on sucess.
#
sub NewBlock
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $region = shift or IPDBError(-1,'missing arg');
  my $bits = shift or IPDBError(-1,'missing arg');
  my $custdesc = shift;
  my $CUST = shift ;
  my $id = '';
  my $newblock = '';
  my $now = time();
  my @out;
  #
  #lock the region
  #
  my $lock_id = GetLock($dbh,$region);
  #
  # Any blocks the exact Size?
  #
  my $sql = q
  (
    SELECT
      ID,
      BITS,
      BLOCK
    FROM
      IPDB
    WHERE
      CHILDL IS NULL
      AND
      CHILDR IS NULL
      AND
      ALLOCATED IS NULL
      AND
      REGION = ?
      AND
      BITS <= ?
      AND
      RECLAIM IS NULL
      AND
      (
        HOLDTIME < ?
        OR
        HOLDTIME IS NULL
      )
      ORDER BY
        priority ASC,
        BITS DESC
  );
  my $sth = $dbh->prepare( $sql )
    or IPDBError(-1,$DBI::errstr);
  my $num = $sth->execute( $region, $bits, $now )
    or IPDBError(-1,$DBI::errstr);
  while(@out = $sth->fetchrow)
  {
    my $size = $out[1];
    $id = $out[0];
    if($size == $bits)
    {
      #
      # We have exact blocks
      #
      setblock($dbh,$id,$custdesc,$CUST,$region) || IPDBError(-1,'Unable to setblock');
      Log_Event($dbh,10,$region,$id,$out[2],$bits,$custdesc,$CUST);
      UnLock($dbh,$lock_id);
      return($id);
    }
    else
    {
      #
      # There are larger blocks in region.
      #
      $newblock = makeblock($dbh,$id,$bits) || IPDBError(-1,'Unable to makeblock');
      setblock($dbh,$newblock,$custdesc,$CUST,$region) || IPDBError(-1,'Unable to setblock #2');
      my @blk = GetBlockFromID($dbh,$newblock);
      Log_Event($dbh,10,$region,$newblock,$blk[0],$bits,$custdesc,$CUST);
      UnLock($dbh,$lock_id);
      return($newblock);
    }
  }
  print "No Free Blocks in region\n";
  UnLock($dbh,$lock_id);
  return(0);
}
#--------------------------------------------------------------------------------------

sub GetLock {
  etrace(@_);
  my $dbh = shift;
  my $region = shift;
  my $trys = 10;
  my $lower=1000; 
  my $upper=2000000; 
  while($trys) {
    my $sth = $dbh->prepare("SELECT * FROM LOCK_TABLE WHERE REGION=$region");
    my $num = $sth->execute;
    $num =~ s/E.*//g;
    if(!$num) {
      my $random = int(rand( $upper-$lower+1 ) ) + $lower; 
      my $now = time();
      $sth = $dbh->prepare("INSERT INTO LOCK_TABLE (REGION,SET,TYPE) VALUES ($region,$now,$random)");
      $sth->execute;
      $sth = $dbh->prepare("SELECT ID,TYPE FROM LOCK_TABLE WHERE REGION=$region");
      $num = $sth->execute;
      $num =~ s/E.*//g;
      if($num == 1) {
        my @out = $sth->fetchrow;
        if($out[1] == $random) {
          return($out[0]);
        } else {
          print "found only one lock and it wasn't ours...\n";
        }
      } elsif ($num > 1) {
        print "We were beaten to the lock\n";
        $sth = $dbh->prepare("DELETE FROM LOCK_TABLE WHERE REGION = $region and TYPE = $random");
        $sth->execute;
      } elsif ($num == 0) {
        print "The lock I added isn't there...<BR>\n";

      }
    } else {
      print "Locks are set in this region<BR>\n";
    }
    $trys--;
    sleep(2);
  }
  print "<H1>Failed to get lock</H1>\n";
  exit();
}

  
sub UnLock {
  etrace(@_);
  my $dbh = shift;
  my $lock_id = shift;
        my $sth = $dbh->prepare("DELETE FROM LOCK_TABLE WHERE ID = $lock_id");
        my $num = $sth->execute;
        if($sth->err) {
    IPDBError(-1,$DBI::errstr);
        }
}
#--------------------------------------------------------------------------------------
#  ip2deci()
# Takes:
#  an IP-Address (IPv4 or IPv6)
# Returns:
#  A decimal number
#
sub ip2deci {
  etrace(@_);
  my $in = shift or IPDBError(-1,'missing arg');
  my $ip =  new Net::IP ($in) or &IPDBError(-1,"IP address no supplied");
  my $out = $ip->intip();
  return $out;
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#       setblock()
# Takes:
#       Database Connection (from pg) to ipdb
#       The block id of the block to set.
#       The Customer name to assign this allocation to.
#       Customer code/number
#       Optional Region
# Returns:
#       -1 on error or not in database.
#       1 on sucess
#
sub setblock {
  etrace(@_);
        my $dbh = shift or IPDBError(-1,'missing arg');
        my $block = shift or IPDBError(-1,'missing arg');
        my $custdesc= shift;
        my $CUST = shift;
        my $region = shift;
        my $time = time();
  #Shouldn't we get bits here too?
        my $sth = $dbh->prepare("SELECT ALLOCATED,CHILDL,CHILDR,RECLAIM FROM IPDB WHERE ID = $block");
  my $num = $sth->execute;
        if($sth->err) {
    IPDBError(-1,$DBI::errstr);
        }
        my $allocated;
        my $childl;
        my $childr;
        my $reclaim;
  $num =~ s/E.*//g;
        if($num) {
    my @out = $sth->fetchrow;
                $allocated = $out[0];
                $childl = $out[1];
                $childr = $out[2];
                $reclaim = $out[3];
    if ($allocated) {
      if($allocated =~ /\d+/) {
        &IPDBError(-1,"Block in use  or allocated set to $allocated");
      }
    }
    if ($childl || $childr) {
      if($childl =~ /\d+/ || $childr =~ /\d+/) {
        &IPDBError(-1,"Block $block has children");
      }
    }
        } else {
                &IPDBError(-1,"Block not in database");
        }
  if($reclaim) {
          if($reclaim =~ /[01]/) {
      &IPDBError(0,"Unable to set block In reclaim mode");
          }
  }
        $sth = $dbh->prepare("UPDATE IPDB SET ALLOCATED = $time WHERE ID = $block");
  $sth->execute();
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $sth = $dbh->prepare("UPDATE IPDB SET HOLDTIME = NULL WHERE ID = $block");
        if($sth->err) {
    IPDBError(-1,$DBI::errstr);
        }
  if($custdesc) {
          $sth = $dbh->prepare("UPDATE IPDB SET CUSTDESC = '$custdesc' WHERE ID = $block");
    $sth->execute;
          if($sth->err) {
      IPDBError(-1,$DBI::errstr);
          }
  }
        if($CUST) {
                $sth = $dbh->prepare("UPDATE IPDB SET CUSTNUM = $CUST WHERE ID = $block");
    $sth->execute;
                if($sth->err) {
      IPDBError(-1,$DBI::errstr);
                }
        }
        if($region) {
                $sth = $dbh->prepare("UPDATE IPDB SET REGION = $region WHERE ID = $block");
    $sth->execute;
                if($sth->err) {
      IPDBError(-1,$DBI::errstr);
                }
        }
  $sth->finish;
  undef $sth;
        return(1);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  NewAlloc()
# Takes:
#  Database Connection (from pg) to ipdb
#  The block id of the block to set.
#  Region ID.
# Returns:
#  -1 on error or not in database.
#  ID on sucess
#
sub NewAlloc {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $block = shift or IPDBError(-1,'missing arg');
  my $bits = shift or IPDBError(-1,'missing arg');
  my $region = shift or IPDBError(-1,'missing arg');
  my $priority = shift;
  my $binblock = &ip2deci($block);
        my $check = &CheckBlockFree($dbh,$binblock,$bits,$region);
        if($check) {
                print "Block is in use<BR>\n";
                return(0);
        } else {
    my $ver = &VersionFromRegion($dbh,$region);
                my $added = &SetBlockP($dbh,$block,$region,$bits,1,1,$ver);
                if($added) {
                        print "A parent of that block exists.<BR>\n";
                        &reclaim($dbh,$added);
                } else {
      unless($priority) {$priority = "NULL";}
      my $sth = $dbh->prepare("INSERT INTO IPDB (BLOCK,BITS,REGION,PARENT,PRIORITY) VALUES ($binblock,$bits,$region,0,$priority)");
      $sth->execute;
      if($sth->err) {
        IPDBError(-1,$DBI::errstr);
      }
      my $query = "SELECT ID FROM IPDB WHERE BLOCK = ".$binblock."::NUMERIC(40,0) AND BITS = $bits AND REGION = $region";
      $sth = $dbh->prepare($query);         
      my $num = $sth->execute;
      if($sth->err) {
        IPDBError(-1,$DBI::errstr);
      }
      $num =~ s/E.*//g;
      if($num) {
        my @out = $sth->fetchrow;
        my $blockID = $out[0];
        print "<BR>Block added to database.";
        $sth->finish;
        undef $sth;
        &Log_Event($dbh,5,$region,$blockID,$binblock,$bits,0,$priority);
        return($blockID);
      } else {
        &IPDBError(-1,"Could not confirm block in database.");
                        }
                }
  }
}
#--------------------------------------------------------------------------------------


#--------------------------------------------------------------------------------------
#  splitblock()
# Takes:
#  Database Connection (from pg) to ipdb
#  ID of block to split
#  The decimal value of the block to be returned.
# Returns:
#  -1 on an error
#  0 on parent block not in database
#  ID of (red defined) child block in database
#
sub splitblock() {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $ret = shift;
  my $sth = $dbh->prepare('SELECT BLOCK,BITS,REGION,RECLAIM,priority,ALLOCATED FROM IPDB WHERE ID = ?');
  my $num = $sth->execute($id);
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $num =~ s/E.*//g;
  unless($num) {
    &IPDBError(-1,"Parent block not in database ID = $id");
  }
  my @out = $sth->fetchrow;
  my $block = $out[0];
  my $bits = $out[1];
  my $region = $out[2];
  my $reclaim = $out[3];
  my $alloc_prio = $out[4] || "NULL";
  my $allocated = $out[5];
  if($allocated) {
    &IPDBError(-1,"Parent block is in use!");
  }
  if($reclaim =~ /[01]/) { &IPDBError(0,"Could not split block in-use");}
  $bits++;
  my $block1 = Math::BigInt->new($block);
  my $block2 = Math::BigInt->new($block);
  $block = Math::BigInt->new($block);
  my $temp = Math::BigInt->new("1");
  my $v;
  if(&Version($dbh,$id) == 4) {
    $temp = $temp->blsft((32 - $bits));
    $block2 = $block ^ $temp;
    $v = 4;
  } else {
    $temp = $temp->blsft((128 - $bits));
    $block2 = $block ^ $temp;
    $v = 6;
  }
  $block2 =~ s/\+//g; # Strip the leading "+"
  $block1 =~ s/\+//g;
  $sth = $dbh->prepare("INSERT INTO IPDB (BLOCK,BITS,REGION,PARENT,priority) VALUES ($block1,$bits,$region,$id,$alloc_prio)");
  $sth->execute();
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $sth = $dbh->prepare("INSERT INTO IPDB (BLOCK,BITS,REGION,PARENT,priority) VALUES ($block2,$bits,$region,$id,$alloc_prio)");
  $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my $query1 = "SELECT ID FROM IPDB WHERE BLOCK = ".$block1."::numeric(40,0) AND BITS = $bits AND REGION = $region";
  my $query2 = "SELECT ID FROM IPDB WHERE BLOCK = ".$block2."::numeric(40,0) AND BITS = $bits AND REGION = $region";
      my $sth1 = $dbh->prepare($query1);
  my $num1 = $sth1->execute;
  if($sth1->err) {
    IPDBError(-1,$DBI::errstr);
  }
      my $sth2 = $dbh->prepare($query2);
  my $num2 = $sth2->execute;
  if($sth2->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my $childr;
  my $childl;
  $num1 =~ s/E.*//g;
  if($num1) {
    my @out1 = $sth1->fetchrow;
          $childl = $out1[0];
  } else {
    &IPDBError(-1,"There was an error creating block1");
  }
  $num2 =~ s/E.*//g;
  if($num2) {
      my @out2 = $sth2->fetchrow;
          $childr = $out2[0];
  } else {
    &IPDBError(-1,"There was an error creating block2");
  }
  $sth = $dbh->prepare("UPDATE IPDB SET CHILDR = $childr WHERE ID = $id");
  $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $sth = $dbh->prepare("UPDATE IPDB SET CHILDL = $childl WHERE ID = $id");
  $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my $a;
  $a = &makemask($bits,$v) || &IPDBError(0,"Makemask failed");
  my $mask = Math::BigInt->new($a);
  $block1 =~ s/^/+/g; # Put the leading "+" back on.
  $block2 =~ s/^/+/g;
  my $bm1 = $block1 & $mask;
  my $bm2 = $block2 & $mask;
  my $b1 = Math::BigInt->new($bm1);
  my $b2 = Math::BigInt->new($bm2);
  my $t1 = $ret & $mask;
  my $test = Math::BigInt->new($t1);
  $sth->finish;
  undef $sth;
  $sth1->finish;
  undef $sth1;
  $sth2->finish;
  undef $sth2;
  if(!$ret) {
    if($test == "+0") {
      return($childl);
    } else {
      return($childr);
    }
  } else {
    if($block1 == $ret || $block1 ==  $t1) {
      return($childl);
    } elsif ($block2 == $ret || $block2 == $t1) {
      return($childr);
    } else {
      print "My output did not match the input\n";
    }
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  makemask()
# Takes:
#  Number of bits to mask
#  Version 4 || 6
# Returns:
#  -1 on error
#  a bitmask
#
sub makemask {
  etrace(@_);
  my $bits = shift or IPDBError(-1,'missing arg');
  my $version = shift or IPDBError(-1,'missing arg');
  my $i;
  my $out = Math::BigInt->new("0");
  if($version == 4) { 
    $i = 31;
  } elsif($version == 6) {
    $i = 127;
  } else {
    &IPDBError(-1,"Did not supply an IP version");
  }
  if($bits < 1) {
    &IPDBError(-1,"Did not supply mask size");
  }
  while($bits) {
    my $temp = Math::BigInt->new("1");
    $temp = $temp->blsft($i);
    $out = $out ^ $temp;
    $bits--;
    $i--;
  }
  return($out);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  makeblock()
# Takes:
#  Database connection (pg)
#  Block to base from
#  Size in netmask.
# Returns:
#  -1 on error
#  0 on base block does not exist.
#  ID of new block
#
sub makeblock {
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $bits = shift or IPDBError(-1,'missing arg');
  my $sth = $dbh->prepare('SELECT BITS,REGION,BLOCK FROM IPDB WHERE ID = ?');
  my $num = $sth->execute($id);
  if($sth->err)  {
    IPDBError(-1,$DBI::errstr);
  }
  $num =~ s/E.*//g;
  $num|| &IPDBError(-1,"Parent block does not exist.");
  my @out = $sth->fetchrow;
  my $size = $out[0];
  my $region = $out[1];
  my $block = $out[2];
  my $foo = "";
  $foo = &splitblock($dbh,$id,0) || &IPDBError(-1,"Splitblock failed");
  if(($size + 1) != $bits) { # the next block will fit
    my $out1 = &makeblock($dbh,$foo,$bits) || &IPDBError(-1,"Makeblock failed");
    return($out1);
  }
  return($foo);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  deci2ip()
# Takes:
#  A Integet (to conver to an IP address)
#  A version (4 || 6);
# Returns:
#  The IP address in dotted decimal or IPv6 Notation.
#
sub deci2ip {
  etrace(@_);
  my ($binip,$ver) = @_;
  my $bin;
  my $ip;
  if($binip =~ m/[\d]+/) {
    # Define normal size for address
    if($ver == 4) {
      $bin = ip_inttobin($binip,4);
      $ip = ip_bintoip($bin,4);
      return($ip);
    } elsif($ver == 6) {  
      $bin = ip_inttobin($binip,6);
      $ip = ip_bintoip($bin,6);
      return($ip);
    } else {
      &IPDBError(-1,"Did not supply an IP version number");
    }  
  } else {
    &IPDBError(-1,"Did not get an integer to convert");
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  IPDB-Error()
# Takes:
#  Return Code (-1,1,0,...)
#  Text string
# Retruns
#  exits if RET = -1
#  0 if RET = 0
sub IPDBError
{
  etrace(@_);
  my $code = shift;
  my $error = shift or IPDBError(-1,'missing arg');
  my @sub = caller(1);
  my @me = caller();
  print  "Error in $sub[1] in $sub[3] at line $me[2] $error</TABLE>\n";
  warn "Error in $sub[1] in $sub[3] at line $me[2] $error\n";
  if($code < 0) { die("Exiting $code");}
  return($code);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  SetBlockP()
# Takes:
#  Database Connection (Pg);
#  Block ID to set.
#  Region to put block in.
#  Size of block in bits.
#  CUSTDESC Number 
#  CUST number
# Returns:
#  -1 on error
#  0 on block does not exist or is in use.
#  1 on sucess.
#
sub SetBlockP
{
  etrace(@_);
        my $dbh = shift or IPDBError(-1,'missing arg');
        my $block = shift or IPDBError(-1,'missing arg');
        my $region = shift or IPDBError(-1,'missing arg');
        my $bits = shift or IPDBError(-1,'missing arg');
        my $custdesc= shift;
  my $CUST = shift;
  my $ver = shift or IPDBError(-1,'missing arg');
  my $bblock = &ip2deci($block);
  my $newblock = &CheckBlockFree($dbh,$bblock,$bits,$region);
  if($newblock == -1) {
    print "That block is in use\n";
    $dbh->disconnect;
    exit();
  }
  if($newblock == 0) {
    $newblock = &MakeParent($dbh,$bblock,$bits,$region,$bblock,$ver) || return(0);
  }
  &setblock($dbh,$newblock,$custdesc,$CUST,$region);
  return($newblock);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  CheckBlocksFree()
# Takes:
#  A database connection to IPDB
#   A block ID to check for.
#  A A bit-boundry
# Returns:
#  -1 on Error
#  0 on No block found
#  ID on found block.
#
sub CheckBlockFree
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $block = shift or IPDBError(-1,'missing arg');
  my $bits = shift or IPDBError(-1,'missing arg');
  my $region = shift or IPDBError(-1,'missing arg');
  my $query = "SELECT ID FROM ipdb WHERE BITS = ".$bits." AND BLOCK = ".$block."::numeric(40) AND REGION = $region ";
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute;
  $num =~ s/E.*//g;
  if($sth->err)
  {
    IPDBError(-1,$DBI::errstr);
  }
  unless($num)
  { 
    return(0);
  } else {
    my @out = $sth->fetchrow;
    my $id = $out[0];
    my $sth2 = $dbh->prepare('SELECT ALLOCATED,CHILDR,CHILDL FROM IPDB WHERE ID = ?');
    $sth2->execute($id);
    if($sth2->err)
    {
      IPDBError(-1,$DBI::errstr);
    }
    else
    {
      my @out1 = $sth2->fetchrow;
      my $allo = $out1[0];
      my $childl = $out1[1];
      my $childr = $out1[2];
      if($allo < 0 || $childl < 0 || $childr < 0)
      {
        print "ID $id ALLO $allo CHILDR $childr CHILDL $childl\n";
        return(-1);
      }
      else
      {
        return($id);
      }
    }
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  ParentBlock()
# Takes:
#  block in integer form.
#  Bits 
#  version 4 or 6
# Returns:
#  Integer value of the parent
#
sub ParentBlock
{
  etrace(@_);
  my $block = shift or IPDBError(-1,'missing arg');
  my $bits = shift or IPDBError(-1,'missing arg');
  my $v = shift or IPDBError(-1,'missing arg');
  my $BitFlip = Math::BigInt->new(1);
  my $other = Math::BigInt->new();
  my $out;
  $block = Math::BigInt->new($block);
  if($v == 6)
  {
    $BitFlip = $BitFlip->blsft(128 - $bits);
    $other = ($block ^ $BitFlip);
  }
  elsif($v == 4)
  {
    $BitFlip = $BitFlip->blsft(32 - $bits);
    $other = ($block ^ $BitFlip);
  }
  else
  {
    IPDBError(-1,"IP Version not valid [$v]");
  }
  if($bits == 0)
  {
    return(0);
  }
  if($block > $other)
  {
    $out = $other;
  }
  else
  {
    $out = $block;
  }
  $out =~ s/\+//g;
  return($out);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  MakeParent()
# Takes:
#  Database connection
#  Block (integer format)
#  netmask in bits
#  region ID
#  Goal (The block we are trying to make)
#  Version (4||6)
# Returns:
#  ID of output block
#
sub MakeParent
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $block = shift or IPDBError(-1,'missing arg');
  my $bits = shift or IPDBError(-1,'missing arg');
  my $region = shift;
  my $goal = shift or IPDBError(-1,'missing arg');
  my $ver = shift or IPDBError(-1,'missing arg');
  my $out;
  my $done;
  my $parent = &ParentBlock($block,$bits,$ver);
  if($parent == 0) {return(0);} # Got to end of free blocks.
  if($bits == 1) {&IPDBError(-1,"Block not on bit-boundry");}
  my $check = &CheckBlockFree($dbh,$parent,($bits - 1),$region) ;
  if($check == -1 ) {&IPDBError(-1,"Block come back in-use");}
  my $b1 = &deci2ip($block,$ver) || &IPDBError(-1,"Failed");
  my $b2 = &deci2ip($parent,$ver) || &IPDBError(-1,"Failed #2");
  if($check != 0)
  {
    $done = &splitblock($dbh,$check,$goal,$region) || &IPDBError(-1,"Splitblock failed");
  }
  else
  {
    $out = &MakeParent($dbh,$parent,($bits -1),$region,$goal,$ver) || return(0) ;
    $done = &splitblock($dbh,$out,$goal,$region) || &IPDBError(-1,"Splitblock failed #2");
  }
  return($done);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#       ListRegions()
# Takes:
#       Database Connection (pg to ipdb)
# Returns:
#       prints a list (HTML Select list) of regions.
#
sub ListRegions
{
  etrace(@_);
  my $dbh = shift;
  my $parent = shift || '0';
  my $tab = shift || '0';
  my @result = &QueryDB($dbh,"SELECT ID,NAME FROM REGIONTABLE WHERE PARENT = $parent ORDER BY NAME","Getting Region list");
  my @out;
  while (@out = $result[0]->fetchrow)
  {
    print "<OPTION VALUE=$out[0]>";
    if($tab)
    {
      my $k = $tab;
      while($k--)
      {
        print "-";
      }
    }
    print "$out[1]\n";
    ListRegions($dbh,$out[0],($tab +1));
  }
  FinishDB(@result);
}


sub RegionSelect
{
  etrace(@_);
  my $form = shift;
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $parent = shift;
  my $tab = shift;
  my $j = shift;
  $form->{ids}[0] = '---';
  $form->{names}[0] = " --- Please Choose ---\n";
  $parent ||= 0;
  my @result = &QueryDB($dbh,"SELECT ID,NAME FROM REGIONTABLE WHERE PARENT = $parent ORDER BY NAME","Getting Region list");
  my @out;
  while (@out = $result[0]->fetchrow) {
    $form->{ids}[$j] = $out[0];
    if($tab) {
      my $k = $tab;
      while($k--) {
        $form->{names}[$j] .= "-";
      }
    }
    $form->{names}[$j] .= $out[1];
    $j++;
    &RegionSelect($form,$dbh,$out[0],($tab + 1),$j);
        }
  if($parent == 0) {
    $form->{ids}[$j] = "";
    $form->{names}[$j] = "";
  }
}


#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  ListDeleteRegions()
# Takes:
#  Database Connection (pg to ipdb)
# Returns:
#  prints a list (HTML Select list) of regions.
#
sub ListDeleteRegions
{
  etrace(@_);
        my $dbh = shift;
  my $count = 0;
  my $sth = $dbh->prepare('SELECT ID,NAME FROM REGIONTABLE ORDER BY NAME');
  my @out;
  $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  while (@out = $sth->fetchrow) {
    if(!&RegionInUse($dbh,$out[0])) {
      print "<OPTION VALUE=$out[0]>$out[1]\n";
      $count++;
    }
  }
  $sth->finish;
  undef $sth;
  if(!$count) {
    print "<OPTION SELECTED> --- No Region's to Delete ---\n";
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  ListRA()
# Takes:
#  Database Connection (pg to ipdb)
# Returns:
#  prints a list (HTML Select list) of ra's
#
sub ListRA
{
  etrace(@_);
  my $dbh = shift;
  my $sth = $dbh->prepare('SELECT ID,NAME FROM RATABLE ORDER BY NAME');
  my @out;
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  while (@out = $sth->fetchrow) {
    print "<OPTION VALUE=$out[0]>$out[1]\n";
  }
  $sth->finish;
  undef $sth;
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  ListDeleteRA()
# Takes:
#  Database Connection (pg to ipdb)
# Returns:
#  prints a list (HTML Select list) of ra's
#
sub ListDeleteRA
{
  etrace(@_);
  my $dbh = shift;
  my $count = 0;
  my $sth = $dbh->prepare("SELECT ID,NAME FROM RATABLE ORDER BY NAME");
  my @out;
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  while (@out = $sth->fetchrow) {
    if(!&RAInUse($dbh,$out[0])) {
      print "<OPTION VALUE=$out[0]>$out[1]\n";
      $count++;
    }
  }
  if(!$count) {
    print "<OPTION SELECTED> --- No RA's to Delete ---\n";
  }
  $sth->finish;
  undef $sth;
}
#--------------------------------------------------------------------------------------

sub RegionInUse
{
  etrace(@_);
  my $dbh = shift;
  my $region = shift;
  my $sth = $dbh->prepare("SELECT COUNT(REGION) FROM IPDB WHERE REGION = $region GROUP BY REGION");
  my @out;
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  if($num) {
    @out = $sth->fetchrow;
    return($out[0]);
  } else {
    return(0);
  }
}

sub RAInUse
{
  etrace(@_);
  my $dbh = shift;
  my $ra = shift;
  my $sth = $dbh->prepare("SELECT COUNT(RA) FROM REGIONTABLE WHERE RA = $ra GROUP BY RA");
  my @out;
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  if($num) {
    @out = $sth->fetchrow;
    return($out[0]);
  } else {
    return(0);
  }
}

#--------------------------------------------------------------------------------------
#  Version()
# Takes:
#  Database Connection (pg to ipdb)
#  A block ID
# Returns:
#  (4||6) depending on version.
#
sub Version
{
  etrace(@_);
  my $dbh = shift;
  my $block = shift;
  my $sth = $dbh->prepare("SELECT r.v6 from REGIONTABLE r,IPDB i WHERE i.REGION = r.ID AND i.ID = $block");
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $num =~ s/E.*//g;
  if($num) {
      my @out = $sth->fetchrow;
      my $v = $out[0];
      if($v) { return(6);} else { return(4);}
  } else {
      &IPDBError(0,"Block not in database");
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
sub VersionFromRegion
{
  etrace(@_);
  my $dbh = shift;
  my $region = shift;
  my $query = "SELECT v6 from REGIONTABLE WHERE ID = $region";
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $num =~ s/E.*//g;
  if($num) {
    my @out = $sth->fetchrow;
    my $v = $out[0];
    if($v) { return(6);} else { return(4);}
  } else {
    &IPDBError(0,"Region not in database.");
  }
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  GetBroadcat()
# Takes:
#  Block in int.
#  Size of block in bits.
# Returns:
#  Broadcast in int form.
#  
#
sub GetBroadcast
{
  etrace(@_);
  my $block = Math::BigInt->new(shift);
  my $size = shift;
  my $ver = shift;
  my $num =
    $ver == 4
    ? 32
    :  $ver == 6
      ? 128
      : IPDBError(-1, "IP version $ver is unknown.");
  $size = $num - $size;
  while($size) {
                $size--;
    my $temp = Math::BigInt->new("1");
    $temp = $temp->blsft($size);
    $block = $block | $temp;
        }
  $block =~ s/\+//g;
        return($block);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  Addresses()
# Takes:
# Returns:
#
sub Addresses
{
  etrace(@_);
  my $size = shift;
  my $ver = shift;
  my $out = &GetBroadcast(0,$size,$ver);
  $out++; 
  return($out);
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  HDReport()
sub HDReport
{
  etrace(@_);
  my $dbh = shift;
  my $query = "SELECT ID,BITS,BLOCK,REGION FROM IPDB WHERE PARENT = 0 AND REGION != 4 ORDER BY REGION,BLOCK";
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my $Tinuse = Math::BigInt->new("0");
  my $Ttotal = Math::BigInt->new("0");
  my $inuse = Math::BigInt->new("0");
  
  my $i = 0;
  my @out;
  while (@out = $sth->fetchrow) {
    my $id = $out[0];
    my $ver = &Version($dbh,$id);
    my $bits = $out[1];
    $Ttotal += &Addresses($bits,$ver);
    my $block = $out[2];
    my $blk = &deci2ip($block,$ver);
    my $inuse = &HDChild($dbh,$id);
    $Tinuse += $inuse;
    my $hd;
    if($inuse == 0) {
      $hd = "0";
    } else {
      $hd = log10($inuse)/log10(&Addresses($bits,$ver));
    }
    printf("%15s / %2d  | %4f\n",$blk,$bits,$hd);
  }
  my $hd = log10($Tinuse)/log10($Ttotal);
  print "OVERALL: $hd\n";
}


sub HDChild
{
  etrace(@_);
  my $dbh = shift;
  my $id = shift;
  my $query = "SELECT ALLOCATED,CHILDL,CHILDR,BITS FROM IPDB WHERE ID = $id";
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my @out = $sth->fetchrow;
  my $ver = &Version($dbh,$id);
  my $inuse = Math::BigInt->new("0");
  $inuse = &Addresses($out[3],$ver);
  if($out[1]) {  #Have children
    $inuse = &HDChild($dbh,$out[1]);
    $inuse += &HDChild($dbh,$out[2]);
    return($inuse);
  } else {
    if($out[0]) { #We are allocated
      if($out[3] < 31) {
        return($inuse - 2);
      } else {
        return($inuse);
      }
    } else {
      return(0);
    }
  }
}

#--------------------------------------------------------------------------------------

sub log10
{
  etrace(@_);
  my $in = shift;
  return(log($in)/log(10));
}


#--------------------------------------------------------------------------------------
#  UtilDisplay()
# Takes:
#  A database connection to IPDB
# Prints:
#  A Block utilization report.
#
sub UtilDisplay
{
  etrace(@_);
  my $dbh = shift;
  my $query = 'SELECT ID,BLOCK,BITS FROM IPDB WHERE PARENT=0 AND REGION!=4';
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my $total = Math::BigInt->new("0");
  my $inuse = Math::BigInt->new("0");
  my $tnum = Math::BigInt->new("0");
  my $tinuse = Math::BigInt->new("0");
  my $pcnt = 0;
  my $i = 0;
  my @out;
  while (@out = $sth->fetchrow) {
    my $id = $out[0];
    my $block = $out[1];
    my $bits = $out[2];
    my $ver = &Version($dbh,$id);
    if($ver == 4) {
      $total = &Addresses($bits,$ver);
      $tnum += $total;
      my $blk = &deci2ip($block,$ver);
      my $inuse = &GetInUse($dbh,$id);  
      $tinuse += $inuse;
      $pcnt = ($inuse/$total)*100;
      printf("%40s/%3d | %.2f %% in-use\t%10d / %d\n",$blk,$bits,$pcnt,$inuse,$total);
    }
  }
  $tinuse =~ s/\+//g;
  $tnum =~ s/\+//g;
  $pcnt = ($tinuse/$tnum)*100;
  print "                                       ";
  printf("Total | %.2f %% in-use ",$pcnt);
  printf("\t%10d / %d in-use/total\n",$tinuse,$tnum);
  print "                                   ";
  printf("Class C's |                 ",$pcnt);
  $tinuse = $tinuse / 255;
  $tnum = $tnum / 255;
  printf("\t%10d / %d in-use/total\n",$tinuse,$tnum);
  print "                                   ";
  printf("Class B's |                 ",$pcnt);
  $tinuse = $tinuse / 255;
  $tnum = $tnum / 255;
  printf("\t%10d / %d in-use/total\n",$tinuse,$tnum);
  print "                                   ";
  printf("Class A's |                 ",$pcnt);
  $tinuse = $tinuse / 255;
  $tnum = $tnum / 255;
  printf("\t%10d / %d in-use/total\n",$tinuse,$tnum);
  $sth->finish;
  undef $sth;
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  UtilRegion()
# Takes:
#  A database connection to FreeIPdb
# Returns: a list of region and % in use.
#
sub UtilRegion
{
  etrace(@_);
  my $dbh = shift;
  my $query = 'SELECT BITS,ALLOCATED,REGION FROM IPDB WHERE CHILDL IS NULL AND REGION != 4 ORDER BY REGION';
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my $total = Math::BigInt->new("0");
  my $inuse = Math::BigInt->new("0");
  my $tnum = Math::BigInt->new("0");
  my $tinuse = Math::BigInt->new("0");
  my $i = 0;
  my $number;
  my $largest;
  my $oldregion = '';
  my $regionname;
  my $pcnt = 0;
  my @out;
  while (@out = $sth->fetchrow) {
    my $bits = $out[0];
    my $alloc = $out[1];
    my $region = $out[2];
    if(!$largest) {$largest = $bits;}
    if($bits < $largest) { $largest = $bits;}
    my $ver = &VersionFromRegion($dbh,$region);
    if($ver == 4) {
      if($oldregion && ($oldregion ne $region)) {
        $inuse =~ s/\+//g;
        $total =~ s/\+//g;
        $pcnt = ($inuse/$total)*100;
        $regionname = &LookupRegion($dbh,$oldregion);
        printf("%20s | %.2f %% in-use  [/%d LFB]",$regionname,$pcnt,$largest);
        printf("\t%10d / %d in-use/total\n",$inuse,$total);
        $oldregion = $region;
        $total = Math::BigInt->new("0");
        $inuse = Math::BigInt->new("0");
        $largest = 128;
      } else {
        $oldregion = $region;
      }
      $number = &Addresses($bits,$ver);
      $total += $number;
      $tnum += $number;
      if($alloc) { 
        $inuse += $number;
        $tinuse += $inuse;
      }
    }
  }
  $inuse =~ s/\+//g;
  $total =~ s/\+//g;
  $pcnt = ($inuse/$total)*100;
        $regionname = &LookupRegion($dbh,$oldregion);
  printf("%20s | %.2f %% in-use  [/%d LFB]",$regionname,$pcnt,$largest);
  printf("\t%10d / %d in-use/total\n",$inuse,$total);
  $tinuse =~ s/\+//g;
  $tnum =~ s/\+//g;
  $pcnt = ($tinuse/$tnum)*100;
  print "               ";
  printf("Total | %.2f %% in-use ",$pcnt);
  printf("\t\t%10d / %d in-use/total\n",$tinuse,$tnum);
  print "[LFB = Largest Free Block]\n";
  $sth->finish;
  undef $sth;
}
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#  GetInUse()
# Takes:
#  A database connection to IPDB
#  The ID of a block to return in-use of.
# Returns:
#  A Math::BigInt od the numbre of addresses in use
#    recurssivly from this parent block
#
sub GetInUse
{
  etrace(@_);
  my $dbh = shift;
  my $block = shift;
  # Get info on children
  my $sth = $dbh->prepare("SELECT I.CHILDL,I.CHILDR,I.BITS,I.ALLOCATED,R.V6 FROM IPDB I, REGIONTABLE R WHERE I.ID = $block AND I.REGION = R.ID");
  my $num = $sth->execute;
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my @out = $sth->fetchrow;
  my $childl = $out[0];
  my $childr = $out[1];
  my $size = $out[2];
  my $allocated = $out[3];
  my $ver = $out[4];
  if($ver) {$ver = 6;} else { $ver = 4;}
  if(!$childl && !$childr) {
    if($allocated) {
      return(&Addresses($size,$ver));
    } else {
      return(0);
    }
  } 
  my $rtotal;
  my $ltotal;
  # Get info from childl
  my $sthl = $dbh->prepare("SELECT I.ALLOCATED,I.BITS,R.v6 FROM IPDB I,REGIONTABLE R WHERE I.ID = $childl AND I.REGION = R.ID");
  my $numl = $sthl->execute;
  if($sthl->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $numl =~ s/E.*//g;
  if($numl) {
    my @outl = $sthl->fetchrow;
    if($outl[0]) {
      my $verl = $outl[2];
      if($verl) {$ver = 6;} else { $ver = 4;}
      $ltotal = &Addresses($outl[1],$ver);
    } else {
      $ltotal =  &GetInUse($dbh,$childl);
    }
  } else {
    &IPDBError(-1,"Could not query Left block [$childl].");
  }
  # Get info from childr
  my $sthr = $dbh->prepare("SELECT I.ALLOCATED,I.BITS,R.v6 FROM IPDB I,REGIONTABLE R WHERE I.ID = $childr AND I.REGION = R.ID");
  my $numr = $sthr->execute;
  if($sthr->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $numr =~ s/E.*//g;
  if($numr) {
    my @outr = $sthr->fetchrow;
    if($outr[0]) {
      my $verr = $outr[2];
      if($verr) {$ver = 6;} else { $ver = 4;}
      $rtotal = &Addresses($outr[1],$ver);
    } else {
      $rtotal = &GetInUse($dbh,$childr);
    }
  } else {
    &IPDBError(-1,"Could not query Right Block. [$childr]");
  }
  # Combine results
  my $out = $rtotal + $ltotal;
  # Give output
  $sth->finish;
  undef $sth;
  return($out);
}
#--------------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Subroutine ip_inttobin
# Purpose           : Transform a BigInt into a bit string
# Comments          : sets warnings (-w) off.
#                     This is necessary because Math::BigInt is not compliant
# Params            : BigInt, IP version
# Returns           : bit string
sub ip_inttobin
{
  etrace(@_);
  my $dec = Math::BigInt->new (shift);
  # Find IP version
  my $ip_version = shift;
  $ip_version or do
  {
    my $ERROR = "Cannot determine IP version for $dec";
    my $ERRNO = 101;
    return;
  };
  # Define normal size for address
  my %IPLengths = ( 4 => 32 , 6 => 128);
  # Number of bits depends on IP version
  my $maxn = $IPLengths{$ip_version};
  my ($n, $binip);
  # Set warnings off, use integers only (loathe Math::BigInt)
  local $^W = 0;
  use integer;
  for ($n=0;$n < $maxn;$n++)
  {
    # Bit is 1 if $dec cannot be divided by 2
    $binip .= $dec%2;
    # Divide by 2, without fractional part
    $dec/= 2;
  };
  no integer;
  # Strip + signs
  $binip =~ s/\+//g;
  # Reverse bit string
  return scalar reverse $binip;
}

#------------------------------------------------------------------------------
# Subroutine ip_bintoip
# Purpose           : Transform a bit string into an IP address
# Params            : bit string, IP version
# Returns           : IP address on success, undef otherwise
sub ip_bintoip
{
  etrace(@_);
        my ($binip,$ip_version) = @_;

  # Number of bits for each IP version
  my %IPLengths = ( 4 => 32 , 6 => 128);

        # Define normal size for address
        my $len = $IPLengths{$ip_version};

        # Prepend 0s if address is less than normal size
        $binip = '0'x($len-length($binip)).$binip;

        # IPv4
        $ip_version == 4 and
                return join '.', unpack( 'C4C4C4C4', pack( 'B32', $binip ));

        # IPv6
        return join (':', unpack( 'H4H4H4H4H4H4H4H4', pack( 'B128', $binip )));
}

#------------------------------------------------------------------------------
# Subroutine ip_bintoint
# Purpose           : Transform a bit string into an Integer
# Params            : bit string
# Returns           : BigInt
sub ip_bintoint
{
  etrace(@_);
        my $binip = shift;

        require Math::BigInt;

        # $n is the increment, $dec is the returned value
        my ($n,$dec) = (Math::BigInt->new (1),Math::BigInt->new (0));

        # Reverse the bit string
        foreach (reverse (split '', $binip))
        {
                # If the nth bit is 1, add 2**n to $dec
                $_ and $dec += $n;
                $n*=2;
        };
        # Strip leading + sign
        $dec=~s/^\+//;
        return $dec;
}

sub GetBlockId
{
  etrace(@_);
        my $dbh = shift;
        my $block = shift;
        my $bits = shift;
        my $region = shift;
        my $query = "SELECT ID FROM IPDB WHERE BLOCK = ".$block."::NUMERIC(40,0) AND BITS = $bits AND REGION = $region";
        my $sth = $dbh->prepare($query);
  my $num = $sth->execute();
        if($sth->err) { 
    IPDBError(-1,$DBI::errstr);
  }
        if($num) {
    my @out = $sth->fetchrow;
                my $id = $out[0];
                return($id);
        }   
  $sth->finish;
  undef $sth;
}

sub GetBlockFromID
{
  etrace(@_);
  my $dbh = shift;
  my $id = shift;
  my $query = "SELECT BLOCK,BITS,REGION,ALLOCATED,PARENT,CHILDL,CHILDR,CUSTDESC,CUSTNUM FROM IPDB WHERE ID = $id";
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute();
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $num =~ s/E.*//g;
  if($num) {
    my @out = $sth->fetchrow;
    return(@out);
  }
  $sth->finish;
  undef $sth;
}

# Returns 1 if block has any DNS associated with it.
sub CheckDNS
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $query = "SELECT ID FROM zone_record_table WHERE BLOCK = $id";
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute();
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $sth->finish;
  $num =~ s/E.*//g;
  if($num) {
    return(1);
  } else {
    return(0);
  }
}

sub CheckRWhois
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $query = "SELECT ID FROM justificationtable WHERE BLOCK = $id";
  my $sth = $dbh->prepare($query);
  my $num = $sth->execute();
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $sth->finish;
  $num =~ s/E.*//g;
  if($num) {
    return(1);
  } else {
    return(0);
  }
}

# Returns 1 if zone has any 
sub CheckZone
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $sth = $dbh->prepare( 'SELECT ID FROM zone_record_table WHERE ZONE=?' );
  my $num = $sth->execute( $id );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $sth->finish;
  $sth = $dbh->prepare( 'SELECT REVERSE_BLOCK FROM ZONE_TABLE WHERE ID=?' );
  my $num3 = $sth->execute( $id );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  my @out = $sth->fetchrow;
  my $num2;
  if($out[0]) {
    $num2 = &RevCheckZone($dbh,$out[0]);
  }
  $num =~ s/E.*//g;
  $sth->finish;
  if($num || $num2) {
    return(1);
  } else {
    return(0);
  }
}

sub ZoneChild
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $id = shift or IPDBError(-1,'missing arg');
  my $sth = $dbh->prepare( 'SELECT ID FROM zone_table WHERE PARENT=?' );
  my $num = $sth->execute( $id );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  return($num);
}

# Do the recursion for CheckZone
sub RevCheckZone
{
  etrace(@_);
  my $dbh = shift or IPDBError(-1,'missing arg');
  my $block = shift or IPDBError(-1,'missing arg');
  my $sth = $dbh->prepare( 'SELECT CHILDL,CHILDR FROM IPDB WHERE ID=?' );
  my $num = $sth->execute( $block );
  if($sth->err) {
    IPDBError(-1,$DBI::errstr);
  }
  $num =~ s/E.*//g;
  if($num) {
    my @out = $sth->fetchrow;  
    my $childl = $out[0];
    my $childr = $out[1];  
    if($childr) {
      my $return1 = &RevCheckZone($dbh,$childl);
      my $return2 = &RevCheckZone($dbh,$childr);
      $sth->finish;
      return($return1 + $return2);
    } else {
      my $sth2 = $dbh->prepare( 'SELECT count(ID) FROM ZONE_RECORD_TABLE WHERE BLOCK=?' );
      my $num2 = $sth2->execute( $block );
      if($sth2->err) {
        IPDBError(-1,$DBI::errstr);
      }
      @out = $sth2->fetchrow;
      $sth2->finish;
      return($out[0]);
    }
  }
}


sub argErr { goto &IPDBError(-1,'missing arg') }


sub etrace
{
  defined $config::config{'debug'}&&$config::config{'debug'}>0
  ? warn sprintf("[%s] %s(%s): %s(%s)\n", strftime('%H:%M:%S', localtime), (caller(1))[1..3],join(', ',map{qq("$_")}@_))
  : 1;
}


1;


