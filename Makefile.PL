use ExtUtils::MakeMaker;

WriteMakefile(
    'ABSTRACT'          => 'Date sets math',
    'AUTHOR'            => 'Flavio S. Glock - fglock@pucrs.br',
    'NAME'      		=> 'Date::Set',
    'VERSION_FROM'  	=> 'lib/Date/Set.pm', 
    'EXCLUDE_EXT'       => 'Makefile gz LOG',
    'PREREQ_PM'         => {    'Set::Infinite' => 0.32, 
                                'Date::ICal' => '' ,
                                'Test::Harness'         => '1.23',  # we use todo tests
                                'Test::More'            => '0.31',      
                            },
    'dist'          	=> { 'COMPRESS' => 'gzip' },
);

