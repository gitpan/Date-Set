#!/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

require Exporter;
use strict;

package Date::Set;

use Set::Infinite ':all';
use vars qw(@ISA @EXPORT @EXPORT_OK  $AUTOLOAD $VERSION
  %FREQ %WEEKDAY %WHICH_OCCURRENCE
  $FUTURE $PAST $FOREVER $NEVER
  $DEBUG
  );    # perl standard stuff / lookup tables / date sets / debug

use AutoLoader;
use Carp;
@ISA       = qw(Set::Infinite);
@EXPORT    = qw();
@EXPORT_OK = qw(type);
$VERSION = (qw'$Revision: 1.22 $')[1];

=head1 NAME

Date::Set - Date set math

=head1 SYNOPSIS

NOTE: The API is VERY unstable.
Please read the POD before upgrading from an earlier version.

    use Date::Set;

    my $interval = Date::Set->new('20010501')->as_months();
     print "This month: ". $interval. "\n\n";

        $interval = $interval->as_weeks;
    print "Weeks this month: ". $interval."\n\n";

        #Offset syntax is subject to change. (as is everything else for now ;)
        $interval->offset( mode => 'begin', unit=>'days', value => [ 2, 3] );
     print "Tuesdays this month: ". $interval . "\n\n";

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

$DEBUG                = 0;
$Set::Infinite::TRACE = 0;
Set::Infinite::type('Date::Set::ICal');

# A global used for mapping next/this/last/as names to quantize parameters.
%WHICH_OCCURRENCE = (
    'next' => 1,
    'this' => 0,
    'prev' => -1,
    'as'   => 0
);

%WEEKDAY = ( SU => 0, MO => 1, TU => 2, WE => 3, TH => 4, FR => 5, SA => 6 );

# $FUTURE is an infinite set for EVERYTHING in the future
$FUTURE = &inf;

# $PAST is an infinite set for EVERYTHING IN the past
$PAST = -&inf;

$FOREVER = __PACKAGE__->new( $PAST, $FUTURE );
$NEVER   = __PACKAGE__->new();

=head2 event

    event( start =>$date , end => $date, default => 'full' );

Constructor. By default, with no arguments, returns a Date::Set that, by default, encompasses 'forever', 
that is: (-Inf .. Inf).

Takes a param hash with several optional parameters:

        default => ('empty'||'full')
                If you specify a default of 'full', the returned object encompasses all of time.
                If you specify a default of 'empty', the returned object encompasses no time at all.
                Current module behavior always defaults to 'full'.
                TODO: see if there are cases where we EVER want to use empty

       start => Date::ICal

                If you specify a 'start' parameter, the returned set will be bounded to start on that date

       end => Date::ICal

                If you specify an 'end' parameter, the returned set will be bounded to end on that date

        TODO: we have no idea what happens if you set default to 'empty' and also specify a start and/or end date.

=cut

sub event {
    my $class = shift;
    my %args  = (
        start   => undef,
        end     => undef,
        default => 'full',
        @_
    );

    my ( $start, $end );

    if ( $args{'default'} eq 'full' ) {
        $start = $args{'start'} || $PAST;
        $end   = $args{'end'}   || $FUTURE;

    } elsif ( $args{'default'} eq 'empty' ) {
        $start = $args{'start'} || undef;
        $end   = $args{'end'}   || undef;
    }

    $class->new( $start, $end );
}

=head2  print

TODO: We think this is an internal debugging method. but if so, it should
be called _debug or at least _print. it gets used frequently in the code
which makes it appear to be more critical than we think it is. --jesse & srl.

Otherwise, it should get proper documentation and be public. but if so,
what would it do?

=cut

sub print {
    my ( $self, %parm ) = @_;
    print "\n $parm{title} = ", $self->fixtype, "\n" if $DEBUG;
    return $self;
}

=head2 period

    period( time => [time1, time2] )

    or

    period( start => Date::ICal,  end => Date::ICal )

This routine is a constructor. Returns an "empty" time period bounded by
the dates specified when called in a scalar context.

=cut

sub period {    # time[]
    my $class = shift;
    my %parm  = ( start => undef,
                  end => undef,
                  time => undef,
                  @_);
    my $self;
    if ($parm{start} && $parm{end}) {
        $self = $class->new( $parm{start}, $parm{end} );
    } else {

        # TODO: 'un-deprecated' until we fix the tests - Flavio

        # carp "$self -> period ( time => [a,b] calling convention deprecated.\n ".
        # "Please use start and end parameters instead";
        $self = $class->new( $parm{time}[0], $parm{time}[1] );
    }
    $self->print( title => 'period ' . join ( ':', %parm ) ) if $DEBUG;
    return $self;
}

