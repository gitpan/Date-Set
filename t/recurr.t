#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Date::Set
#

use strict;
use warnings;
use Date::Set;

my $error = 0;
my ($a, $b);
my $events;
my $test = 0;
my ($result, $errors);

print "1..17\n";

sub test {
	my ($header, $sub, $expected) = @_;
	$test++;
	#print "\t# $header \n";
	$result = eval $sub;
	if ("$expected" eq "$result") {
		print "ok $test";
	}
	else {
		print "not ok $test"; # \n\t# expected \"$expected\" got \"$result\"";
		print "\n\t# $sub expected \"$expected\" got \"$result\"";
		$errors++;
	}
	print " \n";
}

# $Date::Set::DEBUG = 1;
# $Set::Infinite::TRACE = 1;

# new
$a = Date::Set->new('19971024T120000Z', '19971024T130000Z');
test('','$a','[19971024T120000Z..19971024T130000Z]');
# period
$a = Date::Set->period( time => ['19971024T120000Z', '19971024T130000Z'] );
test('','$a','[19971024T120000Z..19971024T130000Z]');
# dtstart - after
$b = $a->dtstart( start => '19971024T123000Z' );
test('','$b','[19971024T123000Z..19971024T130000Z]');
# dtstart - before
$b = $a->dtstart( start => '19971024T113000Z' );
test('','$b','[19971024T120000Z..19971024T130000Z]');
# duration( unit => months, duration => 10 )
$b = $a->duration( unit => 'days', duration => 5 );
test('','$b','[19971024T120000Z..19971029T120000Z]');

# rrule
$a = Date::Set->period( time => ['19970101T000000Z', '19971231T235959Z'] );

$b = $a->rrule( BYMONTH => [ 10 ] );
test('','$b','[19971001Z..19971101Z)');
# TODO
# $b = $a->rrule( BYMONTH => [ -10 ] );
# test('','$b','[19970201Z..19970301Z)');

# TODO
# $b = $a->rrule( BYWEEKNO => [ 10 ] );
# test('','$b','[19970110Z..19970111Z)');
# $b = $a->rrule( BYWEEKNO => [ -10 ] );
# test('','$b','[19970121Z..19970122Z)');

$b = $a->rrule( BYYEARDAY => [ 10 ] );
test('','$b','[19970110Z..19970111Z)');
$b = $a->rrule( BYYEARDAY => [ -10 ] );
test('','$b','[19971221Z..19971222Z)');

$b = $a->rrule( BYMONTHDAY => [ 10 ] );
test('','$b','[19970110Z..19970111Z),[19970210Z..19970211Z),[19970310Z..19970311Z),[19970410Z..19970411Z),[19970510Z..19970511Z),[19970610Z..19970611Z),[19970710Z..19970711Z),[19970810Z..19970811Z),[19970910Z..19970911Z),[19971010Z..19971011Z),[19971110Z..19971111Z),[19971210Z..19971211Z)');
$b = $a->rrule( BYMONTHDAY => [ -10 ] );
test('','$b','[19970121Z..19970122Z),[19970218Z..19970219Z),[19970321Z..19970322Z),[19970420Z..19970421Z),[19970521Z..19970522Z),[19970620Z..19970621Z),[19970721Z..19970722Z),[19970821Z..19970822Z),[19970920Z..19970921Z),[19971021Z..19971022Z),[19971120Z..19971121Z),[19971221Z..19971222Z)');

$b = $a->rrule( UNTIL => '19970201Z', BYDAY => [ qw(WE) ] );
test('','$b','[19970101T000000Z..19970102Z),[19970108Z..19970109Z),[19970115Z..19970116Z),[19970122Z..19970123Z),[19970129Z..19970130Z)');
# TODO
# $b = $a->rrule( UNTIL => '19970201Z', BYDAY => [ qw(-WE) ] );
# test('','$b','[19971221Z..19971222Z)');

$b = $a->rrule( UNTIL => '19970103Z', BYHOUR => [ 10 ] );
test('','$b','[19970101T100000Z..19970101T110000Z),[19970102T100000Z..19970102T110000Z)');
$b = $a->rrule( UNTIL => '19970103Z', BYHOUR => [ -10 ] );
test('','$b','[19970101T140000Z..19970101T150000Z),[19970102T140000Z..19970102T150000Z)');

$b = $a->rrule( UNTIL => '19970101T030000Z', BYMINUTE => [ 10 ] );
test('','$b','[19970101T001000Z..19970101T001100Z),[19970101T011000Z..19970101T011100Z),[19970101T021000Z..19970101T021100Z)');
$b = $a->rrule( UNTIL => '19970101T030000Z', BYMINUTE => [ -10 ] );
test('','$b','[19970101T005000Z..19970101T005100Z),[19970101T015000Z..19970101T015100Z),[19970101T025000Z..19970101T025100Z)');

$b = $a->rrule( UNTIL => '19970101T000300Z', BYSECOND => [ 10 ] );
test('','$b','[19970101T000010Z..19970101T000011Z),[19970101T000110Z..19970101T000111Z),[19970101T000210Z..19970101T000211Z)');
$b = $a->rrule( UNTIL => '19970101T000300Z', BYSECOND => [ -10 ] );
test('','$b','[19970101T000050Z..19970101T000051Z),[19970101T000150Z..19970101T000151Z),[19970101T000250Z..19970101T000251Z)');

# FREQ, INTERVAL, COUNT

# occurrences

1;
