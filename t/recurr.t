#!/bin/perl
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

my $a2;
my $a = Date::Set->new('19971024T120000Z', '19971024T130000Z');
is("$a", '[19971024T120000Z..19971024T130000Z]', 'simple date set creation works');

$a = Date::Set->period( time => ['19971024T120000Z', '19971024T130000Z'] );
is("$a",'[19971024T120000Z..19971024T130000Z]', 
    'creation of a date period with time => [foo] works');

# dtstart - after
$b = $a->dtstart( start => '19971024T123000Z' );
is("$b",'[19971024T123000Z..19971024T130000Z]', 
    'dtstart() works to set starting time');

$b = $a->dtstart( start => '19971024T113000Z' );
is("$b",'[19971024T120000Z..19971024T130000Z]',
    "dtstart() can't be set to an earlier date after being set");

$b = $a->dtend( end => '19971024T121000Z' );
is("$b",'[19971024T120000Z..19971024T121000Z]',
    "dtend() works to set finish time");

$b = $a->duration( unit => 'days', duration => 5 );
is("$b",'[19971024T120000Z..19971029T120000Z]',
    "setting the duration of a date set in days works");

$b = Date::Set->rdate( list => [ '19970101Z', '19970102Z' ] );
is("$b",'19970101Z,19970102Z',
    "using rdate to create a date list");

$b = Date::Set->rdate( list => [ '19970101Z', '19970102Z' ] )->rdate( list => [ '19970101Z', '19970103Z' ] );
is("$b",'19970101Z,19970102Z,19970103Z',
    "using rdate to extend a date list");

$b = Date::Set->rdate( list => [ '19970101Z', '19970102Z' ] )->exdate( list => [ '19970101Z' ] );
is("$b",'19970102Z',
    "using exdate to remove a date from a list");

# $a is now a period spanning the year 1997.
$a = Date::Set->period( time => ['19970101Z', '19971231T235959Z'] );

# DTSTART tests
	# $a2 has 'month'.
	$a2 = Date::Set->period( time => ['19970506Z', '19981231T235959Z'] );
	$b = $a2->rrule( FREQ => 'YEARLY' );
	is("$b",'19970506Z,19980506Z', 
		"rrule() gets month from DTSTART");


# rrule as constructor, without 'period'
$b = Date::Set->rrule( BYMONTH => [ 10 ] )->occurrences( period => $a );
is("$b",'19971001Z', 
	"rrule() constructor is ok");

# rrule as constructor, with 'period'
$b = Date::Set->rrule( period => $a, BYMONTH => [ 10 ] );
is("$b",'19971001Z', 
	"rrule() constructor with period is ok");



$b = $a->rrule( BYMONTH => [ 9,10,11 ] )->exrule( BYMONTH => [ 10 ] );
is("$b",'19970901Z,19971101Z', 
	"exrule() works");



$b = $a->rrule( BYMONTH => [ 10 ] );
is("$b",'19971001Z', 
	"rrule() interprets BYMONTH correctly");

$b = $a->rrule( BYMONTH => [ -10 ] );
# is( $@, '', "rrule() with a negative BYMONTH runs without dying");
# find the 10th month before the end of the year (february)
is("$b",'19970201Z', 
	"rrule() interprets BYMONTH with negative numbers correctly");
    
# find the 10th week of the year
$b = $a->rrule( BYWEEKNO => [ 10 ] );
is("$b",'19970303Z',
    "rrule() interprets BYWEEKNO with positive numbers correctly");

# figure out the 10th week before the end of the year
$b = $a->rrule( BYWEEKNO => [ -10 ] );
is("$b",'19971013Z',
    "rrule() interprets BYWEEKNO with negative numbers correctly");

# this means "repeat on the 10th day of every year"
$b = $a->rrule( BYYEARDAY => [ 10 ] );
is("$b",'19970110Z',
    "rrule() interprets BYYEARDAY with positive numbers correctly");

# this means "repeat on the day that's 10 days before the end of the year"
$b = $a->rrule( BYYEARDAY => [ -10 ] );
is("$b",'19971221Z',
    "rrule() interprets BYYEARDAY with negative numbers correctly");

# this means "repeat on the 10th day of the month"
$b = $a->rrule( BYMONTHDAY => [ 10 ] );
is("$b",'19970110Z,19970210Z,19970310Z,19970410Z,19970510Z,19970610Z,19970710Z,19970810Z,19970910Z,19971010Z,19971110Z,19971210Z',
    'rrule() interprets BYMONTHDAY with positive numbers correctly');

# this means "repeat on the 10th day before the end of every month"
$b = $a->rrule( BYMONTHDAY => [ -10 ] );
is("$b",'19970121Z,19970218Z,19970321Z,19970420Z,19970521Z,19970620Z,19970721Z,19970821Z,19970920Z,19971021Z,19971120Z,19971221Z',
    'rrule() interprets BYMONTHDAY with negative numbers correctly');

# all wednesdays
$b = $a->rrule( UNTIL => '19970201Z', BYDAY => [ qw(WE) ] );
is("$b",'19970101Z,19970108Z,19970115Z,19970122Z,19970129Z',
    'rrule() with BYDAY and UNTIL works correctly');
    
# last wednesday of month
$b = $a->rrule( FREQ => 'MONTHLY', UNTIL => '19970301Z', BYDAY => [ qw(-1WE) ] );
is("$b",'19970129Z,19970226Z', 
    'rrule() with BYDAY and UNTIL works on "last Wednesday of month" syntax (-1WE)');

# last wednesday of year
$b = $a->rrule( FREQ => 'YEARLY', UNTIL => '19980101Z', BYDAY => [ qw(-1WE) ] );
is("$b",'19971231Z',
    'rrule() with BYDAY and UNTIL works on "last Wednesday of year" syntax');

$b = $a->rrule( UNTIL => '19970103Z', BYHOUR => [ 10 ] );
is("$b",'19970101T100000Z,19970102T100000Z',
    'rrule() with UNTIL and BYHOUR ("10-11am every day") works');
    
# this is not in the RFC
# $b = $a->rrule( UNTIL => '19970103Z', BYHOUR => [ -10 ] );

$b = $a->rrule( UNTIL => '19970101T030000Z', BYMINUTE => [ 10 ] );
is("$b",'19970101T001000Z,19970101T011000Z,19970101T021000Z',
    'rrule() with UNTIL and BYMINUTE ("10 minutes after the start of the hour") works');
    
# this is not in the RFC
# $b = $a->rrule( UNTIL => '19970101T030000Z', BYMINUTE => [ -10 ] );

$b = $a->rrule( UNTIL => '19970101T000300Z', BYSECOND => [ 10 ] );
is("$b",'19970101T000010Z,19970101T000110Z,19970101T000210Z',
    'rrule() works with UNTIL and BYSECOND ("the 10th second of every minute")');
    
# this is not in the RFC
# $b = $a->rrule( UNTIL => '19970101T000300Z', BYSECOND => [ -10 ] );

# BYSETPOS, FREQ, INTERVAL, COUNT

# occurrences

1;
