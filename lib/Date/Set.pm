#!/bin/perl
# Copyright (c) 2001, 2002 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

require Exporter;
use strict;

package Date::Set;

use Set::Infinite;
use vars qw(@ISA @EXPORT @EXPORT_OK  $AUTOLOAD $VERSION
  %FREQ %WEEKDAY %WHICH_OCCURRENCE
  $FUTURE $PAST $FOREVER $NEVER
  $WKST $inf
  $DEBUG
  );    # perl standard stuff / lookup tables / date sets / debug

use AutoLoader;
use Carp;
@ISA       = qw(Set::Infinite);
@EXPORT    = qw();
@EXPORT_OK = qw(type $inf inf);
$VERSION = (qw'$Revision: 1.24_08 $')[1];


#----- initialize package globals

$DEBUG                = 0;
$Set::Infinite::TRACE = 0;
Set::Infinite::type('Date::Set::ICal');
$inf = 10**10**10;
sub inf { $inf }

$WKST = 'MO';      # by default, weeks start on monday

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

#----- end: initialize package globals

#----- our special version of new()
# propagates dtstart 

sub new {
    my $class = shift;
    my $self = Set::Infinite->new(@_);
    bless $self, __PACKAGE__;
    # print " new ";
    $self->{dtstart} = ref($class) ? $class->{dtstart} : undef;
    $self->{wkst} =    ref($class) ? $class->{wkst}    : $WKST;
    return $self;
}

#----- POD intro

=head1 NAME

Date::Set - Date set math

=head1 SYNOPSIS

    use Date::Set;

    $a = Date::Set->event( at => '20020311' );      # 20020311
    $a->event( at => [ '20020312', '20020313' ] );  # 20020311,[20020312..20020313]
    $a->exclude( at => '20020312' );                # 20020311,(20020312..20020313]

=head1 DESCRIPTION

Date::Set is a module for date/time sets. It allows you to generate
groups of dates, like "every wednesday", and then find all the dates
matching that pattern. 

This module is part of the Reefknot project http://reefknot.sf.net

It requires Date::ICal and Set::Infinite.

=head2 Limitations

THIS IS PRELIMINARY INFORMATION. This API may change. 
Everything in 'OLD API' section is safe to use, but might get 
deprecated.

Some internal operations still use the system's 'time' functions and
are limited by epoch issues (no support for years outside the 
1970-2038 range).

Date::Set does not implement timezones yet. 
All dates are in UTC.

Date::ICal durations are not supported yet.

=head2 IETF RFC 2445 (iCalendar)

If you want to understand the context of this module, look at
IETF RFC 2445 (iCalendar). 
It specifies the syntax for describing recurring events. 

If you don't need iCalendar functionality, 
you may try to use Set::Infinite directly.
Most of Date::Set is syntactic sugar for Set::Infinite functions.

RFC2445 can be obtained for free at http://www.ietf.org/rfc/rfc2445.txt

=head2 ISO 8601 week

We use the words 'weekyear' and 'year' with special meanings. 

'year' is a period beginning in january first, ending in december 31.

'weekyear' is the year, beginning in 'first week of year' and ending
in 'last week of year'. 
This year break is somewhere in late-december or begin-january, 
and it is NOT equal to 'first day of january'. 

However, 'first monday of year' is 'first monday of january'. 
It is not 'first monday of first week'.

ISO8601 cannot be obtained for free, as far as I know.

=head2 What's a Date Set

A Date Set is a collection of Dates. 

Date::ICal module defines what a 'date' is.
Set::Infinite module defines what a 'set' is.
This module puts them together.

This module accepts both Date::ICal objects or string dates.

These are Date Sets:

    ''                                          # empty

    '19971024T120000Z'                          # one date

    '19971024T120000Z', '19971025T120000Z'      # two dates

=head2 Period

A Date Set period is an infinite set: you can't 
count how many single dates are there inside the set, because it is 'continuous':

    '19971024T120000Z' ... '19971025T120000Z'   # all dates between days 24 and 25

    '19971024T120000Z' ... 'infinity'           # all dates after day 24

A Date Set can have more date periods:

    '19971024T120000Z' ... '19971025T120000Z',  # all dates between days 24
    '19971124T120000Z' ... '19971125T120000Z'   # and 25, in october and in november

=head2 Recurrence

Sometimes a Date::Set have an infinity number of periods. This is what happen when 
you have a 'recurrence'.

A recurrence is created by a 'recurrence rule':

    $recurr = Date::Set->event( rule => 'FREQ=YEARLY' );   # all possible years

An unbounded recurrence like this cannot be printed. 
It would take an infinitely long roll of paper.

    print $recurr;  # "Too Complex"  

You can limit a recurrence into a more useful period of time:

    $a->event( rule => 'FREQ=YEARLY;INTERVAL=2' );
    $a->during( start => $today, end => $year_2020 );

The program waits until you ask for a particular
recurrence before calculating it. This is implemented by module 
Set::Infinite, and it is based on 'functional programming'.
If you are interested on how this works, take a look at Set::Infinite.

=head2 Encapsulation

Object-oriented programmers are told not to modify an object's data directly, 
and to use the object's methods instead. 

For most objects you don't see any difference, but for 
Date::Set objects, changing the internal data might break your
program:

- there are many internal formats/states for Date::Set objects,
that are translated by the API at run-time (this behaviour is inherited from 
Set::Infinite). You must be sure what your object state will be.
In other words, you might be asking for data that does not exist yet.

- due to optimizations, modifying an object's internal data might break 
some function's results, since you 
might get a pointer into the memoization cache. In other words, two 
different objects might
be sharing the same data.

=head2 Open and closed intervals

If we used integer arithmetic only, then the interval 

    '20010101T000000' < date < '20020501T000000' 

could be written [ '20010101T000001' .. '20020430T235959' ].

This method doesn't work well for real numbers, so we use the
'open' and 'closed' interval notation:

