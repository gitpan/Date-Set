#!/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

require Exporter;
use strict;

package Date::Set;

use Set::Infinite ':all'; 
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION $DEBUG
    $future $past $forever $never
    %freq %weekday
);
use Carp;
@ISA = qw(Set::Infinite);
@EXPORT = qw();
@EXPORT_OK = qw(type);
$VERSION = (qw'$Revision: 1.05 $')[1];

=head1 NAME

Date::Set - Date set math

=head1 SYNOPSIS

	use Date::Set;

	my $interval = Date::Set->new('20010501')->quantize(unit=>'months');
	# print "This month: ", $interval, "\n\n";
	# print "Weeks this month: ", $interval->quantize(unit=>'weeks'), "\n\n";
	# print "Tuesdays this month: ", $interval->quantize(unit=>'weeks')->
	    offset( mode => 'begin', unit=>'days', value => [ 2, 3] );

    # TODO: add some examples of RRULE syntax.
    #
     
=head1 DESCRIPTION

Date::Set is a module for date/time sets. It allows you to generate
groups of dates, like "every Wednesday", and then find all the dates
matching that pattern. It waits until you ask for a particular
recurrence before calculating it.

If you want to understand the context of this module, look at
IETF RFC 2445 (iCalendar), which specifies a particular syntax for
describing recurring events. 

It requires Date::ICal and Set::Infinite. 
If you don't need iCalendar functionality, use Set::Infinite instead.

=head1 METHODS

=cut

$DEBUG = 0;
$Set::Infinite::TRACE = 0;
Set::Infinite::type('Date::Set::ICal');


$future  = &inf; 
$past    = -&inf;   
$forever = __PACKAGE__->new($past, $future);
$never   = __PACKAGE__->new();

=head2 event

	event()

Constructor. Returns 'forever', that is: (-Inf .. Inf). If you use this method,
*must* limit the event by calling dtstart() to set a starting date for the
event. 

=cut

sub event   { $forever }

sub print {
	my ($self, %parm) = @_;
	 print "\n $parm{title} = ",$self,"\n" if $DEBUG;
	return $self;
}


=head2 period

	period( time => [time1, time2] )

Another constructor. Returns "[time1 .. time2]" when
called in a scalar context.

=cut

sub period { # time[]
	my ($class, %parm) = @_;
	my $self;
	$self = $class->new($parm{time}[0], $parm{time}[1]);
	$self->print(title=>'period ' . join(':', %parm) );
	return $self;
}


=head2 dtstart

	dtstart( start => time1 )

Returns set intersection [time1 .. Inf)

'dtstart' puts a limit on when the event starts. 
If the event already starts AFTER dtstart, it will not change.

=cut


sub dtstart { # start
	my ($self, %parm) = @_;
	$self->print(title=>'dtstart ' . join(':', %parm) );
	return $self->intersection($parm{start}, $future);
	# my $tmp = __PACKAGE__->new($parm{start}, $future);
	# return $self->intersection($tmp);
}

=head2 duration

	duration( unit => months, duration => 10 )

All intervals for the quantize function are modified to 'duration'.

'unit' parameter can be years, months, days, weeks, hours, minutes, or seconds.

=cut

sub duration { # unit,duration
	my ($self, %parm) = @_;
	$self->print(title=>'duration');
	return $self->offset(mode=>'begin', unit=>$parm{unit}, value=>[0, $parm{duration}]);
}

%freq = qw(SECONDLY seconds MINUTELY minutes HOURLY hours DAILY days WEEKLY weeks MONTHLY months YEARLY years);
%weekday = qw( SU 0 MO 1 TU 2 WE 3 TH 4 FR 5 SA 6 );

=head2 rrule

    rrule ( BYMONTH => [ list ], BYWEEKNO => [ list ],
        BYYEARDAY => [ list ],   BYMONTHDAY => [ list ],
        BYDAY => [ list ],       BYHOUR => [ list ],
        BYMINUTE => [ list ],    BYSECOND => [ list ],
        BYSETPOS => [ list ],
        UNTIL => time, FREQ => freq, INTERVAL => n, COUNT => n,
		WKST => day )

Implements RRULE from RFC2445. 

FREQ can be: SECONDLY MINUTELY HOURLY DAILY WEEKLY MONTHLY or YEARLY

WKST and BYDAY list may contain: SU MO TU WE TH FR SA

BYxxx items must be array references (must be bracketed): BYMONTH => [ 10 ] or
BYMONTH => [ 10, 11, 12 ] or BYMONTH => [ qw(10 11 12) ]

(some documentation needed!)

=cut

