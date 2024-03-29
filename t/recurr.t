#!/bin/perl -w
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Date::Set
#

use strict;
# use warnings;
use Test::More qw(no_plan);
$| = 1;
BEGIN { use_ok('Date::Set') };

my $a2;
my $a = Date::Set->new('19971024T120000Z', '19971024T130000Z');
is("$a", '[19971024T120000Z..19971024T130000Z]', 'simple date set creation works');

$a = Date::Set->period( start => '19971024T120000Z', end => '19971024T130000Z' );
is("$a",'[19971024T120000Z..19971024T130000Z]', 
    'creation of a date period with time => [foo] works');

# dtstart - after
$b = $a->dtstart( start => '19971024T123000Z' );
is("$b",'[19971024T123000Z..19971024T130000Z]', 
    'dtstart() works to set starting time');

$b = $a->dtstart( start => '19971024T113000Z' );
is("$b",'19971024T113000Z,[19971024T120000Z..19971024T130000Z]',
    "dtstart() adds itself to the set");

$b = $a->dtend( end => '19971024T121000Z' );
is("$b",'[19971024T120000Z..19971024T121000Z]',
    "dtend() works to set finish time");

$b = $a->duration( unit => 'days', duration => 5 );
is("$b",'[19971024T120000Z..19971029T120000Z]',
    "setting the duration of a date set in days works");

$b = Date::Set->recur_by_date( list => [ '19970101Z', '19970102Z' ] );
is("$b",'19970101Z,19970102Z',
    "using recur_by_date to create a date list");

$b = Date::Set->recur_by_date( list => [ '19970101Z', '19970102Z' ] )->recur_by_date( list => [ '19970101Z', '19970103Z' ] );
is("$b",'19970101Z,19970102Z,19970103Z',
    "using recur_by_date to extend a date list");

$b = Date::Set->recur_by_date( list => [ '19970101Z', '19970102Z' ] )->exclude_by_date( list => [ '19970101Z' ] );
is("$b",'19970102Z',
    "using exclude_by_date to remove a date from a list");

# $a is now a period spanning the year 1997.
$a = Date::Set->period( time => ['19970101Z', '19971231T235959Z'] );


# NOTE: "DTSTART" is *ALWAYS* included in the recurrence set,
# whether or not it matches the rule.

# DTSTART tests
	# $a2 has 'month'.
	$a2 = Date::Set->period( time => ['19970506Z', '19981231T235959Z'] );
	$b = $a2->recur_by_rule( DTSTART => $a2->min, FREQ => 'YEARLY' );
	is("$b",'19970506Z,19980506Z', 
		"recur_by_rule() gets month from DTSTART");

# $Date::Set::DEBUG=1;
# recur_by_rule as constructor, without 'period'
$b = Date::Set->recur_by_rule( DTSTART => $a->min, BYMONTH => [ 10 ] )->occurrences( period => $a );
is("$b",'19970101Z,19971001Z',
	"recur_by_rule() constructor is ok and includes DTSTART");
# $Date::Set::DEBUG=0;

# recur_by_rule as constructor, with 'period'
# $Date::Set::DEBUG=1;
# $Set::Infinite::TRACE=1;
# print " period is $a \n";
# print " DTSTART is ",$a->min," \n";
# $Set::Infinite::TRACE=0;
$b = Date::Set->recur_by_rule( DTSTART => $a->min, period => $a, BYMONTH => [ 10 ] );
# exit;
is("$b",'19970101Z,19971001Z',
	"recur_by_rule() constructor with period is ok");
# $Date::Set::DEBUG=0;



$b = $a->recur_by_rule( DTSTART => $a->min, BYMONTH => [ 9,10,11 ] )->exclude_by_rule( DTSTART => $a->min, BYMONTH => [ 10 ] );
is("$b",'19970101Z,19970901Z,19971101Z',
	"exrule() works");

# TODO more testing for exclude_by_rule could be cool

$b = $a->recur_by_rule( DTSTART => $a->min, BYMONTH => [ 10 ] );
is("$b",'19970101Z,19971001Z',
	"recur_by_rule() interprets BYMONTH correctly");

$b = $a->recur_by_rule( DTSTART => $a->min, BYMONTH => [ -11 ] );
# is( $@, '', "recur_by_rule() with a negative BYMONTH runs without dying");
# find the 10th month before the end of the year (february)
is("$b",'19970101Z,19970201Z',
	"recur_by_rule() interprets BYMONTH with negative numbers correctly");
    
