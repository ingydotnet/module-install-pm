#!/usr/bin/perl

# Check that ppport works

use strict;
use vars qw{$VERSION};
BEGIN {
	$|       = 1;
	$^W      = 1;
	$VERSION = '0.81';
}

use Test::More tests => 1;

ok( -f 'ppport.h', 'Found ppport.h' );