A closed interval is an interval which includes its limit points.
It is written with square brackets.

    [ '20010101' .. '20020501' ]    # '20010101' <= date <= '20020501'

If you remove '20020501' from the interval, you get a half-open interval.
The open side is written with parenthesis.

    [ '20010101' .. '20020501' )    # '20010101' <= date < '20020501'

If you remove '20010101' and '20020501' from the interval, you get an open interval.

    ( '20010101' .. '20020501' )    # '20010101' < date < '20020501'

=cut

#----- end POD intro



=head1 "NEW" API

=cut



=head1 SUBROUTINE METHODS

These methods perform everything as side-effects to the object's data structures.
They return the object itself, modified.

=head2 event HASH

    $a->event ( rule => $rule );
    $a->event ( at => $date );
    $a->event ( start => $start, end => $end );

    $a = Date::Set->event ( at => $date );    # constructor

=over 4

=item Timeline diagram to explain 'event' effect

 parameter contents:

    $a = .........[**************]...................   # period
    $b = ................[****************]..........   # period
    $c = ............................[***********]...   # period

 $a->event( at => $b )

    $a = .........[***********************]..........   # bigger period

 $a->event( at => $c )

    $a = .........[**************]...[***********]...   # two periods

=back

Inserts events in a Date::Set. Use 'event' to create or enlarge a Set.

Calling 'event' without parameters returns 'forever', that is: (-Inf .. Inf)

=over 4

=item rule

adds the dates from a recurrence rule, as defined in RFC2445.

This is a simple list of dates. These dates are not 'periods', they have no duration.

    $a->event( rule => 'FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3' );

Optimization tip: rules that have start/end dates might execute faster. 

A rule might have a DTSTART: 

    $a->event( rule => 'DTSTART=19990101Z;FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3' );

    $a->event( dtstart => '19990101Z', rule => 'FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3' );

=item at

adds more dates or periods to the set

    $a->event( at => '19971024T120000Z' );      # one event

    $a->event( at => [ '19971024T120000Z', '19971025T120000Z' ] );  # a period

    $a->event( at => $set );                    # one Date::Set

    $a->event( at => [ $set1, $set2 ] );        # two Date::Sets

    $a->event( at => [ [ '19971024T120000Z', '19971025T120000Z' ] ] );  # one period

    $a->event( at => [ [ '19971024T120000Z', '19971025T120000Z' ],
                       [ '19971027T120000Z', '19971028T120000Z' ] ] );  # two periods

If 'rule' is used together with 'at' it will
add the recurring events that are inside that period only.
The period is a 'boundary':

    $a->event( rule  => 'FREQ=YEARLY',
               at    => [ [ '20010101', '20030101' ] ] );    # 2001, 2002, 2003

=item start, end

add a time period to the set:

    $a->event( start => '19971024T120000Z' );  # one period that goes forever until +infinity

    $a->event( end   => '19971025T120000Z' );  # one period that existed forever since -infinity

    $a->event( start => '19971024T120000Z', 
               end   => '19971025T120000Z' );  # one period

if 'at' is used together with 'start'/'end' it will
add the periods that are inside that boundaries only:

    $a->event( at    => [ [ '20010101', '20090101' ] ],
               end   => '20020101' );                      # period starting 2001, ending 2002

    $a->event( at    => [ [ '20010101', '20090101' ] ],
               start => '20070101' );                      # period starting 2007, ending 2009

if 'rule' is used together with 'start'/'end' it will
add the recurring events that are inside that boundaries only:

    $a->event( rule  => 'FREQ=YEARLY',
               start => '20010101', 
               end   => '20030101' );                       # 2001, 2002, 2003

you can mix 'at' and 'start'/'end' boundary effects to 'rule':

    $a->event( rule  => 'FREQ=YEARLY',
               at    => [ [ '20010101', '20090101' ] ],
               end   => '20020101' );                       # 2001, 2002

=item Timeline diagram to explain 'event' effect with bounded recurrence rule

 parameter contents:

    $a = .........[**************]...................   # period
    $b = ................[****************]..........   # period
    $r = ...*...*...*...*...*...*...*...*...*...*...*   # unbounded recurrence rule

 $a->event( rule => $r, at => $b )

    $a = .........[**************]..*...*............   # period and two occurrences

=back

=cut

sub event {
    my $self = shift;
    my $set = $self->fevent(@_);
    # my $class = ref($self) || $self;
    if (ref($self)) {
        # copy result to self (can't use "copy" method here)
        %$self = ();
        foreach my $key (keys %{$set}) {
            $self->{$key} = $set->{$key};
        }
    }
    return $set;
}


=head2 exclude HASH

=head2 during HASH

    $a->exclude ( at => $date );
    $a->exclude ( rule => $rule );
    $a->exclude ( start => $start, end => $end );

    $a->during ( at => $date );
    $a->during ( rule => $rule );
    $a->during ( start => $start, end => $end );

=over 4

=item Timeline diagram to explain 'exclude' and 'during' effect

 parameter contents:

    $a = .........[**************]...................
    $b = ................[****************]..........

 $a->exclude( at => $b )

    $a = .........[******)...........................

 $a->during( at => $b )

    $a = ................[*******]...................

=back

Calling 'exclude' or 'during' without parameters returns 'never', that is: () the empty set.

'exclude' excludes events from a Date::Set

'during' put start/end boundaries on a Date::Set

In other words: 'exclude' cuts out everything that MATCH it, and  
'during' cuts out everything that DON'T match it.

Use 'exclude' and 'during' to limit a Set size.
You can use 'exclude' and 'during' to put boundaries on an infinitely recurring Set.

=over 4

=item at

    $a->exclude( at => '19971024T120000Z' );

    $a->exclude( at => $set );

    $a->during( at => [ '19971024T120000Z', '19971025T120000Z' ] );  # a period

    $a->during( at => [ $set1, $set2 ] );

