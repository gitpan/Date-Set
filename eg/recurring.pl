#! perl -w
use Date::Set;

print "This is a test for: \n    \"This event happens from 13:00 to 14:00 every Tuesday, unless that Tuesday is the 15th of the month.\" (suggested by srl)\n\n";
my $base_date = '20010501Z';
my $interval = Date::Set->new($base_date)->quantize(unit=>'months');
# print "Weeks: ", $interval->quantize(unit=>'weeks'), "\n\n";
my $tuesdays = $interval->quantize(unit=>'weeks')->
	offset( mode => 'begin', unit=>'days', value => [ 2, 3] );
print "tuesdays: ", $tuesdays, "\n\n";
my $fifteenth = $interval->quantize(unit=>'months')->
	offset( mode => 'begin', unit=>'days', value => [ 14, 15] );
print "fifteenth: ", $fifteenth, "\n\n";
print "events in $base_date: ", $tuesdays -> complement ( $fifteenth ) ->
	offset( mode => 'begin', unit=>'hours', value => [ 13, 14] );
print "\n";

1;