=head2 dtstart

    dtstart( start => time1 )

Returns set intersection [time1 .. Inf)

'dtstart' puts a limit on when the event starts. 
If the event already starts AFTER dtstart, it will not change.

=cut

sub dtstart {    # start
    my ( $self, %parm ) = @_;
    $self->print( title => 'dtstart ' . join ( ':', %parm ) ) if $DEBUG;
    return $self->intersection( $parm{start}, $FUTURE );

    # my $tmp = __PACKAGE__->new($parm{start}, $FUTURE);
    # return $self->intersection($tmp);
}

=head2 dtend

    dtend( end => time1 )

Returns set intersection (Inf .. time1]

'dtend' puts a limit on when the event finishes. 
If the event already finish BEFORE dtend, it will not change.

=cut

sub dtend {    # end
    my ( $self, %parm ) = @_;
    $self->print( title => 'dtend ' . join ( ':', %parm ) ) if $DEBUG;
    return $self->intersection( $PAST, $parm{end} );

    # my $tmp = __PACKAGE__->new($parm{start}, $FUTURE);
    # return $self->intersection($tmp);
}

=head2 duration

    duration( unit => 'months', duration => 10 )

All intervals are modified to 'duration'.

'unit' parameter can be years, months, days, weeks, hours, minutes, or seconds.

=cut

sub duration {    # unit,duration
    my ( $self, %parm ) = @_;
    $self->print( title => 'duration' ) if $DEBUG;
    return $self->offset(
        mode  => 'begin',
        unit  => $parm{unit},
        value => [ 0, $parm{duration} ]
    );
}

%FREQ = (
    SECONDLY => 'seconds',
    MINUTELY => 'minutes',
    HOURLY   => 'hours',
    DAILY    => 'days',
    WEEKLY   => 'weeks',
    MONTHLY  => 'months',
    YEARLY   => 'years'
);

=head2 recur_by_rule

    recur_by_rule ( period => date-set,  DTSTART => time,
        BYMONTH => [ list ],     BYWEEKNO => [ list ],
        BYYEARDAY => [ list ],   BYMONTHDAY => [ list ],
        BYDAY => [ list ],       BYHOUR => [ list ],
        BYMINUTE => [ list ],    BYSECOND => [ list ],
        BYSETPOS => [ list ],
        UNTIL => time, FREQ => freq, INTERVAL => n, COUNT => n,
        WKST => day,
        RRULE => rrule-string,
        include_dtstart => 1 )

All parameters may be upper or lower case.

Implements RRULE from RFC2445. 

FREQ can be: SECONDLY MINUTELY HOURLY DAILY WEEKLY MONTHLY or YEARLY

WKST and BYDAY list may contain: SU MO TU WE TH FR SA.  By default, weeks start on monday (MO)

BYxxx items must be array references (must be bracketed) if the list
has more than one item: 

  BYMOHTH => 10                 or
  BYMONTH => [ 10 ]             or
  BYMONTH => [ 10, 11, 12 ]     or 
  BYMONTH => [ qw(10 11 12) ]

but NOT:

  BYMONTH => 10, 11, 12       #  NOT!

DTSTART value can be given explicitly, otherwise it will be taken from 'period' or from the set.

NOTE: "DTSTART" is *ALWAYS* included in the recurrence set,
whether or not it matches the rule. Use "include_dtstart => 0" to
override this.

NOTE: Some recurrences may give very big or even infinity sized sets.
The currenct implementation does not detect some of these cases and they might crash
your system.

NOTE: The RFC specifies that FREQ is *not* optional.

There are two operating modes: without 'period' it will filter out the rule from the set;
with 'period' it will filter out the rule from the period, then add the list to the set.

The datatype for 'period' is Date-Set.

=cut

# TODO: the API here is a bit weird. RFC parameters are in all caps. period is in lower case.
# this confuses me some. how should we make this clearer? --jesse

sub rrule {
    my $self = shift;
    carp ref $self . "->rrule deprecated in favor of recur_by_rule";
    return ( $self->recur_by_rule(@_) );
}

