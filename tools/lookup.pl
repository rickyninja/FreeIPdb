#!/usr/bin/perl

require '../ipdb_lib.pl';

$| = 1;

my $in = shift || die "No input";

if($in =~ /\./ || $in =~ /\:/){
        $blockout = ip2deci($in);
} else {
        $blockout = deci2ip($in,4);
}
#exit("$blockout");
print "$blockout";
