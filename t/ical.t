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
my $a;
my $events;
my $test = 0;
my ($result, $errors);

print "1..7\n";

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


$a = Date::Set->new('19971024T120000Z', '19971024T130000Z');

test('','$a','[19971024T120000Z..19971024T130000Z]');

test('','$a->size','3600');

test('','$a->union(\'19971024T160000Z\', \'19971024T170000Z\')','[19971024T120000Z..19971024T130000Z],[19971024T160000Z..19971024T170000Z]');

test('','$a->complement','(-inf..19971024T120000Z),(19971024T130000Z..inf)');

test('','$a->complement("19971024T122000Z","19971024T124000Z")','[19971024T120000Z..19971024T122000Z),(19971024T124000Z..19971024T130000Z]');

test ('', ' join (" ", $a->quantize(unit=>"weeks")->compact ) ',
	"[19971019Z..19971026Z)");


# "This event happens from 13:00 to 14:00 every Tuesday, unless that Tuesday is the 15th of the month."

my $interval = Set::Infinite->new('20010501Z')->quantize(unit=>'months');
# print "Weeks: ", $interval->quantize(unit=>'weeks'), "\n";
my $tuesdays = $interval->quantize(unit=>'weeks')->
	offset( mode => 'begin', unit=>'days', value => [ 2 , 3 ] );
# print "tuesdays: ", $tuesdays, "\n";
my $fifteenth = $interval->quantize(unit=>'months')->
	offset( mode => 'begin', unit=>'days', value => [ 14 , 15 ] );
# print "fifteenth: ", $fifteenth, "\n";
$events =  $tuesdays -> complement ( $fifteenth ) ->
	offset( mode => 'begin', unit=>'hours', value => [ 13 , 14 ] );
# print "events in may 2001: ", $events;
test (  "offset: ", ' $events ',
	"[20010501T130000Z..20010501T140000Z),[20010508T130000Z..20010508T140000Z),[20010522T130000Z..20010522T140000Z),[20010529T130000Z..20010529T140000Z)");


LAST: 
1;