# find the 10th week of the year
$b = $a->recur_by_rule( DTSTART => $a->min, BYWEEKNO => [ 10 ] );
is("$b",'19970101Z,19970303Z',
    "recur_by_rule() interprets BYWEEKNO with positive numbers correctly");

# figure out the 10th week before the end of the year
$b = $a->recur_by_rule( DTSTART => $a->min, BYWEEKNO => [ -11 ] );
is("$b",'19970101Z,19971013Z',
    "recur_by_rule() interprets BYWEEKNO with negative numbers correctly");

# this means "repeat on the 10th day of every year"
$b = $a->recur_by_rule( DTSTART => $a->min, BYYEARDAY => [ 10 ] );
is("$b",'19970101Z,19970110Z',
    "recur_by_rule() interprets BYYEARDAY with positive numbers correctly");

# this means "repeat on the day that's 10 days before the end of the year"
$b = $a->recur_by_rule( DTSTART => $a->min, BYYEARDAY => [ -11 ] );
is("$b",'19970101Z,19971221Z',
    "recur_by_rule() interprets BYYEARDAY with negative numbers correctly");

# this means "repeat on the 10th day of the month"
$b = $a->recur_by_rule( DTSTART => $a->min, BYMONTHDAY => [ 10 ] );
is("$b",'19970101Z,19970110Z,19970210Z,19970310Z,19970410Z,19970510Z,19970610Z,19970710Z,19970810Z,19970910Z,19971010Z,19971110Z,19971210Z',
    'recur_by_rule() interprets BYMONTHDAY with positive numbers correctly');

# this means "repeat on the 10th day before the end of every month"
$b = $a->recur_by_rule( DTSTART => $a->min, BYMONTHDAY => [ -11 ] );
is("$b",'19970101Z,19970121Z,19970218Z,19970321Z,19970420Z,19970521Z,19970620Z,19970721Z,19970821Z,19970920Z,19971021Z,19971120Z,19971221Z',
    'recur_by_rule() interprets BYMONTHDAY with negative numbers correctly');

# all wednesdays
$b = $a->recur_by_rule( DTSTART => $a->min, UNTIL => '19970201Z', BYDAY => [ qw(WE) ] );
is("$b",'19970101Z,19970108Z,19970115Z,19970122Z,19970129Z',
    'recur_by_rule() with BYDAY and UNTIL works correctly');
    
# some wednesdays
$b = $a->recur_by_rule( DTSTART => $a->min, FREQ => 'WEEKLY', COUNT => 3, BYDAY => [ qw(WE) ] );
is("$b",'19970101Z,19970108Z,19970115Z',
    'recur_by_rule() with BYDAY and COUNT works correctly');
    
# last wednesday of month
$b = $a->recur_by_rule( DTSTART => $a->min, FREQ => 'MONTHLY', UNTIL => '19970301Z', BYDAY => [ qw(-1WE) ] );
is("$b",'19970101Z,19970129Z,19970226Z',
    'recur_by_rule() with BYDAY and UNTIL works on "last Wednesday of month" syntax (-1WE)');

# last wednesday of year
$b = $a->recur_by_rule( DTSTART => $a->min, FREQ => 'YEARLY', UNTIL => '19980101Z', BYDAY => [ qw(-1WE) ] );
# changed this when using WKST to find last week!
# is("$b",'19971231Z',
is("$b",'19970101Z,19971231Z',
    'recur_by_rule() with BYDAY and UNTIL works on "last Wednesday of year" syntax');

# $Date::Set::DEBUG = 1;

$b = $a->recur_by_rule( DTSTART => $a->min, UNTIL => '19970103Z', BYHOUR => 10 );
is("$b",'19970101Z,19970101T100000Z,19970102T100000Z',
    'recur_by_rule() with UNTIL and BYHOUR ("10am every day") works');
    
# this is not in the RFC
# $b = $a->recur_by_rule( UNTIL => '19970103Z', BYHOUR => [ -10 ] );

$b = $a->recur_by_rule( DTSTART => $a->min, UNTIL => '19970101T030000Z', BYMINUTE => [ 10 ] );
is("$b",'19970101Z,19970101T001000Z,19970101T011000Z,19970101T021000Z',
    'recur_by_rule() with UNTIL and BYMINUTE ("10 minutes after the start of the hour") works');
    