'exclude at' deletes these dates from the set

'during at' limits the set to these boundaries only. 

=item rule

a recurrence rule as defined in RFC2445

    $a->exclude( rule => 'FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3' );

    $a->during( rule => $rule1 );

'exclude rule' deletes from the set all the dates defined by the rule.
The RFC 2445 states that the DTSTART date will not be excluded by a rule, so it isn't. 

'during rule' limits the set to the dates defined by the rule. If the set does not
contain any of the dates, it gets empty

=item start, end

a time period

    $a->exclude( start => '19971024T120000Z', end => '19971025T120000Z' );

    $a->during( start => '19971024T120000Z' );  # limit to forever from start until +infinity

    $a->exclude( end => '19971025T120000Z' );   # delete everything since -infinity until end

'exclude start' deletes from the set all dates including 'start' and after it 

'exclude end' deletes from the set all dates before and including 'end' 

'exclude start,end' deletes from the set all dates between and including 'start' and 'end' 

'during start' limits the set to the dates including 'start' and after it. If there are
no dates after 'start', the set gets empty.

'during end' limits the set to the dates before and including 'end'. If there are
no dates before 'end', the set gets empty.

'during start,end' limits the set to the dates between and including 'start' and 'end'. 
If there are no dates in that period, the set gets empty.

=back

=cut


sub during {
    my $self = shift;
    # my $class = ref($self) || $self;

    my $set = $self->fduring(@_);
    # carp " self $self ; set $set ";

    if (ref($self)) {
        # carp " return self+set ";
        # copy result to self (can't use "copy" method here)
        %$self = ();
        foreach my $key (keys %{$set}) {
            $self->{$key} = $set->{$key};
        }
    }
    return $set;  # as a constructor, it is the same as 'event'
}

sub exclude {
    my $self = shift;
    # my $class = ref($self) || $self;

    my $set = $self->fexclude(@_);
    # carp " self $self ; set $set ";

    if (ref($self)) {
        # carp " return self+set ";
        # copy result to self (can't use "copy" method here)
        %$self = ();
        foreach my $key (keys %{$set}) {
            $self->{$key} = $set->{$key};
        }
    }
    return $set; 
}




=head2 wkst STRING

    Date::Set::wkst('SU');    # global change

    $set->wkst('MO');

Sets/reads the "week start day". 

The parameter must be one of 
'MO' (default), 'TU', 'WE', 'TH', 'FR', 'SA', or 'SU'.

The effect if to change the 'week' boundaries. 
It also changes when the first week of year begins, affecting 'weekyear' operations.

It has no effect on 'weekday' operations, like 'first tuesday of month' or
'last friday of year'.

Return value is current wkst value.

=cut

# wkst works locally too, if applied to an object

sub wkst {
    my $class = shift;
    my $value = shift;
    $value = $class unless defined $value;
    if (ref($class)) {
        # carp " $class:",$class->{wkst}," => ", defined $value , ":$value ";
        $class->{wkst} = uc($value) if (defined $value) and ($value =~ /^\w\w$/);
        return $class->{wkst};
    }
    # carp " $class:$WKST => ", defined $value , ":$value ";
    $WKST = uc($value) if (defined $value) and ($value =~ /^\w\w$/);
    return $WKST;
}

=head1 FUNCTION METHODS

These methods perform operations and return the changed data. 
They return a new object. The original object is never modified.
There are no side-effects.

=head2 fevent, fexclude, fduring HASH

    $b = $a->fevent ( at => $date,
                      date_set => $set,
                      rule => $rule,
                      start => $start, end => $end );

Functions equivalent to event() , exclude() , and during() subroutines.

These functions return a new Date::Set. They DON'T MODIFY the object, as
the subroutines event/exclude/during do.

    $b = $a->fevent ( at => $date );

is the same as:

    $b = $a->copy;
    $b->event ( at => $date );

=cut

