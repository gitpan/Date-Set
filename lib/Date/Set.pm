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
$VERSION = (qw'$Revision: 1.10 $')[1];

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

=head2 dtend

	dtend( end => time1 )

Returns set intersection (Inf .. time1]

'dtend' puts a limit on when the event finishes. 
If the event already finish BEFORE dtend, it will not change.

=cut


sub dtend { # end
	my ($self, %parm) = @_;
	$self->print(title=>'dtend ' . join(':', %parm) );
	return $self->intersection($past, $parm{end});
	# my $tmp = __PACKAGE__->new($parm{start}, $future);
	# return $self->intersection($tmp);
}

=head2 duration

	duration( unit => 'months', duration => 10 )

All intervals are modified to 'duration'.

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

    rrule ( period => date-set,  DTSTART => time,
        BYMONTH => [ list ],     BYWEEKNO => [ list ],
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

There are two operating modes: without 'period' it will filter out the rule from the set;
with 'period' it will filter out the rule from the period, then add the list to the set.

DTSTART value can be given explicitly, otherwise it will be taken from 'period' or from the set.

=cut

sub rrule { 
	my $self = shift;
	my %parm = @_;

	my $rrule;
	my %has;

	# this is the constructor interface
	# it creates an object if we are not given one
	unless (ref($self)) {
		# print " new: $self ";
		# unshift @_, $self;
		$self = (exists $parm{period}) ? $never : $forever;
	}
	my $class = ref($self);

	# this is the backtracking interface. 
	# It allows the program to defer processing if it does not have enough
	# information to proceed.
	if (($self->{too_complex}) or ($self->min == -&inf) or ($self->max == &inf)) {
		my $b = $class->new();
		$self->trace(title=>"rrule:backtrack"); 
		# print " [rrule:backtrack] \n" if $DEBUG_BT;
		$b->{too_complex} = 1;
		$b->{parent} = $self;
		$b->{method} = 'rrule';
		$b->{param}  = [ %parm ];
		return $b;
	}

	# Try to find out what 'period' the rrule is talking about
	$has{period} = 1;
	unless (exists $parm{period}) {
		$parm{period} = $self;
		$has{period} = 0;
	}
	my $when = $parm{period};

	# DTSTART gives the default values for month, day, h, m, s
	$parm{DTSTART} = $parm{period}->min unless exists $parm{DTSTART};
	# print " [DTSTART = $parm{DTSTART} ]\n";
	# my ($has_month, $has_day, $has_hour, $has_minute, $has_second) = (0,0,0,0,0);	

	# define everything we use
        my @list = qw/FREQ INTERVAL COUNT UNTIL WKST/;
        for(@list) {
            next if defined $parm{$_};
            $parm{$_} = '';
        }

	# $parm{FREQ} = $parm{FREQ} . '';
	# $parm{INTERVAL} = $parm{INTERVAL} . '';
	# $parm{COUNT} = $parm{COUNT} . '';
	# $parm{COUNT} = 999_999 unless $parm{COUNT};
	# $parm{UNTIL} = $parm{UNTIL} . '';
	# $parm{WKST} = $parm{WKST} . '';

	$parm{WKST} = "MO" unless $parm{WKST};

	# print " PARAMETERS: ", join(":", %parm), "\n";

	$when->print(title=>'WHEN');

	# apply DTSTART, just in case
	$when = $when->intersection( $parm{DTSTART}, $future  );

	# UNTIL and COUNT MUST NOT occur in the same 'recur'  (why?)
	if ($parm{UNTIL} ne '') {
		# UNTIL
		$when->print(title=>'UNTIL');
		$when = $when->intersection( $past, $parm{UNTIL} );
	}

	if ($parm{FREQ} ne '') {
		# FREQ, INTERVAL, COUNT

		# $DEBUG = 1;

		$when->print(title=>'FREQ');
		$parm{COUNT} = 999999 unless $parm{COUNT};
		$parm{INTERVAL} = 1 unless $parm{INTERVAL};

		if ($self->max == &inf) {
			# that's bad to quantize -- try to fix it
		}

		# -- FREQ works here:
		my $freq = $when->quantize(unit=>$freq{$parm{FREQ}}, strict=>0)
							->print(title=>'FREQ');

		# -- WKST works here:   --> only if FREQ=WEEKLY; see also: BYWEEKNO
		if ($parm{FREQ} eq 'WEEKLY') {
			my $wkst = $weekday{$parm{WKST}};
			# print " [ wkst: $parm{WKST} = $wkst ] \n";
			$freq = $freq->offset( unit=>'days', value=>[$wkst,$wkst] );
			# print " [ wkst: $freq ] \n";
		}

		$rrule = $when->intersection(
							$freq

							# -- INTERVAL works here:
							->select( freq=>$parm{INTERVAL}, count=>999999, strict=>0 ) 
							->print(title=>'FREQ('.$parm{FREQ}.')+INTERVAL('.$parm{INTERVAL}.')')

							->iterate( 	sub { $_[0]
											->print(title=>'PART-'.$parm{FREQ}) 
											->rrule_by ( %parm )
											->print(title=>'PART-done:') 
											} 
							)
							# remove anything out of range before counting!
							->intersection($parm{period})

							# -- COUNT works here:
							->select( freq=>1, count=>$parm{COUNT}, strict=>0 ) 
							->print(title=>'COUNT('.$parm{COUNT}.')')

							->duration( unit => 'seconds', duration => 0 )
						);
	}
	else {
		# is this in the RFC?
		$when->print(title=>'no FREQ or UNTIL');
		$rrule = $when->intersection(
							$when->rrule_by(%parm)
							->duration( unit => 'seconds', duration => 0 )
						);
	}



	if ($has{period}) {
		return $self->union ( $rrule );
	}
	return $rrule;
}

# INTERNAL sub to calculate BYxxx
#   input: $when, %parm
#   output: $when (filtered)
sub rrule_by {

	my ($when, %parm) = @_;
	my %has = ();

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

		$has{month} = 1;
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

		$has{month} = 1;
		$has{day} = 1;   # maybe
	}

	if (exists $parm{BYYEARDAY}) {
		my $byyearday = $when;
		my @by = (); foreach ( @{$parm{BYYEARDAY}} ) { push @by, $_-1, $_; }
		$when = $byyearday->intersection(
			$byyearday->quantize(unit=>'years', strict=>0)
			->offset(mode=>'circle', unit=>'days', value=>[@by], strict=>0 )
		)->no_cleanup; 
		$when->print(title=>'BYYEARDAY');

		$has{month} = 1;
		$has{day} = 1;
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

		$has{month} = 1;
		$has{day} = 1;
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
			if (($parm{FREQ} eq 'YEARLY') and not (exists $parm{BYMONTH})) {
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

		$has{month} = 1;
		$has{day} = 1;

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

		$has{hour} = 1;
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

		$has{minute} = 1;
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

		$has{second} = 1;
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


	# everything that was not defined is got from DTSTART
	unless ($has{month}) {
		my $tmp = $parm{DTSTART}->month - 1;
		# print " [ get month from $parm{DTSTART} = $tmp ]\n";
		$when = $when->offset(mode=>'begin', unit=>'months', value=>[$tmp,$tmp]);
	}
	unless ($has{day}) {
		my $tmp = $parm{DTSTART}->day - 1;
		$when = $when->offset(mode=>'begin', unit=>'days', value=>[$tmp,$tmp]);
	}
	unless ($has{hour}) {
		my $tmp = $parm{DTSTART}->hour;
		$when = $when->offset(mode=>'begin', unit=>'hours', value=>[$tmp,$tmp]);
	}
	unless ($has{minute}) {
		my $tmp = $parm{DTSTART}->minute;
		$when = $when->offset(mode=>'begin', unit=>'minutes', value=>[$tmp,$tmp]);
	}
	unless ($has{second}) {
		my $tmp = $parm{DTSTART}->second;
		$when = $when->offset(mode=>'begin', unit=>'seconds', value=>[$tmp,$tmp]);
	}


	return $when;
}

=head2 exrule

    exrule ( period => date-set, DTSTART => time,
        BYMONTH => [ list ],     BYWEEKNO => [ list ],
        BYYEARDAY => [ list ],   BYMONTHDAY => [ list ],
        BYDAY => [ list ],       BYHOUR => [ list ],
        BYMINUTE => [ list ],    BYSECOND => [ list ],
        BYSETPOS => [ list ],
        UNTIL => time, FREQ => freq, INTERVAL => n, COUNT => n,
		WKST => day )

Implements EXRULE (exclusion-rule) from RFC2445. 

'period' is optional.

=cut

sub exrule { 
	my $self = shift;
	unless (ref($self)) {
		# print " new: $self ";
		unshift @_, $self;
		$self = $forever;
	}
	my $class = ref($self);

	if (($self->{too_complex}) or ($self->min == -&inf) or ($self->max == &inf)) {
		my $b = $class->new();
		$self->trace(title=>"exrule:backtrack"); 
		# print " [exrule:backtrack] \n" if $DEBUG_BT;
		$b->{too_complex} = 1;
		$b->{parent} = $self;
		$b->{method} = 'exrule';
		$b->{param}  = \@_;
		return $b;
	}

	my %parm = @_;
	$parm{period} = $self unless $parm{period};
	my $period = $parm{period};
	delete $parm{period};
	# $DEBUG = 1;
	# print " [ Exclude ", join(':', %parm)," ",$self," ",$parm{period}->rrule(%parm)," ]\n";
	# print " [   period =     ", $parm{period}," ]\n";
	# print " [   rrule =      ", $parm{period}->rrule(%parm)," ]\n";
	# print " [   complement = ", $parm{period}->rrule(%parm)->complement," ]\n";
	return $self->complement( $period->rrule(%parm) );
}


=head2 rdate

	rdate( list => [time1, time2, ...] )

Adds the (scalar) list to the set, or creates a new list.

=cut

sub rdate { 
	my $self = shift;
	unless (ref($self)) {
		# print " new: $self ";
		# unshift @_, $self;
		$self = $never;
	}
	my $class = ref($self);
	my %parm = @_;

	# print " [rdate parm: ",join(':', %parm)," ]\n";
	# print " [rdate parm: ",join(':', @{$parm{list}} )," ]\n";
	my @list = ();
	foreach( @{$parm{list}} ) {
		push @list, $_, $_;
	}
	# print " [rdate list: ",join(':', @list)," = ", $class->new(@list), " ]\n";
	$self = $self->union( $class->new(@list) );
	$self->print(title=>'rdate ' . join(':', %parm) );
	return $self;
}


=head2 exdate

	exdate( list => [time1, time2, ...] )

Removes each element of the list from the set.

=cut

sub exdate { 
	my $self = shift;
	my $class = ref($self);
	my %parm = @_;

	my @list = ();
	foreach( @{$parm{list}} ) {
		push @list, $_, $_;
	}

	$self = $self->complement( $class->new(@list) );
	$self->print(title=>'exdate ' . join(':', %parm) );
	return $self;
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

'duration' and 'period' methods may change in future versions, to generate open-ended sets.

'WEEKLY' does not use 'WKST'

rrule syntax needs uppercase parameters

=head1 AUTHOR

Flavio Soibelmann Glock <fglock@pucrs.br> 
with the Reefknot team.

=cut
