use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Data::BFDump',
    'VERSION_FROM'	=> 'BFDump.pm', # finds $VERSION
    'PREREQ_PM'		=> {
    					Text::Quote=>0.2,
    					Test::More =>0.41,
    					Carp::Assert=>0.13,
    					B::Deparse=>0.60,
    					Algorithm::Diff=>1.11,
    					Test::Harness=>2.01,
    				   }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'BFDump.pm', # retrieve abstract from module
       AUTHOR     => 'demerphq <demerphq@hotmail.com>') : ()),
);
