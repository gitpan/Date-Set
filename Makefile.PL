use ExtUtils::MakeMaker;

WriteMakefile(
    'ABSTRACT'          => 'Date sets math',
    'AUTHOR'            => 'Flavio S. Glock - fglock@pucrs.br',
    'NAME'      		=> 'Date::Set',
    'VERSION_FROM'  	=> 'lib/Date/Set.pm', 
    'EXCLUDE_EXT'       => 'Makefile gz LOG',
    'PREREQ_PM'         => { 'Set::Infinite' => 0.30, Date::ICal },
    'dist'          	=> { 'COMPRESS' => 'gzip' },
);