sub fevent {
    my $self = shift;
    my %parm = @_;
    my $set;
    # $self = $self->new() unless ref($self);
    # my $class = ref($self) || $self;
    # carp " class: $class [ $parm{start} .. $parm{end} ]";

    # carp " fevent " . join(".", %parm);

    # some optimization to find out what to do 
    my $has  = 0;
    $has |= 1 if exists $parm{start};
    $has |= 2 if exists $parm{end};
    $has |= 4 if exists $parm{at};     
    $has |= 8 if exists $parm{rule};

    # carp " has $has ";

    # set default parameters
    %parm  = (
        start   => $PAST,
        end     => $FUTURE,
        at      => undef,
        rule    => '',
        dtstart => undef,
        exclude_dtstart => 0,   # DTSTART is included in RRULE, but not in EXRULE
        %parm
    );

    # carp " fevent " . join(".", %parm);

    # check for deprecated parameters
    if ( exists $parm{'default'} ) {
        carp $self . "-> event-default deprecated";
    }

    # carp "fevent $has";

    # if ($has == 0) {
    #    # start
    #    # carp " SELF $self ".$self->new(-$inf, $inf);
    #    return $self->new(-$inf, $inf) unless ref($self);
    #   return $self;
    # }
    if ($has == 1) {
        # start
        return $self->new($parm{start}, inf) unless ref($self);
        $set = $self->intersection($parm{start}, inf );
    }
    elsif ($has == 2) {
        # end
        return $self->new(-&inf(), $parm{end}) unless ref($self);
        $set = $self->intersection(-&inf(), $parm{end} );
    }
    elsif ($has == 3) {
        # start + end
        return $self->new($parm{start}, $parm{end}) unless ref($self);
        $set = $self->intersection($parm{start}, $parm{end} );
    }
    elsif ($has == 4) {
        # at
        # carp " $self at $parm{at}"; 
        return $self->new($parm{at}) unless ref($self);
        $set = $self->union($parm{at});
        # carp " set $set";
    }
    elsif ($has == 8) {
        # rule
        $self = $self->new(-&inf(), inf) unless ref($self);
        $set = $self->recur_by_rule(
            rrule => $parm{rule}, 
            dtstart => $parm{dtstart}, 
            exclude_dtstart => $parm{exclude_dtstart} );
    }
    elsif ($has == 9) {
        # rule + start
        $self = $self->new($parm{start}, inf) unless ref($self);
        $set = $self->recur_by_rule(
            rrule => $parm{rule}, 
            dtstart => $parm{dtstart},     
            exclude_dtstart => $parm{exclude_dtstart} );
    }
    elsif ($has == 10) {
        # rule + end
        $self = $self->new(-&inf(), $parm{end}) unless ref($self);
        $set = $self->intersection(-&inf(), $parm{end} )
            ->recur_by_rule(
                rrule => $parm{rule}, 
                dtstart => $parm{dtstart}, 
                exclude_dtstart => $parm{exclude_dtstart} );
    }
    else {
        # combined parameters
        $self = $self->new() unless ref($self);
        # carp " self $self ";

        my $start = $parm{start};
        my $end   = $parm{end};
        my $rule_start_end = $self->new( $start, $end );
        # carp " rule_start_end $rule_start_end";

        my $rule_at;
        # $parm{at} = [ $parm{at} ] if ref($parm{at}) ne 'ARRAY';
        if ( $parm{at} ) {
            # carp " AT $parm{at}";
            $rule_at = $self->new($parm{at});
        }
        else {
            # carp " NO AT ";
            $rule_at = $self->new(-&inf, inf);
        }
        # carp " rule_at $rule_at";

        # if (ref($parm{at}) ne 'ARRAY') {
        #    $rule_at = $self->new($parm{at});
        # }
        # elsif ($#{$parm{at}} >= 0) {
        #    my $at = $self->new();
        #    foreach (@{$parm{at}}) {
        #        $at = $at->union($_); 
        #    }
        #    $set = $set->intersection($at);
        # }

        $set = $rule_at->union($self)->intersection($rule_start_end);

        # carp " start+end+at = $set";

        if ($parm{rule}) {
            # my $max = $set->max;
            # $dtend = $max if $max < $dtend;
            # $dtstart = $set->min if $parm{start} == $PAST;

            # my $period = $self->new( $dtstart, $dtend );
            # carp "\n period: $period " . ref($period) . " ";
            # carp " rule: $parm{rule} ";
            my $rule = $set->recur_by_rule(
                rrule => $parm{rule}, 
                dtstart => $parm{dtstart}, 
                # period => $period,
                exclude_dtstart => $parm{exclude_dtstart} );
            $set = $set->intersection($rule);
        }
    }

    # carp " result self $self ; set $set ";

    # if (ref($self) ) {
    #    # carp " return self+set $self + $set";
    #    # $set = $self->union($set);
    # }
    return $set;
}


sub fduring {
    my $self = shift;
    # my $class = ref($self) || $self;
    my $set = __PACKAGE__->fevent(dtstart => $self->{dtstart}, @_);  # $self->new()-> ??
    if (ref($self) ) {
        # carp " during: intersection $self + $set";
        $set = $self->intersection($set);
    }
    # carp " during: $set ";
    return $set;  
}

sub fexclude {
    my $self = shift;
    # my $class = ref($self) || $self;
    # carp " fexclude " . join('.', @_);
    my $set = __PACKAGE__->fevent( exclude_dtstart => 1, dtstart => $self->{dtstart}, @_);  # $self->new()-> ??
    if (ref($self)) {
        # carp " exclude: $set ";
        $set = $self->intersection($set) if $set->is_too_complex;
        # carp " exclude intersection: $set ";
        $set = $self->complement($set);
        # carp " exclude result: $set ";
    }
    return $set; 
}


=head1 "OLD" API

=cut


#  _print
#
# Internal debugging method. Prints set contents as it is being processed.
#
# It works only if $DEBUG is set. 
#

# =head2 print
#
# Deprecated. 
#
# =cut

sub _print {
    my ( $self, %parm ) = @_;
    print "\n $parm{title} = ", $self->fixtype, "\n" if $DEBUG;
    return $self;
}

=head2 period

Deprecated. Replaced by 'event'. 

    period( time => [time1, time2] )

    or

    period( start => Date::ICal,  end => Date::ICal )

This routine is a constructor. Returns a time period bounded by
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

        # TODO: "time[]" is 'un-deprecated' until we fix the tests - Flavio

        # carp "$self -> period ( time => [a,b] calling convention deprecated.\n ".
        # "Please use start and end parameters instead";
        $self = $class->new( $parm{time}[0], $parm{time}[1] );
    }
    $self->_print( title => 'period ' . join ( ':', %parm ) ) if $DEBUG;
    return $self;
}

=head2 dtstart

Sets DTSTART time. 

    dtstart( start => time1 )

Returns set intersection [time1 .. Inf)

time1 is added to the set.

'dtstart' puts a limit on when the event starts. 
If the event already starts AFTER dtstart, it will not change. 

This is a function. It doesn't change the object.

=cut

sub dtstart {    # start
    my ( $self, %parm ) = @_;
    unless (ref($self)) {
        # constructor
        $self = $self->new( $parm{start}, $FUTURE );
        $self->{dtstart} = $parm{start};
        return $self;
    }
    $self->_print( title => 'dtstart ' . join ( ':', %parm ) ) if $DEBUG;
    my $dt = $self->copy;
    $dt->{dtstart} = $parm{start};
    # print " dtstart $self->{dtstart}\n";
    # print " dtstart-i ", $self->intersection( $parm{start}, $FUTURE )->{dtstart},"\n";
    return $dt->intersection( $parm{start}, $FUTURE )->union( $parm{start} );

    # my $tmp = __PACKAGE__->new($parm{start}, $FUTURE);
    # return $self->intersection($tmp);
}

=head2 dtend

