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

$b = $a->duration( unit => 'days', duration => 5 );
is("$b",'[19971024T120000Z..19971029T120000Z]',
    "setting the duration of a date set in days works");

# $a is now a period spanning the year 1997.
$a = Date::Set->period( time => ['19970101T000000Z', '19971231T235959Z'] );

$b = $a->rrule( BYMONTH => [ 10 ] );
is("$b",'[19971001Z..19971101Z)', "rrule() interprets BYMONTH correctly");

    $b = $a->rrule( BYMONTH => [ -10 ] );
    # is( $@, '', "rrule() with a negative BYMONTH runs without dying");
    # find the 10th month before the end of the year (february)
    is("$b",'[19970201Z..19970301Z)', 
            "rrule() interprets BYMONTH with negative numbers correctly");
    
# find the 10th week of the year
$b = $a->rrule( BYWEEKNO => [ 10 ] );
is("$b",'[19970303Z..19970310Z)',
    "rrule() interprets BYWEEKNO with positive numbers correctly");

# figure out the 10th week before the end of the year
$b = $a->rrule( BYWEEKNO => [ -10 ] );
is("$b",'[19971013Z..19971020Z)',
    "rrule() interprets BYWEEKNO with negative numbers correctly");

# this means "repeat on the 10th day of every year"
$b = $a->rrule( BYYEARDAY => [ 10 ] );
is("$b",'[19970110Z..19970111Z)',
    "rrule() interprets BYYEARDAY with positive numbers correctly");

# this means "repeat on the day that's 10 days before the end of the year"
$b = $a->rrule( BYYEARDAY => [ -10 ] );
is("$b",'[19971221Z..19971222Z)',
    "rrule() interprets BYYEARDAY with negative numbers correctly");

# this means "repeat on the 10th day of the month"
$b = $a->rrule( BYMONTHDAY => [ 10 ] );
is("$b",'[19970110Z..19970111Z),[19970210Z..19970211Z),[19970310Z..19970311Z),[19970410Z..19970411Z),[19970510Z..19970511Z),[19970610Z..19970611Z),[19970710Z..19970711Z),[19970810Z..19970811Z),[19970910Z..19970911Z),[19971010Z..19971011Z),[19971110Z..19971111Z),[19971210Z..19971211Z)',
    'rrule() interprets BYMONTHDAY with positive numbers correctly');

# this means "repeat on the 10th day before the end of every month"
$b = $a->rrule( BYMONTHDAY => [ -10 ] );
is("$b",'[19970121Z..19970122Z),[19970218Z..19970219Z),[19970321Z..19970322Z),[19970420Z..19970421Z),[19970521Z..19970522Z),[19970620Z..19970621Z),[19970721Z..19970722Z),[19970821Z..19970822Z),[19970920Z..19970921Z),[19971021Z..19971022Z),[19971120Z..19971121Z),[19971221Z..19971222Z)',
    'rrule() interprets BYMONTHDAY with negative numbers correctly');

# all wednesdays
$b = $a->rrule( UNTIL => '19970201Z', BYDAY => [ qw(WE) ] );
is("$b",'[19970101T000000Z..19970102Z),[19970108Z..19970109Z),[19970115Z..19970116Z),[19970122Z..19970123Z),[19970129Z..19970130Z)',
    'rrule() with BYDAY and UNTIL works correctly');
    
# last wednesday of month
$b = $a->rrule( FREQ => 'MONTHLY', UNTIL => '19970301Z', BYDAY => [ qw(-1WE) ] );
is("$b",'[19970129Z..19970130Z),[19970226Z..19970227Z)', 
    'rrule() with BYDAY and UNTIL works on "last Wednesday of month" syntax (-1WE)');

# last wednesday of year
$b = $a->rrule( FREQ => 'YEARLY', UNTIL => '19980101Z', BYDAY => [ qw(-1WE) ] );
is("$b",'[19971231Z..19980101Z)',
    'rrule() with BYDAY and UNTIL works on "last Wednesday of year" syntax');

$b = $a->rrule( UNTIL => '19970103Z', BYHOUR => [ 10 ] );
is("$b",'[19970101T100000Z..19970101T110000Z),[19970102T100000Z..19970102T110000Z)',
    'rrule() with UNTIL and BYHOUR ("10-11am every day") works');
    
# this is not in the RFC
# $b = $a->rrule( UNTIL => '19970103Z', BYHOUR => [ -10 ] );

$b = $a->rrule( UNTIL => '19970101T030000Z', BYMINUTE => [ 10 ] );
is("$b",'[19970101T001000Z..19970101T001100Z),[19970101T011000Z..19970101T011100Z),[19970101T021000Z..19970101T021100Z)',
    'rrule() with UNTIL and BYMINUTE ("10 minutes after the start of the hour") works');
    
# this is not in the RFC
# $b = $a->rrule( UNTIL => '19970101T030000Z', BYMINUTE => [ -10 ] );

$b = $a->rrule( UNTIL => '19970101T000300Z', BYSECOND => [ 10 ] );
is("$b",'[19970101T000010Z..19970101T000011Z),[19970101T000110Z..19970101T000111Z),[19970101T000210Z..19970101T000211Z)',
    'rrule() works with UNTIL and BYSECOND ("the 10th second of every minute")');
    
# this is not in the RFC
# $b = $a->rrule( UNTIL => '19970101T000300Z', BYSECOND => [ -10 ] );

# BYSETPOS, FREQ, INTERVAL, COUNT

# occurrences

1;