# This private routine parse an RRULE or an EXRULE and hands it back in the chunks
# that recur_by_rule and exclude_by_rule expect
sub _parse_rule {        
    my ($rrule) = @_; 
    my %return;
    # RRULEs look like 'FREQ=foo;INTERVAL=bar;' etc.
     my @pieces = split(';', $rrule);
     foreach (@pieces) {
         my ($name, $value) = split("=", $_);
       
        # BY<FOO> parameters should be arrays. everything else should be strings
         if ($name =~ /^BY/i) {
            @{$return{$name}} = split(/,/,$value);
         }
         else {
            $return{$name} = $value;
         }
     }
     return %return;
}
sub recur_by_rule {
    my $self = shift;

    # TODO - put 'if' around the parsing so that 'backtrack' doesn't have
    # to redo it

    # -- uppercase ALL keys AND values BEFORE assigning to parm
    # -- make all BY<FOO> array refs
    # print " RECUR_BY_RULE ",join(":",@_),"\n" if $DEBUG;
    my @parm = @_;
    my $last_p;
    foreach my $p (@parm) {
        print " $p=",ref($p),"=",ref(\$p)," " if $DEBUG;
        if (ref($p) eq 'ARRAY') {
            foreach my $q (@$p) { $q = uc($q) if defined $q and (ref(\$q) eq 'SCALAR') }
        }
        elsif (ref(\$p) eq 'SCALAR') {
            $p = uc($p) if defined $p;   # 'uc()' would turn 'undef' into 'empty string'
            # if it starts with BY this should be an array
            $p = [ $p ] if defined $last_p and ($last_p =~ /^BY/);
        }
        $last_p = $p;
    }
    print "\nRECUR_BY_RULE ",join(":",@_),"\n" if $DEBUG;

    my %parm = (
        # FREQ     => 'YEARLY',  # whatever
        INTERVAL => 1,
        COUNT    => 999999,    # any big number
        UNTIL    => undef,
        WKST     => 'MO',      # by default, weeks start on monday
        RRULE    => undef,
        PERIOD   => undef, 
        DTSTART  => undef,
        INCLUDE_DTSTART => 1,  # *ALWAYS* include DTSTART in result set
        @parm
    );

    my ( $rrule, %has );

    # parse an RRULE out into its pieces.
    if (defined $parm{'RRULE'} ) {
        my %temp_parm = _parse_rule($parm{'RRULE'}); 
        %parm = (%parm, %temp_parm);
    }

    # this is the constructor interface
    # it creates an object if we are not given one
    unless ( ref($self) ) {

        # If there's a period parameter passed in, start with an empty set
        # otherwise, start with a set of all dates
        # so that "period" will be initialized to "forever" too
        $self = ( defined $parm{PERIOD} ) ? $NEVER : $FOREVER;

        print " NEW: $self \n" if $DEBUG;
    }
    my $class = ref($self);

    # Try to find out what 'period' the rrule is talking about
    if ( defined $parm{PERIOD} ) {
        $has{period} = 1;
        print " PERIOD: $parm{PERIOD} \n" if $DEBUG;
        # try to make $self smaller
        $self = $self->intersection( $parm{PERIOD} );
    }
    else {
        $has{period}  = 0;
        print " NO PERIOD\n" if $DEBUG;
    }

    # this is the backtracking interface.
    # It allows the program to defer processing if it does not have enough
    # information to proceed.
    if ( ( $self->{too_complex} )
        or ( $self->min == -&inf )
        or ( $self->max == &inf ) )
    {
        my $b = $class->new();
        $self->trace( title => "rrule:backtrack" );
        print " BACKTRACKING \n" if $DEBUG;

        # print " [rrule:backtrack] \n" if $DEBUG_BT;
        $b->{too_complex} = 1;
        $b->{parent}      = $self;
        $b->{method}      = 'recur_by_rule';
        $b->{param}       = [%parm];
        return $b;
    }

    # -- don't do this before backtracking!
    $parm{PERIOD} = $self unless $has{period};

    my $when = $parm{PERIOD};

    # DTSTART gives the default values for month, day, h, m, s
    unless ( defined $parm{DTSTART} ) {
        $parm{DTSTART} = $parm{PERIOD}->min;
    }
    else {
        # apply DTSTART, just in case
        $when = $when->intersection( $parm{DTSTART}, $FUTURE );
    }

    # print " PARAMETERS: ", join(":", %parm), "\n";

    $when->print( title => 'WHEN' ) if $DEBUG;

    # UNTIL and COUNT MUST NOT occur in the same 'recur'  (why?)
    if ( $parm{UNTIL} ) {

        # UNTIL
        $when->print( title => 'UNTIL' ) if $DEBUG;
        $when = $when->intersection( $PAST, $parm{UNTIL} );
    }

    if ( $parm{FREQ} ) {

        # FREQ, INTERVAL & COUNT

        # $DEBUG = 1;

        $when->print( title => 'FREQ' ) if $DEBUG;

        if ( $self->max == &inf ) {

            # TODO
            # that's real hard to quantize -- try to fix it
            # should try to find out from DTEND, UNTIL, COUNT, etc. 

        }

        # -- FREQ handling
        # TODO: can we rename $freq to something more obvious?
        my $freq_unit = $FREQ{ $parm{FREQ} };
        my $freq = $when->quantize( unit => $freq_unit, strict => 0, fixtype => 0 );
        $freq->print( title => 'FREQ' ) if $DEBUG;

        # -- WKST works here:   --> only if FREQ=WEEKLY; see also: BYWEEKNO
        if ( $parm{FREQ} eq 'WEEKLY' ) {
            my $wkst = $WEEKDAY{ $parm{WKST} };

            # print " [ wkst: $parm{WKST} = $wkst ] \n";
            $freq = $freq->offset( unit => 'days', value => [ $wkst, $wkst ], fixtype => 0 );

            # print " [ wkst: $freq ] \n";
        }


        # --- TODO - check this for all possible "FREQ" ---
        if ( $freq_unit eq "months" )  { $has{months} = 1 }
        # 'FREQ=WEEKLY' MEANS THAT 'DTSTART' SPECIFIES *DAY-OF-WEEK*
        # unless there is a 'BYDAY'
        if ( $freq_unit eq "weeks" )   { $has{months} = 1 }
        # 'FREQ=DAILY' auto-define "day"
        if ( $freq_unit eq "days" )    { $has{months} = $has{days} = 1 }
        if ( $freq_unit eq "hours" )   { $has{months} = $has{days} = $has{hours} = 1 }
        if ( $freq_unit eq "minutes" ) { $has{months} = $has{days} = $has{hours} = $has{minutes} = 1 }
        if ( $freq_unit eq "seconds" ) { $has{months} = $has{days} = $has{hours} = $has{minutes} = $has{seconds} = 1 }

        $when->print( title => 'WHEN (before INTERVAL, COUNT)' ) if $DEBUG;

        # -- end FREQ handling


        # -- INTERVAL handling
        if ($parm{INTERVAL} > 1) {
            $freq = $freq
              # -- INTERVAL works here:
              ->select( freq => $parm{INTERVAL}, count => 999999, strict => 0 )
              ->print(
                title => 'FREQ('
                  . $parm{FREQ}
                  . ')+INTERVAL('
                  . $parm{INTERVAL} . ')'
              )->compact;
        }

        # -- BYSETPOS special handling -- 
        # BYSETPOS works for each FREQ subset, so we have to 'iterate'
        # over 'FREQ'
        if ( exists $parm{BYSETPOS} ) {
            print " [ENTERING ITERATE->RRULE]\n" if $DEBUG;
            $freq = $freq->iterate(
                sub {
                    $_[0]->print( title => 'PART-' . $parm{FREQ} ) if $DEBUG;
                    my $tmp = $_[0]->_rrule_by( \%parm , \%has );
                    $tmp->print( title => 'PART-done:' ) if $DEBUG;
                    return $tmp;
                  }
              )
        }
        else {
            print " [ENTERING RRULE]\n" if $DEBUG;
            $freq = $freq->_rrule_by( \%parm , \%has );
        }

        $freq->print( title => 'FREQ (after INTERVAL, RRULE)' ) if $DEBUG;

        $rrule = $when->intersection( $freq
              ->_apply_DTSTART( \%parm , \%has )

              # remove anything out of range before counting!
              ->intersection( $parm{PERIOD} )

              # -- COUNT works here:
              ->select( freq => 1, count => $parm{COUNT}, strict => 0 )
              ->print( title => 'COUNT(' . $parm{COUNT} . ')' )

              # ->duration( unit => 'seconds', duration => 0 ) 
              ->offset(mode=>'begin', value=>[0,0])
        );
    } else {

        # is this in the RFC?
        # probably not, but we can try to find an answer anyway

        $when->print( title => 'no FREQ or UNTIL' ) if $DEBUG;
        $parm{FREQ} = '';   # "define" it
        $rrule =
          $when->intersection( $when->_rrule_by( \%parm , \%has )
              ->_apply_DTSTART( \%parm , \%has )
              # ->duration( unit => 'seconds', duration => 0 ) 
              ->offset(mode=>'begin', value=>[0,0])
          );
    }


    # ALWAYS include DTSTART in the result
    # unless we are told not to do so
    $rrule = $rrule->union( $parm{DTSTART} ) if $parm{INCLUDE_DTSTART};

    if ( $has{period} ) {
        return $self->union($rrule)->fixtype;
    }
    return $rrule->fixtype;
}