Deprecated. Replaced by 'event/during'. 

    dtend( end => time1 )

Returns set intersection (Inf .. time1]

'dtend' puts a limit on when the event finishes. 
If the event already finish BEFORE dtend, it will not change.

=cut

sub dtend {    # end
    my ( $self, %parm ) = @_;
    $self->_print( title => 'dtend ' . join ( ':', %parm ) ) if $DEBUG;
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
    $self->_print( title => 'duration' ) if $DEBUG;
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

Deprecated. Replaced by 'event'. 

=cut

<<__internal_docs__;

    recur_by_rule ( period => date-set,  DTSTART => time,
        BYMONTH => [ list ],     BYWEEKNO => [ list ],
        BYYEARDAY => [ list ],   BYMONTHDAY => [ list ],
        BYDAY => [ list ],       BYHOUR => [ list ],
        BYMINUTE => [ list ],    BYSECOND => [ list ],
        BYSETPOS => [ list ],
        UNTIL => time, FREQ => freq, INTERVAL => n, COUNT => n,
        WKST => day,
        RRULE => rrule-string,
        include_dtstart => 1,
        exclude_dtstart => 0 )

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

DTSTART must be given explicitly. 
In older versions of this module DTSTART would be taken 
from 'period' or from the set.


NOTE: "DTSTART" is *ALWAYS* included in the recurrence set,
whether or not it matches the rule. Use "include_dtstart => 0" to
override this. Use "exclude_dtstart => 1" to *NEVER* include "DTSTART"
value in the set.

NOTE: Some recurrences may give very big or even infinity sized sets.
The current implementation does not detect some of these cases and they might crash
your system.

NOTE: The RFC specifies that FREQ is *not* optional.

There are two operating modes: without 'period' it will filter out the rule from the set;
with 'period' it will filter out the rule from the period, then add the list to the set.

The datatype for 'period' is Date-Set.

=cut
__internal_docs__

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
    my $return = shift;
    my ($rrule) = $$return{RRULE}; 

    return unless defined $rrule;
    # print "  RULE: [ $rrule ]\n";

    # RRULEs look like 'FREQ=foo;INTERVAL=bar;' etc.
     my @pieces = split(';', $rrule);
     foreach (@pieces) {
         my ($name, $value) = split("=", $_);
       
        # BY<FOO> parameters should be arrays. everything else should be strings
         if ($name =~ /^BY/i) {
            @{$$return{$name}} = split(/,/,$value);
         }
         else {
            $$return{$name} = $value;
         }
     }
}

