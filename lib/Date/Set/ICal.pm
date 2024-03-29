#!/bin/perl
# Copyright (c) 2001, 2002 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

Date::Set::ICal - internal use - an Infinity + Date::ICal object

=head1 SYNOPSIS

See Date::Set

This module is for Date::Set internal use only!

It's purpose is to provide 'infinity' number handling. 
It also adds some cacheing for string, epoch and new.

=head1 METHODS

=cut

require Exporter;
package Date::Set::ICal;
use strict;
# use warnings;
use Carp;
use AutoLoader;
use vars qw(
    @ISA @EXPORT @EXPORT_OK %NEW_CACHE $DEBUG $VERSION $inf $AUTOLOAD 
);
$DEBUG = 0;
# @ISA = qw(Date::ICal);
@EXPORT = qw();
@EXPORT_OK = qw(); 
$VERSION = (qw'$Revision: 1.23 $')[1];

use Date::ICal;

$inf = 10**10**10;

use overload
    '0+' =>  sub { $_[0]->{epoch} }, 
    '<=>' => sub { 
        return 0 unless defined $_[1];
        $_[2] ? ($_[1] <=> $_[0]{epoch}) : ($_[0]{epoch} <=> $_[1]) 
    },
    '-' =>   sub { 
        $_[2] ? ($_[1]  -  $_[0]{epoch}) : ($_[0]{epoch}  -  $_[1]) },
    '+' =>   sub { $_[0]->{epoch} + $_[1] },
    qw("" as_string),
    fallback => 1;   # we need this for the modulo "%" operation in
                     # quantize() initialization to work
;

%NEW_CACHE = ();

=head2 $new($self, $arg)

$arg can be a string, another Date::Set::ICal object, 
a Date::ICal object, Inf or -Inf.

=head3 Internals

The object is a pointer to $NEW_CACHE{$string}.
Using memoization with %NEW_CACHE makes the program 16% faster.

Each $NEW_CACHE{$string} has 3 keys:

{string} - optional key - a string representation. 
What you get if you put
one of these objects in doublequotes.

{epoch} - a number representation.

{ical} - a Date::ICal object.

=cut

sub new {
    my $self = shift;
    my $string = $_[0]; 

    # figure out what kind of parameter we were given and 
    # get it in a standard format, an iCalendar string
    if ( ref($string) ) {
        if ( UNIVERSAL::isa( $string, 'Date::ICal' )) {
            $self = bless {}, __PACKAGE__;
            $self->{ical}  = $string;
            $self->{epoch} = $string->epoch;
            return $NEW_CACHE{$string} = $self;  # cache object
        }
        return $string;
    }
    return $NEW_CACHE{$string} if exists $NEW_CACHE{$string};

    # print " [ical:new:", join(';', @_) , "] ";

    # we actually have to parse the string and make a new object
    if ($#_ == 0) {  # there are no more parameters
        # epoch or ical mode?
    
        # This is a BOGUS way to tell if a string is a well-formed iCalendar
        # date string, but it's marginally better than what went before
        if ($string =~ /[TZ]/) {
            # carp "1 - $string is the string. we think it's an ical";
            # must be ical format
            $self = bless {}, __PACKAGE__;
            $self->{ical} = Date::ICal->new( ical => $string );
            $self->{string} = $string;    # cache string
            $self->{epoch} = $self->{ical}->epoch;
            return $NEW_CACHE{$string} = $self;  # cache object
        }
        return $NEW_CACHE{$string} =  $inf if $string == $inf;
        return $NEW_CACHE{$string} = -$inf if $string == -$inf;
        # "epoch"
        # print "2\n";
        $self = bless { epoch => $string }, __PACKAGE__;
        return $NEW_CACHE{$string} = $self;  # cache object
    }
    # print "3";
    $self = bless {}, __PACKAGE__;
    $self->{ical} = Date::ICal->new(@_);
    $self->{epoch} = $self->{ical}->epoch;
    return $self;
}

    
=head2 $self->as_string

Stringifies the object; what gets called if you put
one of these objects in doublequotes.

=cut

sub as_string {
    my ($self) = shift;
    if (not exists $self->{string}) {
        if (exists $self->{ical}) {
            $self->{string} = $self->{ical}->ical;
        }
        else {
            $self->{ical} = Date::ICal->new( epoch => $self );
            $self->{string} = $self->{ical}->ical;
            # die "CAN'T STRING: $self->{epoch}\n";
        }
    }
    return $self->{string};
}

=head2 $self->date_ical

Returns the object as a "standard" Date::ICal object.

We don't know what happens if we input an 'infinity' value.

=cut

sub date_ical {
    my $self = shift;
    $self->{ical} = Date::ICal->new( epoch => $self ) unless exists $self->{ical};
    return $self->{ical};
}


# define DESTROY so we don't call AUTOLOAD
sub DESTROY {}

# This is experimental code, originally developed for DateTime::Set:
#
# If I can't do something, I check if the first 'leaf' can do it.
# For example:
#   $set_10 = $set->add( seconds => 10 );
# is a shortcut to:
#   $set_10 = $set->new( $set->min->add( seconds => 10 ) );
#

my %Is_Leaf_Subroutine = (
    add => 1,
    # clone() is a function
    # ical() is a function
);
sub AUTOLOAD {
    if ( $AUTOLOAD =~ /.*::(.*?)$/ ) {
        my $sub = $1;
        my $self = shift;
        my $leaf = $self->date_ical; 

        # warn "D::S::ICal: leaf is a '". ref( $leaf ) . "'";

        # warn "leaf value is ". $leaf->ical ." is a '". ref( $leaf ). "' sub is '". $sub. "' param @_";
        if ( UNIVERSAL::can( $leaf, $sub ) ) {
            # we have different calling modes in leaf class - that's bad.
            if (exists $Is_Leaf_Subroutine{$sub} ) {
                # calling mode is 'subroutine'
                $leaf = $leaf->clone;
                $leaf->$sub(@_);
                # warn "D::S::ICal: sub result is ". $leaf->ical ." ";
            }
            else {
                # calling mode is 'function'
                $leaf = $leaf->$sub(@_);
                # warn "D::S::ICal: function result is ". $leaf;
            }
            # warn "D::S::ICal: result is a '". ref( $leaf ) . "'";
            $leaf = $self->new($leaf) if ref($leaf) eq 'Date::ICal';
            return $leaf;
        }
        Carp::croak( __PACKAGE__ . $AUTOLOAD . " is malformed in AUTOLOAD" );
    }
    else {
        Carp::croak( __PACKAGE__ . $AUTOLOAD . " is malformed in AUTOLOAD" );
    }
    # warn "no autoloading for $AUTOLOAD";
}


=head1 AUTHOR

    Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

1;

__END__

