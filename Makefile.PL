
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME      => 'diveplan',
    VERSION   => '1.1.1',
    EXE_FILES => ['diveplan'],
    'dist'    => { COMPRESS => "gzip -9", SUFFIX => "gz" }
);