# this is not in the RFC
# $b = $a->recur_by_rule( UNTIL => '19970101T030000Z', BYMINUTE => [ -10 ] );

$b = $a->recur_by_rule( DTSTART => $a->min, UNTIL => '19970101T000300Z', BYSECOND => [ 10 ] );
is("$b",'19970101Z,19970101T000010Z,19970101T000110Z,19970101T000210Z',
    'recur_by_rule() works with UNTIL and BYSECOND ("the 10th second of every minute")');
    
# this is not in the RFC
# $b = $a->recur_by_rule( UNTIL => '19970101T000300Z', BYSECOND => [ -10 ] );

# BYSETPOS, FREQ, INTERVAL, COUNT

# recur_by_rule parses RRULEs properly.
$b = Date::Set->recur_by_rule( DTSTART => $a->min, RRULE => "BYMONTH=10" )->occurrences( period => $a );
is("$b",'19970101Z,19971001Z',
	"recur_by_rule() constructor is ok when called with a simple RRULE");

# recur_by_rule parses RRULEs properly.
$b = Date::Set->recur_by_rule( DTSTART => $a->min, RRULE => "BYMONTH=10,11" )->occurrences( period => $a );
is("$b",'19970101Z,19971001Z,19971101Z',
	"recur_by_rule() constructor is ok when called with a simple RRULE");

# occurrences



# test first()/tail of unbounded set
# (same test as in t/rfc2445.t)

my ($title, $period, $first, $tail);

$title="***  Every other week on Tuesday and Thursday, unlimited  ***";
#
#     DTSTART;TZID=US-Eastern:19970902T090000
#     recur_by_rule:FREQ=WEEKLY;INTERVAL=2;WKST=SU;BYDAY=TU,TH
#
#     ==> (1997 9:00 AM EDT)September 2,4,16,18,30;October 2,14,16
#

# $Set::Infinite::TRACE = 1;
# $Set::Infinite::PRETTY_PRINT = 1;
	$a = Date::Set->event->dtstart( start => '19970902T090000Z' )
		->recur_by_rule( RRULE=>'FREQ=WEEKLY;INTERVAL=2;WKST=SU;BYDAY=TU,TH' );

    # warn "$a is a ".$a->{method};
    $first = $a->first;
	is("$first", "19970902T090000Z", $title . " - scalar context");

    ($first, $tail) = $a->first;
	is("$first", 
    '19970902T090000Z', $title . " - list context - #1");

    ($first, $tail) = $tail->first;
	is("$first", 
    '19970904T090000Z', $title . " - #2");

    ($first, $tail) = $tail->first;
	is("$first", 
    '19970916T090000Z', $title . " - #3");

    ($first, $tail) = $tail->first;
	is("$first", 
    '19970918T090000Z', $title . " - #4");


# test Martijn's unbounded set
my $set = Date::Set->event(rule => 'FREQ=YEARLY');
$a = $set->during( start => '20020101Z');

    is ( $a->min, '20020101Z', 'min is defined');

# make it a bit more difficult
$set = Date::Set->event(rule => 'FREQ=YEARLY;BYMONTH=3');
$a = $set->during( start => '20020101Z');

    is ( $a->min, '20020301Z', 'min is working properly');

# TODO: complement() is not working properly

TODO: {
    local $TODO = 'complement() test is disabled';
    is ( 'not testing', 'testing', '' );
}
__END__

# $Set::Infinite::TRACE = 1;

    ($first, $tail) = $a->complement( $a->first )->first;
	is("$first", 
    '20030301Z', $title . " - #2nd");

    ($first, $tail) = $tail->first;
	is("$first", 
    '20040301Z', $title . " - #3rd");

    ($first, $tail) = $tail->first;
	is("$first", 
    '20050301Z', $title . " - #4th");


    $first = "" . $a->complement( $a->first )->first;  # doesn't work without ""!
    is ( $first, '20030301Z', 'first again');

# $Set::Infinite::TRACE = 1;
# $Set::Infinite::PRETTY_PRINT = 1;

    is ( $a->complement( $a->min )->min, '20030301Z', 'min is exact');
$Set::Infinite::TRACE = 0;


# TODO: first() doesn't work after intersection()

    ($first, $tail) = $a->first;
    is("$first", '20020301Z', "first - #1");

    ($first, $tail) = $tail->first;
    is("$first", '20030301Z', "first - #2");

1;
