use strict;

use Test::More;
plan tests => 4;

use Date::ICal;
use Date::Set;

#======================================================================
# LEAF METHOD INHERITANCE
#====================================================================== 

my $t1 = new Date::ICal( ical => '20001122Z' );
my $s1 = new Date::Set( $t1 );

is( $s1->ical , '20001122Z',
    "ical function inherited from leaf" );

my $s2 = $s1->add( hour => '3' );  
is( $s2->ical , '20001122T030000Z',
    "add() subroutine inherited from leaf - internally changed to function" );

is( $s2->hour , 3,
    "hour() function inherited from leaf" );

is( $s2->max->hour , 3,
    "hour() function inherited from cache-leaf" );

