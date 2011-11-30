                  ========================
                    DIVE PLAN CALCULATOR
                  ========================

This CGI script allows to make dive plans for single as well
as repetitive dives.

It uses the NOB ("Nederlandse Onderwatersport Bond") dive tables,
based on the Canadian DCIEM ("Defense and Civil Institute of
Environmental Medicine") dive tables, considered to be safer
than most other diving tables.

This CGI script is still to be considered a work in progress
(it doesn't handle multilevel dives or dives at altitude yet,
for instance).

License:

Same as Perl itself, see files "Artistic.txt" and "GNU_GPL.txt"
in this distribution.

Installation:

Copy the CGI script "diveplan.pl" to a location where it will
be executed by your web server, upon request.

Make sure to adapt the first line ("she-bang" line) of the script,
in order to reflect the path where Perl is installed on your machine.

Happy diving!
--
    Steffen Beyer <STBEY@cpan.org>
    Free Perl and C Software for Download:
    http://www.engelschall.com/u/sb/download/
