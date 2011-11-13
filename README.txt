                  ========================
                    DIVE PLAN CALCULATOR
                  ========================

This script allows to make dive plans for single as well as
repetitive dives.

Uses the NOB ("Nederlandse Onderwatersport Bond") dive tables,
based on the Canadian DCIEM ("Defense and Civil Institute of
Environmental Medicine") dive tables, considered to be safer
than most other diving tables.

Before running it, you will have to edit this script to adjust
its parameters (there are too many parameters to handle them
on the command line, many of which do probably not change often
anyway - but it's hard to predict which, depending on what kind
of dives you usually make).

The script should be rather self-explanatory due to the comments
which accompany each of the parameters and also the code itself.

The script was deliberately kept simple in order to make it
easy to adapt to other kinds of dives (e.g. multilevel dives)
and to other ways of calculating dives (e.g. in order to include
the ascent time to a deep stop as part of the time spent at the
deep stop itself, which is currently not the case, or the ascent
time to a deco stop to be part of the time spent at the deco stop,
which slighlty reduces the time actually spent at the stop level).

Also, it is still to be considered as work in progress (it doesn't
handle multilevel dives or dives at altitude yet, for instance).

License:

GNU General Public License, see file "GPL.txt" in this distribution.

Installation:

In order to install this script, type the following commands:

    UNIX:                         Windows:

    perl Makefile.PL              perl Makefile.PL
    make install                  nmake install

This is the recommended method. Alternatively, just move or copy
the file "diveplan" to somewhere in your search path, where you
can easily find it, because you will have to edit it each time
before running in order to adjust its parameters.

Before doing so, under UNIX, don't forget to edit "diveplan"
and to adjust the shell-bang line (the first line of the script)
to match the path where the "perl" binary is located on your system.

Then proceed as follows (illustrative examples):

    UNIX:                              

    chmod 555 diveplan
    cp -p diveplan /usr/local/bin

    Windows:

    pl2bat diveplan
    copy diveplan.bat C:\Windows\System32

Non-UNIX and non-Windows users please refer to the documentation
of your Perl installation for instructions on how to install Perl
scripts as executable applications if none of the above works.

Happy diving!
--
    Steffen Beyer <STBEY@cpan.org>
    Free Perl and C Software for Download:
    http://www.engelschall.com/u/sb/download/