# INTERNAL sub to define pending parameters from DTSTART
#   input: $when, %parm

#   output: $when (filtered)


sub _apply_DTSTART {
    my $when =   $_[0];
    my %parm = %{$_[1]};
    print " [EVALUATING RRULE PARM ",join(':',%parm)," ]\n" if $DEBUG;
    my %has =  %{$_[2]};
    print " [EVALUATING RRULE HAS  ",join(':',%has)," ]\n" if $DEBUG;
    my $wkst = $WEEKDAY{ $parm{WKST} };
    my $tmp;

    #  {{{ everything that was not defined is got from DTSTART
    foreach my $has ( qw'months days hours minutes seconds' ) {
        unless ( $has{$has} ) {
            if ( ($has eq 'days') and ($parm{FREQ} eq 'WEEKLY') ) {
                # SPECIAL CASE: WEEKLY + NO-DAY == WEEK-DAY

                # Returns the day of week as 0..6 (0 is Sunday, 6 is Saturday)
                $tmp = $parm{DTSTART}->date_ical->day_of_week - $wkst;
                $tmp += 7 if $tmp < 0;
                print " [INSERT DTSTART WEEKDAY => $tmp ]\n" if $DEBUG;
            }
            else {
                my ($date_ical_method) = $has =~ /(.*)s/;
                # if ($parm{DTSTART}->date_ical->can($date_ical_method)) {
                    $tmp = $parm{DTSTART}->date_ical->$date_ical_method;
                # }
                # else {
                #    $tmp = $parm{DTSTART}; # infinity ?
                # }
                $tmp-- if ($has eq 'months') or ($has eq 'days');  # month,day start in '1'
            }
            if ($tmp) {
                print " [INSERT DTSTART $has => $tmp ]\n" if $DEBUG;
                $when = $when->offset(
                    mode  => 'begin',
                    unit  => $has,
                    value => [ $tmp, $tmp ], fixtype => 0
                );
            }
        }
    } # end: foreach m/d/h/m/s
    # }}}

	return $when;
}


