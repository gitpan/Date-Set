#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Date::Set
#

use strict;
use warnings;
use Test::More qw(no_plan);

BEGIN { use_ok('Date::Set') };
use Date::Set qw($inf);

$a = Date::Set->new('19971024T120000Z', '19971024T130000Z');

# test operations unique to ICal.pm.

is("$a",'[19971024T120000Z..19971024T130000Z]', 
    "doublequote operator overloading works and produces proper output");

# these all seem to be tests for the inherited functionality. 
ok($a->size == 3600, "size() function returns correct length (3600) for an hour period");

is($a->union("19971024T160000Z", "19971024T170000Z")->as_string,
    '[19971024T120000Z..19971024T130000Z],[19971024T160000Z..19971024T170000Z]',
    'union() returns a correct set for the union of 2 periods');

is($a->complement->as_string,
    "(-$inf..19971024T120000Z),(19971024T130000Z..$inf)",
    'complement() with no args correctly returns the infinite set of time not in the period');

is($a->complement('19971024T122000Z','19971024T124000Z')->as_string,
    '[19971024T120000Z..19971024T122000Z),(19971024T124000Z..19971024T130000Z]',
    'complement() with args correctly returns the bounded set of time not in the period');

is( join (" ", $a->quantize(unit=>"weeks")->compact ) ,
	"[19971019Z..19971026Z)",
    'describe this test, please; clarify how quantize() works');


# "This event happens from 13:00 to 14:00 every Tuesday, unless that Tuesday is the 15th of the month."

my $interval = Set::Infinite->new('20010501Z')->quantize(unit=>'months');
# print "Weeks: ", $interval->quantize(unit=>'weeks'), "\n";
my $tuesdays = $interval->quantize(unit=>'weeks')->
	offset( mode => 'begin', unit=>'days', value => [ 2 , 3 ] );

# print "tuesdays: ", $tuesdays, "\n";
my $fifteenth = $interval->quantize(unit=>'months')->
	offset( mode => 'begin', unit=>'days', value => [ 14 , 15 ] );

# print "fifteenth: ", $fifteenth, "\n";

my $events =  $tuesdays -> complement ( $fifteenth ) ->
	offset( mode => 'begin', unit=>'hours', value => [ 13 , 14 ] );
# print "events in may 2001: ", $events;
is("$events",
	"[20010501T130000Z..20010501T140000Z),[20010508T130000Z..20010508T140000Z),[20010522T130000Z..20010522T140000Z),[20010529T130000Z..20010529T140000Z)",
    'describe this test, please; reduce this test into smaller tests, or document better');

# TESTS FOR FUNCTIONS THAT GET USED IN OVERLOADS -------------------

# Test with an epoch string from the 1970s
$a = Date::Set::ICal->new('25682400');
is($a->date_ical->epoch(), 25682400 , "Parsed an epoch time from 1970 correctly");

LAST: 
1;
