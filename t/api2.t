#!/bin/perl -w
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Date::Set new API:
# event
#

use strict;
# use warnings;
use Test::More qw(no_plan);
use Carp;

BEGIN { use_ok('Date::Set') };

use Date::Set qw($inf);
my ($title, $a, $a2, $b, $period, $RFC);

# $Date::Set::DEBUG = 1;

# carp " INF is $inf ";
$title = "event() constructor returns 'forever'";
    $a = Date::Set->event();
    is("$a",     "(-$inf..$inf)", $title);

$title = "event-at constructor";
    $a = Date::Set->event( 
        at    => '19970902T090000Z' );
    is("$a",     '19970902T090000Z', $title);



$title = "event-at constructor, array, meaning interval";
    $a = Date::Set->event( 
        at    => [ '19970902T090000Z','19970903T090000Z' ] );
    is("$a",       '[19970902T090000Z..19970903T090000Z]', $title);

$title = "event-at constructor, array, meaning events";
    $a = Date::Set->event( 
        at    => [ ['19970902T090000Z'],['19970903T090000Z'] ] );
    is("$a",       '19970902T090000Z,19970903T090000Z', $title);

$title = "event at";
    $a->event( 
        at    => [ '19950101Z' ] );
    is("$a",       '19950101Z,19970902T090000Z,19970903T090000Z', $title);



$title = "event-start constructor";
    $a = Date::Set->event( 
        start    => '19950101Z' );
    is("$a",       "[19950101Z..$inf)", $title);



$title = "event-end constructor";
    $a = Date::Set->event( 
        end    => '19950101Z' );
    is("$a",       "(-$inf..19950101Z]", $title);

$title = "event-start-end constructor";
    $a = Date::Set->event( 
        start    => '19950101Z', 
        end      => '19970902T090000Z' );
    is("$a",       '[19950101Z..19970902T090000Z]', $title);



# NOTE: this test fails if used with Set::Infinite < 0.36
$title = "event-rule constructor, unbounded";
    $a = Date::Set->event( 
        rule    => 'FREQ=DAILY;COUNT=10' );
    is("$a",       'Too complex', $title);
$title = "event-rule constructor, gets bounded";
    $b = Date::Set->event( start => '19950101Z', end => '19990101Z' );
    $b = $b->intersection($a);
    is("$b",       '19950101Z,19950102Z,19950103Z,19950104Z,19950105Z,' .
                   '19950106Z,19950107Z,19950108Z,19950109Z,19950110Z', $title);


# rule and start/end unions;

$title = "event-start union";
    $a = Date::Set->event( start => '19950101Z', end => '19990101Z' );
    $a->event( 
        start    => '19960101Z' );
    is("$a",       '[19960101Z..19990101Z]', $title);

$title = "event-end union";
    $a = Date::Set->event( start => '19950101Z', end => '19990101Z' );
    $a->event( 
        end    => '19980101Z' );  
    is("$a",       '[19950101Z..19980101Z]', $title);



$title = "event-start-end union";
    $a = Date::Set->event( start => '19950101Z', end => '19990101Z' );
    $a->event( 
        start    => '19960101Z', 
        end      => '19980902T090000Z' );
    is("$a",       '[19960101Z..19980902T090000Z]', $title);
    is( $a->is_too_complex, '0', 'is_too_complex 0');


# $Set::Infinite::DEBUG_BT = 1;
# $Date::Set::DEBUG = 1;
$title = "event-rule union";
    $a = Date::Set->event( start => '19950101Z', end => '19990101Z' );
    $a->event( 
        rule    => 'FREQ=YEARLY;COUNT=10' );
    is("$a",       '19950101Z,19960101Z,19970101Z,19980101Z,19990101Z', $title);
    # is( $a->is_too_complex, '1', 'is_too_complex 1');

# $Set::Infinite::DEBUG_BT = 1;
# $Date::Set::DEBUG = 1;
$title = "event-rule union, gets bounded";
    $b = Date::Set->event( start => '19930101Z', end => '20020101Z' );
    $b = $b->intersection($a);
    is("$b",       '19950101Z,19960101Z,19970101Z,19980101Z,19990101Z',
                   $title);
$Set::Infinite::DEBUG_BT = 0;
$Date::Set::DEBUG = 0;



$title = "event-rule start, bounded by UNTIL";
    $a = Date::Set->event( 
        rule    => 'FREQ=YEARLY;UNTIL=19970101Z',
        start => '19950101Z' );
    is("$a",       '19950101Z,19960101Z,19970101Z', $title);