# INTERNAL sub to calculate BYxxx
#   input: $when, %parm

#   output: $when (filtered)

# TODO: This code needs to be refactored into ~ <50 line chunks and tested

sub _rrule_by {

    print " [EVALUATING RRULE ",join(':',@_)," ]\n" if $DEBUG;

    my $when =   $_[0];
    my %parm = %{$_[1]};
    print " [EVALUATING RRULE PARM ",join(':',%parm)," ]\n" if $DEBUG;
    my %has =  %{$_[2]};
    print " [EVALUATING RRULE HAS  ",join(':',%has)," ]\n" if $DEBUG;
    my $wkst = $WEEKDAY{ $parm{WKST} };

    my $base = $when;  # this is what we had after "FREQ"

    # {{{ evaluation order: BYMONTH, BYWEEKNO, BYYEARDAY, BYMONTHDAY, BYDAY, BYHOUR,
    # BYMINUTE, BYSECOND and BYSETPOS; then COUNT and UNTIL

    # {{{ if exists BYMONTH / BYWEEKNO / BYYEARDAY / BYMONTHDAY
    foreach ( [ 'BYMONTH',    'years',     'months'    ],
              [ 'BYWEEKNO',   'weekyears', 'weeks'     ],
              [ 'BYYEARDAY',  'years',     'days'      ],
              [ 'BYMONTHDAY', 'months',    'days'      ]  ) {
        my    ( $BYfoo,       $big_unit,   $small_unit ) = @$_;
        if ( exists $parm{$BYfoo} ) {
            my @by = ();
            foreach ( @{ $parm{$BYfoo} } ) {
                if ($_ > 0) {
                    push @by, $_ - 1, $_;   # positive: starts in 0,1
                } else {
                    push @by, $_, $_ + 1;   # negative: starts in -1,0
                }
            }
            $when = $when->intersection(
                $when->quantize(
                    unit   => $big_unit,
                    wkst   => $wkst,
                    strict => 0,
                    fixtype => 0 )
                  # ->print( title => $BYfoo . ":quantize=" . $big_unit )
                  ->offset(
                    mode   => 'circle',
                    unit   => $small_unit,
                    value  => [@by],
                    strict => 0,
                    fixtype => 0 )
                  # ->print( title => $BYfoo . ":offset=" . $small_unit . join ( ',', @by ) )
            )->no_cleanup;
            $when->print( title => $BYfoo ) if $DEBUG;
            $has{months} = 1;
            $has{days}   = 1 if $small_unit eq 'days';
        }
    }
    # }}}

    # {{{ if exists BYDAY

    if ( exists $parm{BYDAY} ) {
        my $BYDAY = $when;
        my ($indexed, $non_indexed);

        #   Each BYDAY value can also be preceded by a positive (+n) or negative
        #   (-n) integer. If present, this indicates the nth occurrence of the
        #   specific day within the MONTHLY or YEARLY RRULE.

        # classify BYDAY parameters between indexed and non-indexed
        my ( @byday, @indexed_byday );
        foreach ( @{ $parm{BYDAY} } ) {
            if (/[\-\+\d]/) {
               push @indexed_byday, $_
            }
            else {
               push @byday, $_
            }
        }

        if ( $#byday >= 0 ) {
            # non-indexed BYDAY
            my @by = ();
            foreach my $day ( @{ $parm{BYDAY} } ) {
                push @by, $WEEKDAY{$day}, ( $WEEKDAY{$day} + 1 );
            }
            $non_indexed = $BYDAY->quantize(
                    unit => 'weeks',
                    wkst => $wkst,
                    strict => 0,
                    fixtype => 0 )
                  # ->print (title=>'weeks')
                  ->offset(
                    mode   => 'circle',
                    unit   => 'days',
                    value  => [@by],
                    strict => 0,
                    fixtype => 0
                  );
            $non_indexed->print( title => 'BYDAY' ) if $DEBUG;
        }
        else {
            $non_indexed = $NEVER;
        }

        if ( $#indexed_byday >= 0 ) {
            # indexed BYDAY
            # reuse "base" since we already know it from FREQ
            # -- iterate through parameters
            $indexed = $NEVER;
            foreach (@indexed_byday) {
                # parse parameters
                my ( $index, $day ) = /([\-\+]?\d+)(\w\w)/;
                print " [Indexed BYDAY: $index $day ]\n" if $DEBUG;
                $index-- if $index > 0;   # perl index starts in 0 instead of 1
                $day = $WEEKDAY{$day};
                # print " [Indexed BYDAY: $index $day ]\n" if $DEBUG;
                my $weekday = $base->offset( 
                    mode => 'offset', 
                    unit => 'weekdays', 
                    value => [ $day, $day ] );
                $weekday->print( title => "WEEKDAYS: $day " ) if $DEBUG;
                $weekday = $weekday->offset( 
                    mode => 'circle', 
                    unit => 'days', 
                    value => [ $index * 7, $index * 7 + 1 ] );
                $weekday->print( title => "DAYS: $index weeks" ) if $DEBUG;
                $indexed = $indexed->union( $weekday );
                $indexed->print( title => 'BYDAY-INDEX:' . $index . ',' . $day ) if $DEBUG;
            }
        }
        else {
            $indexed = $NEVER;
        }

        # mix indexed with non-indexed days
        $when = $BYDAY->intersection(
                    $non_indexed->union($indexed)
                )->no_cleanup;
        $when->print( title => 'BYDAY' ) if $DEBUG;

        $has{months} = 1;
        $has{days}   = 1;
    }    # end: BYDAY
    # }}}

    # {{{ byhour, byminute, and bysecond
    # byhour, byminute, and bysecond use the same processing sequence
    foreach ( 
          [ 'BYHOUR',   'days',    'hours'   ],
          [ 'BYMINUTE', 'hours',   'minutes' ],
          [ 'BYSECOND', 'minutes', 'seconds' ] ) {
        my ($BYx, $prev_unit, $has) = @$_;
        if ( exists $parm{$BYx} ) {
            my @by     = ();
            foreach ( @{ $parm{$BYx} } ) { push @by, $_, $_ + 1; }
            $when->print( title => 'before ' . $BYx ) if $DEBUG;
            $when = $when->intersection(
                $when->quantize(
                    unit => $prev_unit,
                    fixtype => 0 )
                 ->offset(
                    mode   => 'circle',
                    unit   => $has,
                    value  => [@by],
                    strict => 0, fixtype => 0 )
            )->no_cleanup;
            $when->print( title => $BYx ) if $DEBUG;
            $has{$has} = 1;
        }
    } # end: foreach h/m/s
    # }}}

    # {{{ if exists BYSETPOS

    if ( exists $parm{BYSETPOS} ) {
        my @by = @{ $parm{BYSETPOS} };
        foreach (@by) { $_-- if $_ > 0 }    # BY starts in 1; perl starts in 0
        $when = $when->intersection( 
           $when->compact
           # ->print (title=>'bysetpos1')
           ->select( by => [@by] )
           # ->print (title=>'bysetpos2')
        )->no_cleanup;
        $when->print( title => 'BYSETPOS' ) if $DEBUG;
    }
    # }}} 

    # }}}

    %{$_[2]} = %has;
    return $when;
}

