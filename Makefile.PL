
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME      => 'diveplan',
    VERSION   => '3.0.1',
    EXE_FILES => ['diveplan.pl'],
    'dist'    => { COMPRESS => "gzip -9", SUFFIX => "gz" }
);