sub recur_by_rule {
    my $self = shift;

    # $self = $self->numeric;
    # carp "recur_by_rule $self";

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
        COUNT    => $inf, 
        UNTIL    => undef,
        # WKST     => $WKST,
        RRULE    => undef,
        PERIOD   => undef, 
        DTSTART  => undef,
        INCLUDE_DTSTART => 1,  # *ALWAYS* include DTSTART in result set
		EXCLUDE_DTSTART => 0,  # DON'T remove DTSTART from result set
        @parm,
    );

    my ( $rrule, %has );
    if (exists $parm{'RRULE'}) {
        _parse_rule(\%parm); # parse an RRULE out into its pieces.
        undef $parm{'RRULE'};
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
    # my $class = ref($self);

    # set our {dtstart} if defined
    # print " dtstart is $parm{DTSTART} , was $self->{dtstart} \n";
    # later! ---> $self->{dtstart} = $parm{DTSTART}   if defined $parm{DTSTART};
    # ... and vice-versa


    $self = $self->numeric;
    $parm{PERIOD} = $parm{PERIOD}->numeric if defined $parm{PERIOD};


    $parm{DTSTART}   = $self->{dtstart} 
        if defined $self->{dtstart} and not defined $parm{DTSTART};
    $parm{DTSTART}   = $parm{PERIOD}->{dtstart} 
        if ref($parm{PERIOD}) and defined $parm{PERIOD}->{dtstart} and not defined $parm{DTSTART};
    $parm{DTSTART}   = $self->new( $parm{DTSTART} )->min 
        if defined $parm{DTSTART};
    $parm{DTSTART_save} = $parm{DTSTART};   

    # print " dtstart is $parm{DTSTART} , was $self->{dtstart} \n";

    # $DEBUG = 1;

    # Try to find out what 'period' the rrule is talking about
    if ( defined $parm{PERIOD} ) {
        $has{period} = 1;
        print " PERIOD: $parm{PERIOD} \n" if $DEBUG;
        # try to make $self smaller

        # TODO: test for too_complex PERIOD? (we test $self later)
        $self = $self->intersection( $parm{PERIOD} );

        print "  self intersected with period\n" if $DEBUG;
    }
    else {
        $has{period}  = 0;
        print " NO PERIOD\n" if $DEBUG;
        # try to make a period from DTSTART and $self
        if ( defined $parm{DTSTART} ) {
            # make sure DTSTART is the right type
            #    this could be more efficient...
            $parm{DTSTART} = $self->new( $parm{DTSTART} )->min;
            # apply DTSTART, just in case
            $self = $self->intersection( $parm{DTSTART}, $FUTURE );
            print " NEW PERIOD: $self \n" if $DEBUG;

            # if we have "COUNT" we must start at DTSTART
            if ( defined $parm{DTSTART_save} ) {
                # print "  ( $parm{DTSTART_save} < $self->min )  \n";
                if ( ( $parm{DTSTART_save} < $self->min ) and 
                     ($parm{COUNT} < $inf) ) {
                    $self = $self->union( $parm{DTSTART_save}, $self->min );
                }
                if ( $parm{DTSTART_save} > $self->min ) {
                    $self = $self->intersection( $parm{DTSTART_save}, $inf );
                }
            }

        }
        else {
            print " NO DTSTART \n" if $DEBUG;
        }
    }

    # carp " PERIOD $parm{PERIOD} ";
    # $DEBUG = 0;

    print "  test until\n" if $DEBUG;
    # UNTIL and COUNT MUST NOT occur in the same 'recur'  (why?)
    if ( $parm{UNTIL} ) {
        # UNTIL
        $self->_print( title => 'UNTIL' ) if $DEBUG;
        $self = $self->intersection( $PAST, $parm{UNTIL} );
    }

    # this is the backtracking interface.
    # It allows the program to defer processing if it does not have enough
    # information to proceed.
    # print "  testing self $self  min = ",$self->min," max = ",$self->max, "\n";
    if ( ( $self->{too_complex} )
        or ( $self->min and $self->min == -&inf )
        or ( $self->max and $self->max == &inf ) )
    {

        my $b = $self->new();
        $self->trace( title => "rrule:backtrack" );
        print " BACKTRACKING \n" if $DEBUG;

        # print " [rrule:backtrack] \n" if $DEBUG_BT;
        $b->{too_complex} = 1;
        $b->{parent}      = $self->copy;
        $b->{method}      = 'recur_by_rule';
        $b->{param}       = [%parm];

        # TODO: set up {min} and {max}, if possible...


        # now that we have a "function" we can try to find a valid subset 
        #    if we have a COUNT
        if (exists $parm{COUNT}  &&
            exists $parm{FREQ}   &&
            ($parm{COUNT} != &inf) &&
            ($self->min   != -&inf)
           ) {
            # warn "we have COUNT=$parm{COUNT} INTERVAL=$parm{INTERVAL} and start=".$self->min." and FREQ=$parm{FREQ}";
            my $count = $parm{COUNT} * $parm{INTERVAL};
            my $try = $self->new( $self->min )->
                offset( unit => $FREQ{$parm{FREQ}}, value => [0,$count] );
            # warn "set = $try";
            my $subset = $b->intersection($try);
            # warn "subset = $subset";
            my $size = 1 + $#{$subset->{list}};
            if ( $size == $parm{COUNT} ) {
                # warn "success: $size / $parm{COUNT}";
                return $subset;
            }
            # TODO: if we were sure we never fail we wouldn't have to use backtracking
            # warn "failed: $size / $parm{COUNT}";
        }


        # try to make a subset suitable for first() iteration
        # warn "trying 'first': ";
        if (exists $parm{FREQ}   &&
            ($self->min   != -&inf)
           ) {
            # warn "we have COUNT=$parm{COUNT} INTERVAL=$parm{INTERVAL} and start=".$self->min." and FREQ=$parm{FREQ}";
            my $count = $parm{INTERVAL};
            my $try = $self->new( $self->min )->
                offset( unit => $FREQ{$parm{FREQ}}, value => [0,$count] );
            $try->{list}[0]{open_end} = 1;
            # warn "\n    set = $try";
            my $subset = $b->intersection($try);
            # warn "\n    subset = $subset";
            my $size = 1 + $#{$subset->{list}};
            if ( $size > 0 ) {

                # warn "\n    self: $self \n    parm: ".join(' ', map { "$_=$parm{$_}" } keys %parm );

                # move $self ahead
                $b->{parent} = $b->{parent}->complement($try);
                @{$b->{min}} = $try->max_a;
                # warn "    parent: ".$b->{parent};

                return $subset->union($b);
            }
            else {
                # warn "failed: 'first' $size";
            }
        }


        return $b;
    }

    print "  self numeric\n" if $DEBUG;
    $self = $self->numeric;   # again?
    # $parm{PERIOD} = $parm{PERIOD}->numeric if $has{period};
    # $parm{DTSTART} = $parm{DTSTART}->numeric if defined $parm{DTSTART};

    # -- don't do this before backtracking!
    $parm{PERIOD} = $self unless $has{period};

    my $when = $parm{PERIOD};

    # print " PARAMETERS: ", join(":", %parm), "\n";

    $when->_print( title => 'WHEN' ) if $DEBUG;

    $parm{WKST} = $self->{wkst} unless defined $parm{WKST};

    if ( $parm{FREQ} ) {

        # FREQ, INTERVAL & COUNT

        # $DEBUG = 1;

        $when->_print( title => 'FREQ' ) if $DEBUG;

        if ( $self->max == $inf ) {

            # TODO
            # that's real hard to quantize -- try to fix it
            # should try to find out from DTEND, UNTIL, COUNT, etc. 

        }

        # -- FREQ handling
        # TODO: can we rename $freq to something more obvious?
        my $freq_unit = $FREQ{ $parm{FREQ} };
        my $freq = $when->quantize( unit => $freq_unit, strict => 0, fixtype => 0 );
        $freq->_print( title => 'FREQ' ) if $DEBUG;

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

        $when->_print( title => 'WHEN (before INTERVAL, COUNT)' ) if $DEBUG;

        # -- end FREQ handling


        # -- INTERVAL handling
        if ($parm{INTERVAL} > 1) {
            $freq = $freq
              # -- INTERVAL works here:
              ->select( freq => $parm{INTERVAL}, count => $inf, strict => 0 );
            # carp "INTERVAL $parm{INTERVAL}";
            $freq->_print(
                title => 'FREQ('
                  . $parm{FREQ}
                  . ')+INTERVAL('
                  . $parm{INTERVAL} . ')'
              )->compact if $DEBUG;
        }

        # -- BYSETPOS special handling -- 
        # BYSETPOS works for each FREQ subset, so we have to 'iterate'
        # over 'FREQ'
        if ( exists $parm{BYSETPOS} ) {
            print " [ENTERING ITERATE->RRULE]\n" if $DEBUG;
            $freq = $freq->iterate(
                sub {
                    $_[0]->_print( title => 'PART-' . $parm{FREQ} ) if $DEBUG;
                    my $tmp = $_[0]->_rrule_by( \%parm , \%has );
                    $tmp->_print( title => 'PART-done:' ) if $DEBUG;
                    return $tmp;
                  }
              )
        }
        else {
            print " [ENTERING RRULE]\n" if $DEBUG;
            $freq = $freq->_rrule_by( \%parm , \%has );
        }

        $freq->_print( title => 'FREQ (after INTERVAL, RRULE)' ) if $DEBUG;

        $rrule = $when->intersection( $freq
              ->_apply_DTSTART( \%parm , \%has )

              # remove anything out of range before counting!
              ->intersection( $parm{PERIOD} )

              # -- COUNT works here:
              ->select( freq => 1, count => $parm{COUNT}, strict => 0 )
              # ->_print( title => 'COUNT(' . $parm{COUNT} . ')' )

              # ->duration( unit => 'seconds', duration => 0 ) 
              ->offset(mode=>'begin', value=>[0,0])
        );
    } else {

        # is this in the RFC?
        # probably not, but we can try to find an answer anyway

        $when->_print( title => 'no FREQ or UNTIL' ) if $DEBUG;
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
    if (defined $parm{DTSTART_save} ) {
        $rrule = $rrule->union( $parm{DTSTART_save} ) if $parm{INCLUDE_DTSTART};
        $rrule = $rrule->complement( $parm{DTSTART_save} ) if $parm{EXCLUDE_DTSTART};
    }

    # carp " returning $self ";
    # carp "       and $rrule ";
    # carp "        as " . $rrule->fixtype ;
    # carp "       and " . $self->fixtype ;

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

    return $when unless defined $parm{DTSTART_save};

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
                  # ->_print( title => $BYfoo . ":quantize=" . $big_unit )
                  ->offset(
                    mode   => 'circle',
                    unit   => $small_unit,
                    value  => [@by],
                    strict => 0,
                    fixtype => 0 )
                  # ->_print( title => $BYfoo . ":offset=" . $small_unit . join ( ',', @by ) )
             )->no_cleanup;
            $when->_print( title => $BYfoo ) if $DEBUG;
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
                  # ->_print(title=>'weeks')
                  ->offset(
                    mode   => 'circle',
                    unit   => 'days',
                    value  => [@by],
                    strict => 0,
                    fixtype => 0
                  );
            $non_indexed->_print( title => 'BYDAY' ) if $DEBUG;
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
                $weekday->_print( title => "WEEKDAYS: $day " ) if $DEBUG;
                $weekday = $weekday->offset( 
                    mode => 'circle', 
                    unit => 'days', 
                    value => [ $index * 7, $index * 7 + 1 ] );
                $weekday->_print( title => "DAYS: $index weeks" ) if $DEBUG;
                $indexed = $indexed->union( $weekday );
                $indexed->_print( title => 'BYDAY-INDEX:' . $index . ',' . $day ) if $DEBUG;
            }
        }
        else {
            $indexed = $NEVER;
        }

        # mix indexed with non-indexed days
        $when = $BYDAY->intersection(
                    $non_indexed->union($indexed)
                )->no_cleanup;
        $when->_print( title => 'BYDAY' ) if $DEBUG;

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
            $when->_print( title => 'before ' . $BYx ) if $DEBUG;
            $when = $when->intersection(
                $when->quantize(
                    unit => $prev_unit,
                    strict => 0,
                    fixtype => 0 )
                 ->offset(
                    mode   => 'circle',
                    unit   => $has,
                    value  => [@by],
                    strict => 0, fixtype => 0 )
             )->no_cleanup;
            $when->_print( title => $BYx ) if $DEBUG;
            $has{$has} = 1;
        }
    } # end: foreach h/m/s
    # }}}

    # {{{ if exists BYSETPOS

    if ( exists $parm{BYSETPOS} ) {
        my @by = @{ $parm{BYSETPOS} };
        foreach (@by) { $_-- if $_ > 0 }    # BY starts in 1; perl starts in 0
        # $when = $when->intersection( 
        #   $when->compact
        #   # ->_print(title=>'bysetpos1')
        #   ->select( by => [@by] )
        #   # ->_print(title=>'bysetpos2')
        # )->no_cleanup;
        $when->_print( title => 'BYSETPOS' ) if $DEBUG;

        $when = $when->select( by => [@by] );
        # carp " When: $when ";
    }
    # }}} 

    # }}}

    %{$_[2]} = %has;
    return $when;
}

