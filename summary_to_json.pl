#!/usr/bin/perl

use strict;
use warnings;

print "[ ";

while (<>) {
    chomp;
    print "$_,";
}

print "{}]";
