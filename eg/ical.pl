#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

use strict;
use warnings;
use Date::Set;

# ----- SAMPLE DATA ------

my $a = '20010923Z';
my $b = '20011106T235959Z';  
my $c = '20010101T100000Z';

#-------------------------

my ($event, $vperiod);
$vperiod = Date::Set::period( time=>[$a,$b] );
print "period: $vperiod\n";

# ---- direct syntax ----

my $occurrences = $vperiod->
	rrule( FREQ=>'WEEKLY', COUNT=>2, 
		BYMONTH => [9,10],
		# BYWEEKNO => [40,41],
		# BYYEARDAY => [-65],
		BYMONTHDAY => [20,21,22,23],
		# BYDAY => [qw(SU TU TH)],
		# BYHOUR => [10,13],
		BYSETPOS => [0, -1],
	);
print "occurrences: $occurrences \n";

# ---- functional syntax ----

$event = Date::Set::rrule( FREQ=>'WEEKLY', COUNT=>2, 
		BYMONTH => [9,10],
	);
print "occurrences: ", $event->occurrences( period => $vperiod)," \n";

1;