=head2 exclude_by_rule

Deprecated. Replaced by 'exclude'. 

=cut

<<__internal_docs__;

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
__internal_docs__


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
        $b->{parent}      = $self->copy;
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
    return $self->numeric->complement( $period->recur_by_rule(%parm) )->fixtype;
}

=head2 recur_by_date

Deprecated. Replaced by 'event'. 

=cut
<<__internal_docs__;

    recur_by_date( list => [time1, time2, ...] )

Adds the (scalar) list to the set, or creates a new list.

This Date::Set will recur on each item of the list provided.
This method lets you add items to a set of dates. If you
call it multiple times, entries from previous calls will
be preserved. If you need to delete them again, use exclude_by_date.

=cut
__internal_docs__


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
    $self->_print( title => 'recur_by_date ' . join ( ':', %parm ) ) if $DEBUG;
    return $self;
}

=head2 exclude_by_date

Deprecated. Replaced by 'exclude'. 

=cut
<<__internal_docs__;

    exclude_by_date( list => [time1, time2, ...] )

Removes each element of the list from the set.

=cut
__internal_docs__


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
    $self->_print( title => 'exclude_by_date ' . join ( ':', %parm ) ) if $DEBUG;

    # parse an EXRULE out into its pieces.
    # if ($parm{'EXRULE'} ) {
    #    my %temp_parm = _parse_rule($parm{'EXRULE'}); 
    #    %parm = (%parm, %temp_parm);
    # } 

    return $self;
}

=head2 occurrences

Deprecated. Replaced by 'during'. 

=cut
<<__internal_docs__;

    occurrences( period => date-set )

Returns the occurrences for a given period. In other words,
"when does this event occur during the given period?"