sub rrule { # freq, &method(); optional: interval, until, count
	# TODO: count, interval
	my $self = shift;
	unless (ref($self)) {
		# print " new: $self ";
		unshift @_, $self;
		$self = $forever;
	}
	my $class = ref($self);

	if (($self->{too_complex}) or ($self->min == -&inf) or ($self->max == &inf)) {
		my $b = $class->new();
		$self->trace(title=>"rrule:backtrack"); 
		# print " [rrule:backtrack] \n" if $DEBUG_BT;
		$b->{too_complex} = 1;
		$b->{parent} = $self;
		$b->{method} = 'rrule';
		$b->{param}  = \@_;
		return $b;
	}

	# print "   ", join(" ; ", @_ ), "  ";
	my %parm = @_;
	my $rrule;
	my $when = $self;

	$parm{FREQ} = $parm{FREQ} . '';
	$parm{INTERVAL} = $parm{INTERVAL} . '';
	$parm{COUNT} = $parm{COUNT} . '';
	$parm{UNTIL} = $parm{UNTIL} . '';
	$parm{WKST} = $parm{WKST} . '';
	$parm{WKST} = "MO" unless $parm{WKST};

	$when->print(title=>'WHEN');

	if ($parm{UNTIL} ne '') {
		my $until = $when;
		$when = $until->intersection($past, $parm{UNTIL});
		$when->print(title=>'UNTIL');
	}

	# BYMONTH, BYWEEKNO, BYYEARDAY, BYMONTHDAY, BYDAY, BYHOUR,
	# BYMINUTE, BYSECOND and BYSETPOS; then COUNT and UNTIL are evaluated

	if (exists $parm{BYMONTH}) {
		my $bymonth = $when;
		my @by = (); foreach ( @{$parm{BYMONTH}} ) { push @by, $_-1, $_; }
		$when = $bymonth->intersection(
			$bymonth->quantize(unit=>'years', strict=>0)
			->offset(mode=>'circle', unit=>'months', value=>[@by], strict=>0 )
			->print (title=>'months2 ' . join(',' , @by) )
		)->no_cleanup; 
		$when->print(title=>'BYMONTH');
	}

	if (exists $parm{BYWEEKNO}) {
		my $byweekno = $when;
		my @by = (); foreach ( @{$parm{BYWEEKNO}} ) { push @by, $_-1, $_; }
		my $wkst = $weekday{$parm{WKST}};
		# print " PARM:WKST:$wkst = $parm{WKST} \n";
		$when = $byweekno->intersection(
			$byweekno->quantize(unit=>'weekyears', wkst=>$wkst, strict=>0)
			->offset(mode=>'circle', unit=>'weeks', value=>[@by], strict=>0 )
			->print (title=>'weeks2 ' . join(',' , @by) )
		)->no_cleanup; 
		$when->print(title=>'BYWEEKNO');
	}

	if (exists $parm{BYYEARDAY}) {
		my $byyearday = $when;
		my @by = (); foreach ( @{$parm{BYYEARDAY}} ) { push @by, $_-1, $_; }
		$when = $byyearday->intersection(
			$byyearday->quantize(unit=>'years', strict=>0)
			->offset(mode=>'circle', unit=>'days', value=>[@by], strict=>0 )
		)->no_cleanup; 
		$when->print(title=>'BYYEARDAY');
	}

	if (exists $parm{BYMONTHDAY}) {
		my $BYMONTHDAY = $when;    # __PACKAGE__->new($when);
		my @by = (); foreach ( @{$parm{BYMONTHDAY}} ) { push @by, $_-1, $_; }
		$when = $BYMONTHDAY->intersection(
			$BYMONTHDAY->quantize(unit=>'months', strict=>0)
			# ->print (title=>'months')
			->offset(mode=>'circle', unit=>'days', value=>[@by], strict=>0 )
			# ->print (title=>'days')
		)->no_cleanup; 
		$when->print(title=>'BYMONTHDAY');
	}

	if (exists $parm{BYDAY}) {
		my $BYDAY = $when;
		#   Each BYDAY value can also be preceded by a positive (+n) or negative
		#   (-n) integer. If present, this indicates the nth occurrence of the
		#   specific day within the MONTHLY or YEARLY RRULE.

		# classify BYDAY parameters between indexed and non-indexed
		my (@byday, @indexed_byday);
		foreach (@{$parm{BYDAY}}) {
			if (/\d/) { push @indexed_byday, $_ } else { push @byday, $_ };
		}

		my $non_indexed = $never;
		my $indexed = $never;

		if ($#byday >= 0) {
			# non-indexed BYDAY
			my @by = (); foreach ( map { $weekday{$_} } @{$parm{BYDAY}} ) { push @by, $_, $_+1; }
			$non_indexed = $BYDAY->intersection(
				$BYDAY->quantize(unit=>'weeks', strict=>0)
				# ->print (title=>'weeks')
				->offset(mode=>'circle', unit=>'days', value=>[@by], strict=>0 )
				# ->print (title=>'days')
			)->no_cleanup; 
			$non_indexed->print(title=>'BYDAY');
		}
		if ($#indexed_byday >= 0) {
			# indexed BYDAY
			# print " [Indexed BYDAY (" . $indexed_byday[0] . ") ]\n";

			# look at FREQ and create $base 
			my $base;
			if ($parm{FREQ} eq 'YEARLY') {
				$base = $BYDAY->quantize(unit => 'years', strict=>0);
			}
			else {
				# MONTHLY
				$base = $BYDAY->quantize(unit => 'months', strict=>0);
			}

			my @index = ();
			my @by = (); 
			# iterate through parameters
			foreach (@indexed_byday) {
				# parse parameters
				my ($index, $day) = /([\-\+]\d+)(\w+)/;
				$day = $weekday{$day};

				# TODO: get indexed days to $indexed set
				# quantize weeks -> offset -> intersection -> select

				# print " [Indexed BYDAY: $index $day, base $base ]\n";

				# find out week day
				my $weekday = $BYDAY->quantize(unit=>'weeks', strict=>0)
						->print(title=>'weeks')
						->offset(mode=>'begin', unit=>'days', value=>[ $day, $day + 1 ], strict=>0 );
				$weekday->print(title=>'DAYS:');

				# iterate through $base (months or years) finding out week day index
				$indexed = $indexed->union(
					$base->iterate( 
						sub { $_[0]
							->print(title=>'month') 
							->intersection($weekday)
							->print(title=>'month-weekday') 
							->select( by => [ $index ] )
							->print(title=>'selected') 
						} 
					)
				);

				$indexed->print(title=>'BYDAY-INDEX:'. $index .','. $day);

			}
		}

		# mix indexed with non-indexed days
		$when = $non_indexed->union($indexed);
		$when->print(title=>'BYDAY');

	} # end: BYDAY

	if (exists $parm{BYHOUR}) {
		my $BYHOUR = $when;
		my @by = (); foreach ( @{$parm{BYHOUR}} ) { push @by, $_, $_+1; }
		$when = $BYHOUR->intersection(
			$BYHOUR->quantize(unit=>'days')
			->offset(mode=>'circle', unit=>'hours', value=>[@by], strict=>0 )
			# ->print (title=>'hours')
		)->no_cleanup; 
		$when->print(title=>'BYHOUR');
	}
 
	if (exists $parm{BYMINUTE}) {
		my $BYMINUTE = $when;
		my @by = (); foreach ( @{$parm{BYMINUTE}} ) { push @by, $_, $_+1; }
		$when = $BYMINUTE->intersection(
			$BYMINUTE->quantize(unit=>'hours')
			->offset(mode=>'circle', unit=>'minutes', value=>[@by], strict=>0 )
			# ->print (title=>'minutes')
		)->no_cleanup; 
		$when->print(title=>'BYMINUTE');
	}

	if (exists $parm{BYSECOND}) {
		my $BYSECOND = $when;
		my @by = (); foreach ( @{$parm{BYSECOND}} ) { push @by, $_, $_+1; }
		$when = $BYSECOND->intersection(
			$BYSECOND->quantize(unit=>'minutes')
			->offset(mode=>'circle', unit=>'seconds', value=>[@by], strict=>0 )
			# ->print (title=>'seconds')
		)->no_cleanup; 
		$when->print(title=>'BYSECOND');
	}

	if (exists $parm{BYSETPOS}) {
		my $BYSETPOS = $when;
		my @by = @{$parm{BYSETPOS}};
		$when = $BYSETPOS->intersection(
			$BYSETPOS->compact
			# ->print (title=>'bysetpos1')
			->select( by=> [@by] )
			# ->print (title=>'bysetpos2')
		)->no_cleanup; 
		$when->print(title=>'BYSETPOS');
	}


	# print " PARAMETERS: ", join(":", %parm), "\n";

	# UNTIL and COUNT MUST NOT occur in the same 'recur'
	if ($parm{UNTIL} ne '') {
		# UNTIL
		$when->print(title=>'UNTIL');
		$rrule = $when->intersection($past, $parm{UNTIL});
	}
	elsif ($parm{FREQ} ne '') {
		# COUNT
		$when->print(title=>'FREQ');
		$rrule = $when->intersection(
			$when->quantize(unit=>$freq{$parm{FREQ}}, strict=>0)
			->select(freq=>$parm{INTERVAL}, count=>$parm{COUNT}, strict=>0) )
	}
	else {
		$when->print(title=>'no FREQ or UNTIL');
		$rrule = $when;
	}

	return $rrule;
}

=head2 occurrences

	occurrences( period => date-set )

Returns the occurrences for a given period. In other words,
"when does this event occur during the given period?"

=cut

sub occurrences { # event->, period 
	my ($self, %parm) = @_;
	return $self->intersection($parm{period});
}


1;

__END__

=head1 INHERITED METHODS 

These methods are inherited from Set::Infinite.

=head2 Logic 

    $logic = $a->intersects($b);
    $logic = $a->contains($b);
    $logic = $a->is_null;

=head2 Set  

    $i = $a->union($b);     
    $i = $a->intersection($b);
    $i = $a->complement;
Note: 'unit' parameter can be years, months, days, weeks, hours, minutes, or seconds.  

=cut

=head1 BUGS

'rrule' method is not yet fully RFC2445 compliant.

'byday' does not understand (scalar . string) formats yet (like '-2FR')

'duration' and 'period' methods may change in future versions, to generate open-ended sets.

'WEEKLY' does not use 'WKST'

rrule syntax needs uppercase parameters

=head1 AUTHOR

Flavio Soibelmann Glock <fglock@pucrs.br> 
with the Reefknot team.

=cut
