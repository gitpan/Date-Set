use ExtUtils::MakeMaker;

WriteMakefile(
    'ABSTRACT'       => 'Date sets math',
    'AUTHOR'         => 'Flavio S. Glock - fglock@pucrs.br',
    'NAME'           => 'Date::Set',
    'VERSION_FROM'   => 'lib/Date/Set.pm', 
    'EXCLUDE_EXT'    => 'Makefile gz LOG',
    'PREREQ_PM'      => {    'Set::Infinite' => '0.35', 
                             'Date::ICal'    => '1.67',
                             'Test::Harness' => '1.23',  # we use todo tests
                             'Test::More'    => '0.31',      
                        },
    'dist'           => { 'COMPRESS' => 'gzip' },
);