# start + end + at, start + at, end + at

$title = "event start + end + at; at with interval";
    $b = Date::Set->event( 
        start => '19940101Z', end => '20000201Z', 
        at => [ '19930101Z','19940101Z',['19950101Z','19990101Z'],['20000101Z'],['20010101Z'] ] );
    is("$b",       '19940101Z,[19950101Z..19990101Z],20000101Z',
                   $title);



$title = "event start + at";
    $b = Date::Set->event( 
        start => '19940101Z',
        at => [ '19930101Z','19940101Z',['19950101Z','19990101Z'],['20000101Z'],['20010101Z'] ] );
    is("$b",       '19940101Z,[19950101Z..19990101Z],20000101Z,20010101Z',
                   $title);

$title = "event end + at";
    $b = Date::Set->event( 
        end => '20000201Z', 
        at => [ ['19930101Z'],['19940101Z'],['19950101Z','19990101Z'],['20000101Z'],['20010101Z'] ] );
    is("$b",       '19930101Z,19940101Z,[19950101Z..19990101Z],20000101Z',
                   $title);



# rule + start, rule + end, rule + at

# $Set::Infinite::DEBUG_BT = 1;
# $Date::Set::DEBUG = 1;
$title = "event rule + start, without dtstart";
    $a = Date::Set->event( 
        start => '19970902T090000Z',
        rule  => 'FREQ=DAILY;COUNT=10' );
    $b = Date::Set->event( end => '19990101Z' );
    is("$b", "(-$inf..19990101Z]", 'event end');
    $b = $a->intersection( $b );
    is("$b", 
        '19970902T090000Z,19970903Z,19970904Z,19970905Z,' .
        '19970906Z,19970907Z,19970908Z,19970909Z,' .
        '19970910Z,19970911Z', $title);

$title = "event rule + dtstart";
    $a = Date::Set->dtstart( start => '19970902T090000Z')->
        event( rule  => 'FREQ=DAILY;COUNT=10' );
    $b = Date::Set->event( end => '19990101Z' );
    is("$b", "(-$inf..19990101Z]", 'event end');
    $b = $a->intersection( $b );
    is("$b", 
        '19970902T090000Z,19970903T090000Z,19970904T090000Z,19970905T090000Z,' .
        '19970906T090000Z,19970907T090000Z,19970908T090000Z,19970909T090000Z,' .
        '19970910T090000Z,19970911T090000Z', $title);
$Set::Infinite::DEBUG_BT = 0;
$Date::Set::DEBUG = 0;

$title = "event rule + end";
    $a = Date::Set->event( 
        end => '19990101Z',
        rule  => 'FREQ=DAILY;COUNT=10' );
    $b = Date::Set->event( start => '19970902T090000Z' );
    is("$b", "[19970902T090000Z..$inf)", 'event start');
    $b = $a->intersection( $b );
    is("$b", 
        '19970902T090000Z,19970903Z,19970904Z,19970905Z,' .
        '19970906Z,19970907Z,19970908Z,19970909Z,' .
        '19970910Z,19970911Z', $title);


$title = "event rule + start + end";
    $a = Date::Set->event( 
        start => '19970903Z',
        end => '19990101Z',
        rule  => 'FREQ=DAILY;COUNT=10' );
    is("$a", 
        '19970903Z,19970904Z,19970905Z,' .
        '19970906Z,19970907Z,19970908Z,19970909Z,' .
        '19970910Z,19970911Z,19970912Z', $title);


$title = "event rule + at";
    $a = Date::Set->event( 
        at => [['19970902T090000Z','19990101Z']],
        rule  => 'FREQ=DAILY;COUNT=10' );
    is("$a", 
        '19970902T090000Z,19970903Z,19970904Z,19970905Z,' .
        '19970906Z,19970907Z,19970908Z,19970909Z,' .
        '19970910Z,19970911Z', $title);


# event rule + start + at

$title="event-rule-start-at Daily for 10 occurrences";
#
#     DTSTART;TZID=US-Eastern:19970902T090000
#     recur_by_rule:FREQ=DAILY;COUNT=10
#
#     ==> (1997 9:00 AM EDT)September 2-11
#
    # make a period from 1995 until 1999
    $period = Date::Set->event( start => '19950101Z', end => '19990101Z' );
    $a = Date::Set->event( 
        # start => '19970902T090000Z',
        rule  => 'DTSTART=19970902T090000Z;FREQ=DAILY;COUNT=10',
        at    => $period );
    is("$a", 
        '19970902T090000Z,19970903T090000Z,19970904T090000Z,19970905T090000Z,' .
        '19970906T090000Z,19970907T090000Z,19970908T090000Z,19970909T090000Z,' .
        '19970910T090000Z,19970911T090000Z', $title);
