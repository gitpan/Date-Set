use ExtUtils::MakeMaker;

WriteMakefile(
    'ABSTRACT'       => 'Date sets math',
    'AUTHOR'         => 'Flavio Soibelmann Glock - fglock@pucrs.br',
    'NAME'           => 'Date::Set',
    'VERSION_FROM'   => 'lib/Date/Set.pm', 
    'EXCLUDE_EXT'    => 'Makefile gz LOG x~~',
    'PREREQ_PM'      => {    'Set::Infinite' => '0.37',  
                             'Date::ICal'    => '1.70',
                             'Test::Harness' => '1.23',  # we use to do tests
                             'Test::More'    => '0.31',      
                        },
    'dist'           => { 'COMPRESS' => 'gzip' },
);

