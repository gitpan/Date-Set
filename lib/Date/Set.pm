#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

require Exporter;
use strict;

package Date::Set;

use Set::Infinite ':all'; 
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION $DEBUG
    $future $past $forever
    %freq %weekday
);
@ISA = qw(Set::Infinite);
@EXPORT = qw();
@EXPORT_OK = qw(type);
$VERSION = '0.02';

$DEBUG = 0;
$Set::Infinite::TRACE = 0;
Set::Infinite::type('Date::Set::ICal');


$future  = &inf; 
$past    = -&inf;   
$forever = __PACKAGE__->new($past, $future);

sub event   { $forever }

sub print {
	my ($self, %parm) = @_;
	print "\n $parm{title} = ",$self,"\n" if $DEBUG;
	return $self;
}

sub period { # time[]
	my ($class, %parm) = @_;
	my $self;
	$self = $class->new($parm{time}[0], $parm{time}[1]);
	$self->print(title=>'period ' . join(':', %parm) );
	return $self;
}

sub dtstart { # start
	my ($self, %parm) = @_;
	$self->print(title=>'dtstart ' . join(':', %parm) );
	return $self->intersection($parm{start}, $future);
	# my $tmp = __PACKAGE__->new($parm{start}, $future);
	# return $self->intersection($tmp);
}

sub duration { # unit,duration
	my ($self, %parm) = @_;
	$self->print(title=>'duration');
	return $self->offset(mode=>'begin', unit=>$parm{unit}, value=>[0, $parm{duration}]);
}

%freq = qw(SECONDLY seconds MINUTELY minutes HOURLY hours DAILY days WEEKLY weeks MONTHLY months YEARLY years);
%weekday = qw( SU 0 MO 1 TU 2 WE 3 TH 4 FR 5 SA 6 );

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
		$when = $byweekno->intersection(
			$byweekno->quantize(unit=>'years', strict=>0)
			#->print (title=>'year')
			# *** Put WKST here ********** TODO *********
			->offset(mode=>'begin', value=>[0,0] )
			->quantize(unit=>'weeks', strict=>0)
			->print (title=>'week')
			->offset(unit=>'weeks', mode=>'circle', value=>[@by], strict=>0 ) 
			->print (title=>'week-by ' . join(',' , @by) )
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
		my @by = (); foreach ( map { $weekday{$_} } @{$parm{BYDAY}} ) { push @by, $_, $_+1; }
		$when = $BYDAY->intersection(
			$BYDAY->quantize(unit=>'weeks', strict=>0)
			# ->print (title=>'weeks')
			->offset(mode=>'circle', unit=>'days', value=>[@by], strict=>0 )
			# ->print (title=>'days')
		)->no_cleanup; 
		$when->print(title=>'BYDAY');
	}

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

sub occurrences { # event->, period 
	my ($self, %parm) = @_;
	return $self->intersection($parm{period});
}


1;

__END__

=head1 NAME

Date::Set - Date set math

=head1 SYNOPSIS

	use Date::Set;

	my $interval = Date::Set->new('20010501')->quantize(unit=>'months');
	print "This month: ", $interval, "\n\n";
	print "Weeks this month: ", $interval->quantize(unit=>'weeks'), "\n\n";
	print "Tuesdays this month: ", $interval->quantize(unit=>'weeks')->
	    offset( mode => 'begin', unit=>'days', value => [ 2, 3] );

=head1 DESCRIPTION

Date::Set is a module for date/time sets. 

It requires Date::ICal. 
If you don't need ICal functionality, 
use Set::Infinite instead.

=head1 METHODS

=head2 event

	event()

Constructor. Returns 'forever', that is: (-Inf .. Inf)

=head2 period

	period( time => [time1, time2] )

Another constructor. Returns [time1 .. time2]

=head2 dtstart

	dtstart( start => time1 )

Returns set intersection [time1 .. Inf)

'dtstart' puts a limit when the event starts. 
If the event already starts AFTER dtstart, it will not change.

=head2 duration

	duration( unit => months, duration => 10 )

All intervals are modified to 'duration'.

'unit' parameter can be years, months, days, weeks, hours, minutes, or seconds.

=head2 rrule

    rrule ( BYMONTH => [ list ], BYWEEKNO => [ list ],
        BYYEARDAY => [ list ],   BYMONTHDAY => [ list ],
        BYDAY => [ list ],       BYHOUR => [ list ],
        BYMINUTE => [ list ],    BYSECOND => [ list ],
        BYSETPOS => [ list ],
        UNTIL => time, FREQ => freq, INTERVAL => n, COUNT => n )

Implements RRULE from RFC2445. 

FREQ can be: SECONDLY MINUTELY HOURLY DAILY WEEKLY MONTHLY or YEARLY

BYDAY list may contain: SU MO TU WE TH FR SA

BYxxx items must be array references (must be bracketed): BYMONTH => [ 10 ] or
BYMONTH => [ 10, 11, 12 ] or BYMONTH => [ qw(10 11 12) ]

(some documentation needed!)

=head2 occurrences

	occurrences( period => date-set )

Returns the occurrences for a given period.


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
    $i = $a->complement($b);
    $i = $a->span;   

=head2 Scalar  

    $i = $a->min;
    $i = $a->max;
    $i = $a->size;  

=head2 Other set methods

    $a->real;
    $a->integer;

    quantize( parameters )
	    Makes equal-sized subsets.

    select( parameters )

    	Selects set members based on their ordered positions.
    	Selection is more useful after quantization.

    	freq     - default=1
    	by       - default=[0]
    	interval - default=1
    	count    - dafault=infinite

    offset ( parameters )

    	Offsets the subsets.

    	value   - default=[0,0]
    	mode    - default='offset'. Possible values are: 'offset', 'begin', 'end'.

    type($i)

    	chooses an object data type. 

    	type('Set::Infinite::Date');

    tolerance(0)    defaults to real sets (default)
    tolerance(1)    defaults to integer sets

Note: 'unit' parameter can be years, months, days, weeks, hours, minutes, or seconds.  

=head1 BUGS

'rrule' method is not yet full RFC2445 compliant.

'byday' does not understand (scalar . string) formats yet (like '-2FR')

'duration' and 'period' methods may change in future versions, to generate open-ended sets.

'bymonth' does not accept a negative value

'WKST' is not implemented yet

'byweekno' needs a 'weekyear' quantize unit to work properly. (See: Date::Tie)

=head1 AUTHOR

Flavio Soibelmann Glock <fglock@pucrs.br> 
with the Reefknot team.

=cut