$Date::Set::DEBUG = 0;

$title="event-rule-start-at Daily for 10 occurrences, start < subset";
    $period = Date::Set->event( start => '19970903T100000Z', end => '19990101Z' );
    $a = Date::Set->event( 
        # start => '19970902T090000Z',
        rule  => 'DTSTART=19970902T090000Z;FREQ=DAILY;COUNT=10',
        at    => $period );
    is("$a", 
        '19970904T090000Z,19970905T090000Z,' .
        '19970906T090000Z,19970907T090000Z,19970908T090000Z,19970909T090000Z,' .
        '19970910T090000Z,19970911T090000Z', $title);

$Date::Set::DEBUG = 0;


# during

$title = "during-at";
    $a = Date::Set->event( at    => [[ '19950101Z', '19990101Z' ]] );
    $a->during( at   => [[ '19970101Z', '20000101Z' ]] );
    is("$a",       '[19970101Z..19990101Z]', $title);

$title = "during-rule-at";
    $a->during( rule  => 'FREQ=YEARLY', at => $a );
    is("$a",       '19970101Z,19980101Z,19990101Z', $title);

# during rule

$title = "during rule";
    $a->event( at    => [[ '19950101Z', '19970101Z' ]] );
    $a->during( rule  => 'FREQ=YEARLY' );
    is("$a",       '19950101Z,19960101Z,19970101Z,19980101Z,19990101Z', $title);

# exclude

$title = "exclude-at";
    $a->event( at    => [[ '19950101Z', '19990101Z' ]] );
    # print " event-at => $a \n";
    $a->exclude( at  => [[ '19970101Z', '20000101Z' ]] );
    is("$a",       '[19950101Z..19970101Z)', $title);



$title = "exclude-rule-at";
# NOTE: 19950101Z is excluded because it is NOT the 'DTSTART' value
    # print " a = $a\n";
    my $tmp = $a->copy;
    $a->exclude( rule  => 'FREQ=YEARLY', at => $a );
    is("$a",       '(19950101Z..19960101Z),(19960101Z..19970101Z)', $title);
    
    # get old value back and set DTSTART
    $a = $tmp->copy->dtstart(start => '19950101Z');
    # print " $a starts in ",$a->{dtstart}," \n";

$title = "exclude-rule-at with DTSTART";
# NOTE: now 19950101Z is NOT excluded because it is the 'DTSTART' value
    $a->exclude( rule  => 'FREQ=YEARLY', at => $a );
    is("$a",       '[19950101Z..19960101Z),(19960101Z..19970101Z)', $title);


# exclude rule

$title = "exclude rule";
# $Set::Infinite::TRACE = 1;
# $Set::Infinite::PRETTY_PRINT = 1;
    $a->event( at    => [[ '19950101Z', '19970101Z' ]] );
# warn "$a";
# $Set::Infinite::TRACE = 1;
# $Set::Infinite::PRETTY_PRINT = 1;
    $a->exclude( rule  => 'FREQ=YEARLY' );
    is("$a",       '[19950101Z..19960101Z),(19960101Z..19970101Z)', $title);
$Set::Infinite::TRACE = 0;
$Set::Infinite::PRETTY_PRINT = 0;

# wkst

$title = "wkst read";
    $a = Date::Set::wkst();
    is("$a", "MO", $title);
$title = "wkst set";
    $a = Date::Set::wkst('SU');
    is("$a", "SU", $title);
$title = "wkst read";
    $a = Date::Set::wkst();
    is("$a", "SU", $title);

$title="***  changing only WKST from MO to SU, yields different results...  ***";
#
#     DTSTART;TZID=US-Eastern:19970805T090000
#     recur_by_rule:FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=SU
#     ==> (1997 EDT)August 5,17,19,31
#
	# make a period from 1995 until 1999
	$period = Date::Set->period( time => ['19950101Z', '19990101Z'] );
	$a = Date::Set->event->dtstart( start => '19970805T090000Z' )
		->recur_by_rule( FREQ=>'WEEKLY', INTERVAL=>2, COUNT=>4, BYDAY=>[ qw(TU SU) ] )
		->occurrences( period => $period );
	is("$a", 
		'19970805T090000Z,19970817T090000Z,19970819T090000Z,19970831T090000Z', $title);

    Date::Set::wkst('MO');

1;
