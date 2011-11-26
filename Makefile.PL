
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME      => 'diveplan',
    VERSION   => '2.1.1',
    EXE_FILES => ['diveplan.cgi'],
    'dist'    => { COMPRESS => "gzip -9", SUFFIX => "gz" }
);

