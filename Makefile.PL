
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME      => 'diveplan',
    VERSION   => '3.1.0',
    EXE_FILES => ['diveplan.pl'],
    'dist'    => { COMPRESS => "gzip -9", SUFFIX => "gz" }
);