=head2 exclude_by_rule

    exclude_by_rule ( period => date-set, DTSTART => time,
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
    carp ref($self) . "->exrule deprecated in favor of exclude_by_rule";
    return ( $self->exclude_by_rule(@_) );
}

sub exclude_by_rule {
    my $self = shift;
    unless ( ref($self) ) {

        # print " new: $self ";
        unshift @_, $self;
        $self = $FOREVER;
    }
    my $class = ref($self);

    if ( ( $self->{too_complex} )
        or ( $self->min == -&inf )
        or ( $self->max == &inf ) )
    {
        my $b = $class->new();
        $self->trace( title => "exclude_by_rule:backtrack" );

        # print " [exclude_by_rule:backtrack] \n" if $DEBUG_BT;
        $b->{too_complex} = 1;
        $b->{parent}      = $self;
        $b->{method}      = 'exclude_by_rule';
        $b->{param}       = \@_;
        return $b;
    }

    my %parm = @_;
    $parm{PERIOD} = $parm{period} unless exists $parm{PERIOD};
    $parm{INCLUDE_DTSTART} = $parm{include_dtstart} unless exists $parm{INCLUDE_DTSTART};

    $parm{PERIOD} = $self unless defined $parm{PERIOD};
    my $period = $parm{PERIOD};
    delete $parm{PERIOD};

    $parm{INCLUDE_DTSTART} = 0 unless $parm{INCLUDE_DTSTART};

    # $DEBUG = 1;
    # print " [ Exclude ", join(':', %parm)," ",$self," ",$parm{period}->recur_by_rule(%parm)," ]\n";
    # print " [   period =     ", $parm{period}," ]\n";
    # print " [   rrule =      ", $parm{period}->recur_by_rule(%parm)," ]\n";
    # print " [   complement = ", $parm{period}->recur_by_rule(%parm)->complement," ]\n";
    return $self->complement( $period->recur_by_rule(%parm) );
}