=cut
__internal_docs__


sub occurrences {    # event->, period
    my $self = shift;
    my %parm = @_;
    
    unless ($parm{'period'}) {
        carp "$self -> occurrences called without a period argument";
    }

    my $intersection =  $self->numeric->intersection( $parm{period}->numeric );
    return($intersection)->fixtype;
}

=head2 next_year, next_month, next_week, next_day, next_hour, next_minute, next_weekyear ($date_set)

=head2 this_year, this_month, this_week, this_day, this_hour, this_minute, this_weekyear ($date_set)

=head2 prev_year, prev_month, prev_week, prev_day, prev_hour, prev_minute, prev_weekyear ($date_set)

    $next  = next_month( $date_set ) 
    $whole = this_year ( $date_set )    # [20010101..20020101)

Returns the next/prev/this unit of time for a given period. 

It answers questions like,
"when is next month for the given period?",
"which years are covered by this period?"

=cut


=head2 as_years, as_months, as_weeks, as_days, as_hours, as_minutes, as_weekyears ($date_set)

    as_months( date-set ) 
    as_weeks ( date-set ) 

Returns the given period in a 'unit of time' form. 

It answers questions like,
"which months we have in this period?",
"which years are covered by this period?"

See also previous note on 'weekyear' in 'About ISO 8601 week'.

=cut

sub DESTROY {}

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


1;

__END__

=head1 INHERITED 'SET LOGIC' FUNCTIONS

These methods are inherited from Set::Infinite.

=head2 intersects

    $logic = $a->intersects($b);

=head2 contains

    $logic = $a->contains($b);

=head2 is_null

    $logic = $a->is_null;

=head2 is_too_complex

Sometimes a set might be too complex to print. 
It will happen when you ask for 'every year' (a recurrence) but don't specify
a starting and ending date.

    $recurr = Date::Set->event( rule = 'FREQ=YEARLY' );  
    print $recurr;                   # "Too Complex" 
    print $recurr->is_too_complex;   # "1"
    $recurr->during( start => '20020101', end => '20050101' );
    print $recurr;                   # "20020101,20030101,20040101,20050101"
    print $recurr->is_too_complex;   # "0"

=cut


=head1 INHERITED 'SET' FUNCTIONS

These methods are inherited from Set::Infinite.

=head2 union

    $i = $a->union($b);     

=head2 intersection

    $i = $a->intersection($b);

=head2 complement

    $i = $a->complement;

    $i = $a->complement($b);

=head1 INHERITED 'SPECIAL' FUNCTIONS

These methods are inherited from Set::Infinite.

=head2 min, max

Returns the 'begin' or 'end' of a set. 
'date_ical' function returns the actual Date::ICal object they point to.

    $date1 = $set1->min->date_ical;    # the first Date::ICal object in the set

    $date2 = $set1->max->date_ical;    # the last Date::ICal object in the set

Warning: modifying an object data might break your program.

=head2 list

Splits a set in simpler, 1-period sets.

    print $set1;              #  [20010101..20020101],[20030101..20040101]
    @subset = $set1->list;
    print $subset[0];         #  [20010101..20020101]
    print $subset[1];         #  [20030101..20040101]

    print $subset[0]->min->date_ical;    # 20010101
    print $subset[0]->max->date_ical;    # 20020101

This shortcut might work for simple sets, but you should avoid it:

    print $set1->{list}->[0]->min->date_ical;    # 20010101 - DON'T DO THIS

Complex sets might take a long time (and a lot memory) to 'list'. 

Unbounded recurrences should not be list'ed, because they generate infinite
or even invalid (empty) lists. If you are not sure what type of set you
have, you can test it with is_too_complex() function.

=head2 size

=head2 offset

=head2 select

=head2 quantize

=head2 iterate

=head2 new

See Set::Infinite documentation.

=head2 copy

    $b = $a->copy;

Returns a copy of the object.

This is useful if you want to use one of the subroutine methods, without 
changing the original object.

=cut


=head1 COOKBOOK

=head2 Create a new, empty set

    $a = Date::Set->new();

    $a = Date::Set->event( at => [] );

    $a = Date::Set->during();

=head2 Exclude a date from a set

TODO

=head2 Adding a whole year

    $year = Date::Set->event( at => '20020101' );
    $a->event( at => (  $year->as_years ) );

This is not the same thing, since it includes a bit of next year:

    $a->event( start => '20020101', end => '20030101' );

This is not the same thing, since it misses a bit of this year (a fraction of last second):

    $a->event( start => '20020101', end => '20021231T235959' );

=head2 Using 'during' and 'exclude' to put boundaries on a recurrence

    $a->event( rule => 'FREQ=YEARLY;INTERVAL=2' );
    $a->during( start => $today, end => $year_2020 );

    $a->event( rule => 'FREQ=YEARLY;INTERVAL=2' );
    $a->exclude( end => $today);
    $a->exclude( start => $year_2020 );

=head2 Application of this/next/prev

TODO


=head1 API INSTABILITIES

These are more likely to change:

    - Some method and parameter names may change if we can find better names.

    - support to next/prev/this and as_xxx MAY be deleted in future versions
      if they don't prove to be useful.

    - 'duration' and 'period' methods MAY change in future versions, to generate open-ended sets.
    Possibly by using parameter names 'after' and 'before' instead of 'start' and 'end' 

    - accepting timezones

    - use more of Date::ICal methods for time calculations

Some behaviour is yet undefined:

    - what happens when asked for '31st day of month', when month has less
    than 31 days?

    - does it work when using fractional seconds?

These might change, but they are not likely:

    - Accepting string dates MAY be deleted in future versions. 

=cut


=head1 AUTHOR

Flavio Soibelmann Glock <fglock@pucrs.br> 
with the Reefknot team.

Jesse <>, srl <>, and Mike Heins <> contribute on
coding style, documentation, and testing.

=cut
