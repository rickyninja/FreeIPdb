#!/usr/bin/perl -w

use strict;
use Math::BigInt;

# Just for fun, here's an example bit of code.  It should print "1\n" and
# exit almost immediately.  If this code hangs, you need to upgrade your
# Math::BigInt:
# -monte

print "\n\n --- Math::BigInt (blsft) test ---\n\n";
print "If you don't see \"Done\"";
print " in a few seconds try a diffrent version of Math::BigInt\n";

my $temp = Math::BigInt->new(1);
$temp = $temp->blsft(0);
print "$temp\n";

print "Done. You're good to go!\n";
print "\n";