=head2 recur_by_date

    recur_by_date( list => [time1, time2, ...] )

Adds the (scalar) list to the set, or creates a new list.

This Date::Set will recur on each item of the list provided.
This method lets you add items to a set of dates. If you
call it multiple times, entries from previous calls will
be preserved. If you need to delete them again, use exclude_by_date.

=cut

sub rdate {
    my $self = shift;
    carp ref $self . "->rdate deprecated in favor of recur_by_date";
    return ( $self->recur_by_date(@_) );
}

sub recur_by_date {
    my $self = shift;
    unless ( ref($self) ) {

        # print " new: $self ";
        # unshift @_, $self;
        $self = $NEVER;
    }
    my $class = ref($self);
    my %parm  = @_;

    # print " [recur_by_date parm: ",join(':', %parm)," ]\n";
    # print " [recur_by_date parm: ",join(':', @{$parm{list}} )," ]\n";
    my @list = ();
    foreach ( @{ $parm{list} } ) {
        push @list, $_, $_;
    }

    # print " [recur_by_date list: ",join(':', @list)," = ", $class->new(@list), " ]\n";
    $self = $self->union( $class->new(@list) );
    $self->print( title => 'recur_by_date ' . join ( ':', %parm ) ) if $DEBUG;
    return $self;
}

=head2 exclude_by_date

    exclude_by_date( list => [time1, time2, ...] )

Removes each element of the list from the set.

=cut

sub exdate {
    my $self = shift;
    carp ref $self . "->exdate deprecated in favor of exclude_by_date";
    return ( $self->exclude_by_date(@_) );
}

sub exclude_by_date {
    my $self  = shift;
    my $class = ref($self);
    my %parm  = @_;

    my @list = ();
    foreach ( @{ $parm{list} } ) {
        push @list, $_, $_;
    }

    $self = $self->complement( $class->new(@list) );
    $self->print( title => 'exclude_by_date ' . join ( ':', %parm ) ) if $DEBUG;

    # parse an EXULE out into its pieces.
    if ($parm{'EXULE'} ) {
        my %temp_parm = _parse_rule($parm{'EXULE'}); 
        %parm = (%parm, %temp_parm);
     } 

    return $self;
}

=head2 occurrences

    occurrences( period => date-set )

Returns the occurrences for a given period. In other words,
"when does this event occur during the given period?"

=cut

sub occurrences {    # event->, period
    my $self = shift;
    my %parm = @_;
    
    unless ($parm{'period'}) {
        carp "$self -> occurrences called without a period argument";
    }

    my $intersection =  $self->intersection( $parm{period} );
    return($intersection);
}

=head2 next_year, next_month, next_week, next_day, next_hour, next_minute, next_day ($date_set)

=head2 this_year, this_month, this_week, this_day, this_hour, this_minute, this_day ($date_set)

=head2 prev_year, prev_month, prev_week, prev_day, prev_hour, prev_minute, prev_day ($date_set)

    next_month( date-set ) 
    this_year ( date-set )    # [20010101..20020101)

Returns the next/prev/this unit of time for a given period. 

It answers questions like,
"when is next month for the given period?",
"which years are covered by this period?"

TODO: explain this and give more examples, cookbook-style.

=head2 as_years, as_months, as_weeks, as_days, as_hours, as_minutes, as_days ($date_set)

    as_months( date-set ) 
    as_weeks ( date-set ) 

Returns the given period in a 'unit of time' form. 

It answers questions like,
"which months we have in this period?",
"which years are covered by this period?"

TODO: explain this and give more examples, cookbook-style.

=cut

# try to make up for unwritten methods
# currently defined are:
#   next_XXX  (next_day, next_month ...), this_XXX,  prev_XXX

sub AUTOLOAD {

    no strict 'refs';

    # print " AUTOLOAD $#_ $AUTOLOAD [ ", join(" , ", @_), " ] \n";
    if ( $AUTOLOAD =~ /.*::(.*?)$/ ) {
        my $sub = $1;

        # This matches all the possibe method names that we want to catch in autoload
        # let anything that doesn't match this regex fall through; for example, DESTROY
        if ( $sub =~
            /^(next|prev|this|as)_(year|month|week|day|hour|minute|second)(s)?$/
          )
        {
            my $which = $WHICH_OCCURRENCE{$1};    # prev this next ==> -1 0 1
            my $unit  = $2 . 's';

            #We always want plural. it's easiest to optionally strip and then add.

            # We're going to bind what this sub is really doing into the symbol table
            # This way, repeated calls don't incur the autoload penalty
            *{$AUTOLOAD} = sub {
                my $quantized =
                  $_[0]->quantize( unit => $unit, strict => $_[0] );
                $quantized = $quantized->offset(
                    unit  => "$unit",
                    value => [ $which, $which ]
                  )
                  if $which;
                return ( $quantized->compact );
            };

            # I'm still fairly uncomfortable with using a goto here. The alternative is that
            # we repeat the sub above as a direct call to quantize here.  We should
            # do some perf testing to see if that would be faster.   --jesse

            # [10 minutes later] actually, perldoc -f goto tells us that this is a 
            # _good_ use of goto. so it will stay. -jesse

            goto &$sub;

        }
    } else {
        Carp::croak( __PACKAGE__ . $AUTOLOAD . " is malformed in AUTOLOAD" );
    }

}

=head1 NEW API

Not all of this has been properly implemented or solidified yet. We're assuming Date::Set deals with ICal dates.
This still feels a bit weird

=head2 Date::Set->new($arg)

Creates a new Date::Set.

$arg can be a string, another Date::Set::ICal object, 
a Date::ICal object, or a Set::Infinite::Element_Inf object.

=head2 start_date ([$date]) 

sets or gets the starting date(/time?) of the set.
If called with no argument, gets the current value; otherwise, sets it.

=head2 end_date ([$date])

sets or gets the ending date(/time?) of the set.
If called with no argument, gets the current value; otherwise, sets it.

=head2 duration (duration_before, duration_after ?) 

=head2 period (= start_date + end_date, or start_date + duration_after, or duration_before + end_date) 


=head2 dates_by_rule 

=head2 date_by_rule or include_dates 

huh?

=head2 include_period (=union) 
   (syntactic sugar for Set::Infinite::union) 

=head2 exclude_period (=complement) 
   (syntactic sugar for Set::Infinite::complement) 

=head2 overlapping_periods_with ($set) 

   (syntactic sugar for Set::Infinite::intersection) 

Returns a Date::Set of the overlaps between $self and another Date::Set.

This can be thought of as "conflicting periods with" or "common periods with",
depending on the scheduling application. Free/busy times are more easily
thought of as "common periods free", where events are more easily thought of
as "periods that conflict with one another" if you've overscheduled. 

=head2 overlaps_with ( $set )
    
   (syntactic sugar for Set::Infinite::intersects) 

Returns true if $self overlaps with $set, a Date::Set.
Otherwise returns false.

=head2 add_days, add_weeks, add_years ... (=offset) 

=head2 as_list (=list) 

=head2 (?) (=iterate) 

=head2 final_occurrence_before ($date)
 
   $date should be a Date::ICal.
   Last occurrence before today; 
   returns a single-instance Date::Set ("tuesday, 21 january 2000 from 3pm to 4pm")
   
   rule(...)->before(today)->last; 

=head2 first_occurrence_after ($date)

   $date should be a Date::ICal.
   Next occurrence; 
   returns a single-instance Date::Set ("tuesday, 21 january 2000 from 3pm to 4pm")
   
   rule(...)->after(now)->first; 

=cut

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

'duration' and 'period' methods may change in future versions, to generate open-ended sets.

=head1 AUTHOR

Flavio Soibelmann Glock <fglock@pucrs.br> 
with the Reefknot team.

=cut

