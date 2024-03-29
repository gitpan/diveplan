#!perl -w

##################################################################
##                                                              ##
##    DIVE PLAN CALCULATOR                                      ##
##                                                              ##
##    Version 3.1.0                                             ##
##                                                              ##
##    Released 2011-12-02                                       ##
##                                                              ##
##    Copyright (C) 2011 by Steffen Beyer.                      ##
##    All rights reserved.                                      ##
##                                                              ##
##    This program is free software; you can redistribute it    ##
##    and/or modify it under the same terms as Perl itself.     ##
##                                                              ##
##################################################################

##################################################################
#                                                                #
# Uses the NOB ("Nederlandse Onderwatersport Bond") dive tables, #
# based on the Canadian DCIEM ("Defense and Civil Institute of   #
# Environmental Medicine") dive tables, considered to be safer   #
# than most other diving tables.                                 #
#                                                                #
##################################################################

use strict;

############################
#                          #
# Configuration constants: #
#                          #
############################

my $default_safety_stop_depth = 5;

my $default_safety_stop_time = 3;

my $default_deep_stop_time = 2;

#############################
#                           #
# Parameter default values: #
#                           #
#############################

my $max_depth = 18; # meter

my $bottom_time = 30; # minute

my $includes_descent = 1; # non-zero => bottom time includes time for descent, zero => bottom time is time actually spent at max. depth

my $tank_vol = 15; # liter

my $tank_pre = 200; # bar

my $sac = 25; # surface liter/minute ("surface air consumption")

my $descent_rate = 10; # meter/minute

my $ascent_rate = 10; # meter/minute

my $deep_stops = 0; # zero => disable deep stops, non-zero => enable deep stops

my $safety_stop = $default_safety_stop_depth; # meter - set to 0 to disable

my $time_step = 1; # minute

my $repetitive_dive = 0;

my $pressure_group = 'A'; # 'A' .. 'O'

my $surface_interval = 60; # minute / 1 day = 1440 min, 2 days = 2880 min, 3 days = 4320 min / set e.g. to 5000 to disable

#####################
#                   #
# Global constants: #
#                   #
#####################

my $diveplan = 'diveplan.txt';

my $checked = ' CHECKED';

my $header = <<'VERBATIM';
<TABLE BGCOLOR="#FFFFFF" CELLSPACING="1" CELLPADDING="7" BORDER="2">
<TR>
<TD>
<PRE>
VERBATIM

my $footer = <<'VERBATIM';
</PRE>
</TD>
</TR>
</TABLE>

<P>
<HR NOSHADE SIZE="2">
<P>
VERBATIM

#####################
#                   #
# Global variables: #
#                   #
#####################

my $mandatory_stop = 0;
my $show_tables = 0;
my $save_time = 0;
my $plan = '';

my $delta_air = 0;
my $depth = 0;
my $time = 0;
my $tank = 0;
my $air = 0;

my(%Table_A)  = ();
my(%Table_Aa) = ();
my(%Table_B)  = ();
my(%Table_C)  = ();

my(@Table_B_lo) = ();
my(@Table_B_hi) = ();

my(@inc_flag) = ('', '');
my $deep_flag = '';
my $rep_flag = '';

###################
#                 #
# Initialisation: #
#                 #
###################

process_query_string();

$mandatory_stop = $safety_stop || $default_safety_stop_depth;

$descent_rate = -$descent_rate if ($descent_rate <  0);
$descent_rate = 10             if ($descent_rate == 0);

$ascent_rate  = -$ascent_rate  if  ($ascent_rate  <  0);
$ascent_rate  = 10             if (($ascent_rate  == 0)
                               or  ($ascent_rate  > 10));

$inc_flag[($includes_descent ? 1 : 0)] = $checked;

$deep_flag = $checked if ($deep_stops);

$rep_flag = $checked if ($repetitive_dive);

$save_time = $bottom_time;

$tank = $tank_vol * $tank_pre; # liter * bar = surface liter

init_table_A();
init_table_Aa();
init_table_B();
init_table_C();

##############
#            #
# Calculate: #
#            #
##############

unless ($show_tables)
{
    eval { calculate_plan(); };
    store($@) if ($@);
}

##################
#                #
# Print results: #
#                #
##################

print_page();

###########################
#                         #
# Subroutines and Tables: #
#                         #
###########################

sub calculate_plan
{
    my($factor,$delta_time,$mdd,$dt,$deco,$first,$stop,$temp,$pgdisp,$pgtemp);

    store ("\n                         ***** Dive Plan *****\n\n");
    storef("Maximum Depth:  %3d     (m)\n", $max_depth);
    storef("Bottom Time:    %3d     (min) ", $bottom_time);
    store(($includes_descent?"(in":"(ex"), "cludes time for descent)\n");
    storef("Tank Volume:    %3d     (l)\n", $tank_vol);
    storef("Tank Pressure:  %3d     (bar)\n", $tank_pre);
    storef("SAC Rate:       %3d     (l/min)\n", $sac);
    storef("Descent Rate:    %6.3f (m/min)\n", $descent_rate);
    storef("Ascent Rate:     %6.3f (m/min)\n", $ascent_rate);

    $factor = 1.0;
    if ($repetitive_dive)
    {
        if ($factor = get_rep_factor($pressure_group,$surface_interval))
        {
            store ("\nRepetitive Dive:\n\n");
            store ("Pressure Group:     '$pressure_group'\n");
            storef("Surface Interval:  %4d (min)\n", $surface_interval);
            storef("Repetition Factor:  %3.1f\n", $factor);
        }
        else
        {
            $factor = 1.0;
            $repetitive_dive = 0;
        }
    }

    ############
    #          #
    # Descent: #
    #          #
    ############

    store("\nDescent:\n\n");

    storeline(); # show initial status

    descent($max_depth);

    ###################
    #                 #
    # Stay at Bottom: #
    #                 #
    ###################

    store("\nBottom:\n\n");

    if ($includes_descent)
    {
        $delta_time = $bottom_time - $time;
        if ($delta_time > 0) { make_stop($delta_time);          }
        else                 { store("No bottom time left!\n"); }
    }
    else
    {
        make_stop($bottom_time);
    }
    $bottom_time = $time;

    ###############
    #             #
    # Deep Stops: #
    #             #
    ###############

    ($mdd,$dt,$deco) = get_deco_stops($max_depth,$bottom_time,$factor);

    if ($deep_stops)
    {
        while (($depth - ($first = get_first_stop($deco))) >= 10)
        {
            $stop = int(($depth+$first)/2+0.5);
            store("\nAscent:\n\n");
            ascent($stop);
            store("\nDeep Stop: $default_deep_stop_time min \@ $stop m\n\n");
            make_stop($default_deep_stop_time);
            $bottom_time += $default_deep_stop_time;
            ($mdd,$dt,$deco) = get_deco_stops($max_depth,$bottom_time,$factor);
        }
    }

    ##############################
    #                            #
    # Deco Stops or Safety Stop: #
    #                            #
    ##############################

    if ($deco->[0] or
        $deco->[1] or
        $deco->[2] or
        $deco->[3] or
        $deco->[4])
    {
        if ($deco->[0])
        {
            store("\nAscent:\n\n");
            ascent(12);
            store("\nDeco Stop: $deco->[0] min \@ 12 m\n\n");
            make_stop($deco->[0]);
        }
        if ($deco->[1])
        {
            store("\nAscent:\n\n");
            ascent(9);
            store("\nDeco Stop: $deco->[1] min \@ 9 m\n\n");
            make_stop($deco->[1]);
        }
        if ($deco->[2])
        {
            store("\nAscent:\n\n");
            ascent(6);
            store("\nDeco Stop: $deco->[2] min \@ 6 m\n\n");
            make_stop($deco->[2]);
        }
        if ($deco->[3])
        {
            store("\nAscent:\n\n");
            ascent(3);
            store("\nDeco Stop: $deco->[3] min \@ 3 m\n\n");
            make_stop($deco->[3]);
        }
        if ($deco->[4])
        {
            store("\nAscent:\n\n");
            ascent($mandatory_stop);
            store("\nMandatory Safety Stop: $default_safety_stop_time min \@ $mandatory_stop m\n\n");
            make_stop($default_safety_stop_time);
        }
    }
    elsif ($safety_stop)
    {
        store("\nAscent:\n\n");
        ascent($safety_stop);
        store("\nSafety Stop: $default_safety_stop_time min \@ $safety_stop m\n\n");
        make_stop($default_safety_stop_time);
    }

    #################
    #               #
    # Final Ascent: #
    #               #
    #################

    store("\nFinal Ascent:\n\n");

    ascent(0);

    ########
    #      #
    # End: #
    #      #
    ########

    $pgdisp = $pgtemp = $deco->[5];

    if ($repetitive_dive)
    {
        if (($surface_interval < 360) and (ord($pgdisp) < ($temp = ord($pressure_group) + 1)))
        {
            $pgtemp = chr($temp);
            $pgdisp = "$pgtemp ($deco->[5] => ${pressure_group}+1)";
        }
        $temp = $bottom_time * $factor;
        store("\nYour pressure group for MDD=$mdd and DT=$dt (for $bottom_time x $factor = $temp min bottom time) is now: $pgdisp\n");
    }
    else
    {
        store("\nYour pressure group for MDD=$mdd and DT=$dt (for $bottom_time min bottom time) is now: $pgdisp\n");
    }
    $pressure_group = $pgtemp;
    store("\nEnd.\n");
}

sub descent
{
    my($stop_depth) = shift;
    my($delta_time,$delta_depth,$new_depth);

    while ($depth < $stop_depth) # descent
    {
        $delta_time = $time_step;
        $delta_depth = $delta_time * $descent_rate;
        $new_depth = $depth + $delta_depth;
        if ($new_depth > $stop_depth)
        {
            $delta_depth = $stop_depth - $depth;
            $delta_time = $delta_depth / $descent_rate;
            $new_depth = $stop_depth;
        }
        $delta_air = air_consumption($delta_time,$depth,$descent_rate);
        $time += $delta_time;
        $depth = $new_depth;
        $tank -= $delta_air;
        $air  += $delta_air;
        storeline();
    }
}

sub make_stop
{
    my($stop_time) = shift;
    my($acc_time,$delta_time,$new_time);

    $acc_time = 0;
    while ($acc_time < $stop_time)
    {
        $delta_time = $time_step;
        $new_time = $acc_time + $delta_time;
        if ($new_time > $stop_time)
        {
            $delta_time = $stop_time - $acc_time;
            $new_time = $stop_time;
        }
        $delta_air = air_consumption($delta_time,$depth,0);
        $acc_time = $new_time;
        $time += $delta_time;
        $tank -= $delta_air;
        $air  += $delta_air;
        storeline();
    }
}

sub ascent
{
    my($stop_depth) = shift;
    my($delta_time,$delta_depth,$new_depth);

    while ($depth > $stop_depth) # ascent
    {
        $delta_time = $time_step;
        $delta_depth = $delta_time * $ascent_rate;
        $new_depth = $depth - $delta_depth;
        if ($new_depth < $stop_depth)
        {
            $delta_depth = $depth - $stop_depth;
            $delta_time = $delta_depth / $ascent_rate;
            $new_depth = $stop_depth;
        }
        $delta_air = air_consumption($delta_time,$depth,-$ascent_rate);
        $time += $delta_time;
        $depth = $new_depth;
        $tank -= $delta_air;
        $air  += $delta_air;
        storeline();
    }
}

sub air_consumption
{
    my($time,$depth,$rate) = @_;
    return $sac * $time * (1 + $depth/10 + $rate*$time/20);
}

sub store { $plan .= join('', @_); }

sub storef { $plan .= sprintf(shift,@_); }

sub storeline
{
    storef("Time: %2d (min) Depth: %2d (m) Air: %3d (l) Total: %4d (l) Tank: %3d (bar)\n", int($time+0.5), int($depth+0.5), int($delta_air+0.5), int($air+0.5), int(($tank/$tank_vol)+0.5));
}

sub get_rep_factor
{
    my($group,$interval) = @_;
    my($loop);

    if ($interval < $Table_B_lo[0])
    {
        die "\n\nThis is not a repetitive dive, but a continuation of a previous one (surface interval of $interval min < $Table_B_lo[0] min)!\n";
    }
    if ($interval > $Table_B_hi[10])
    {
        return 0.0; # surface interval lies outside of the table, this is no repetitive dive but a new one
    }
    foreach $loop (0..10)
    {
        if ($interval >= $Table_B_lo[$loop] and $interval <= $Table_B_hi[$loop])
        {
            return     $Table_B{$group}[$loop]
            if (exists($Table_B{$group})               and
               defined($Table_B{$group})               and
                   ref($Table_B{$group}) eq 'ARRAY'    and
               defined($Table_B{$group}[$loop])        and
                      ($Table_B{$group}[$loop] >= 1.0) and
                      ($Table_B{$group}[$loop] <= 2.0));
            die "\n\nNo valid entry found in dive table B for pressure group '$group' and interval \[$Table_B_lo[$loop]..$Table_B_hi[$loop]\] min (for $interval min)!\n";
        }
    }
    die "\n\nNo valid entry found in dive table B for pressure group '$group' and $interval min surface interval!\n";
}

sub get_deco_stops
{
    my($depth,$time,$factor) = @_;
    my($srt,$mandatory,$mdd,$dt,$ndl,$group,$loop);

    $srt = $time;
    $mandatory = 0;
    if ($repetitive_dive and ($factor > 1.0))
    {
        $srt = $time * $factor;
        $mandatory = 1;
        NDL:
        foreach $mdd (sort { $a <=> $b } keys(%Table_C))
        {
            if ($mdd >= $depth)
            {
                $mandatory = 0 if (exists($Table_C{$mdd}{$factor}) and defined($Table_C{$mdd}{$factor}) and ($time < $Table_C{$mdd}{$factor}));
                last NDL;
            }
        }
    }
    NODECO:
    foreach $mdd (sort { $a <=> $b } keys(%Table_Aa))
    {
        if ($mdd >= $depth)
        {
            $ndl = $Table_Aa{$mdd}[0];
            $ndl = 720 if (($ndl == 0) and ($mdd == 6));
            if ($ndl >= $srt)
            {
                $group = 'A';
                foreach $loop (1..15)
                {
                    $dt = $Table_Aa{$mdd}[$loop];
                    if (($dt > 0) and ($dt >= $srt))
                    {
                        return($mdd,$dt,[0,0,0,0,$mandatory,$group]);
                    }
                    $group++;
                }
            }
            last NODECO;
        }
    }
    foreach $mdd (sort { $a <=> $b } keys(%Table_A))
    {
        if ($mdd >= $depth)
        {
            foreach $dt (sort { $a <=> $b } keys(%{$Table_A{$mdd}}))
            {
                if ($dt >= $srt)
                {
                    return($mdd,$dt,$Table_A{$mdd}{$dt});
                }
            }
            if ($repetitive_dive)
            {
                die "\n\nCould not find the time of $srt min (for $time x $factor min) at a depth of $mdd m (for $depth m) in dive table A!\n";
            }
            else
            {
                die "\n\nCould not find the time of $srt min at a depth of $mdd m (for $depth m) in dive table A!\n";
            }
        }
    }
    die "\n\nCould not find the depth of $depth m in dive table A!\n";
}

sub get_first_stop
{
    my($deco) = shift;
    return( ($deco->[0]?12:0) || ($deco->[1]?9:0) || ($deco->[2]?6:0) || ($deco->[3]?3:0) || ($deco->[4]?$mandatory_stop:0) || $safety_stop );
}

sub init_table_A
{
    my($text,$item,$line,$loop,$depth,$time,$deco12,$deco9,$deco6,$deco3,$group);

    $text = <<'VERBATIM';

  9  300   .   .   .   .  M
  9  330   .   .   .   3  N
  9  360   .   .   .   5  O

 12  150   .   .   .   .  J
 12  180   .   .   .   5  M

 15   75   .   .   .   .  G
 15  100   .   .   .   5  I
 15  120   .   .   .  10  K
 15  125   .   .   .  13  K
 15  130   .   .   .  16  L
 15  140   .   .   .  21  M

 18   50   .   .   .   .  F
 18   60   .   .   .   5  G
 18   80   .   .   .  10  I
 18   90   .   .   .  16  J
 18  100   .   .   .  24  K
 18  110   .   .   .  30  L
 18  120   .   .   .  36  M

 21   35   .   .   .   .  E
 21   40   .   .   .   5  F
 21   50   .   .   .  10  G
 21   60   .   .   .  12  H
 21   70   .   .   3  17  J
 21   80   .   .   4  25  K
 21   90   .   .   5  32  M
 21  100   .   .   6  39  N

 24   25   .   .   .   .  E
 24   30   .   .   .   5  F
 24   40   .   .   .  11  G
 24   50   .   .   4  11  H
 24   55   .   .   5  15  I
 24   60   .   .   6  21  J
 24   65   .   .   7  25  J
 24   70   .   .   7  30  K
 24   75   .   .   8  34  L
 24   80   .   .   9  37  M

 27   20   .   .   .   .  D
 27   25   .   .   .   7  E
 27   30   .   .   2   9  F
 27   40   .   .   6  10  H
 27   45   .   .   7  14  I
 27   50   .   .   8  20  J
 27   55   .   .   9  26  K
 27   60   .   2   8  31  L

 30   15   .   .   .   .  D
 30   20   .   .   .   8  E
 30   25   .   .   3   9  F
 30   30   .   .   5  10  G
 30   35   .   .   7  11  H
 30   40   .   .   9  16  I
 30   45   .   3   8  23  J
 30   50   .   4   8  29  K
 30   55   .   5   9  34  L

 33   12   .   .   .   .  C
 33   15   .   .   .   5  D
 33   20   .   .   3   9  F
 33   25   .   .   6  10  G
 33   30   .   .   9  10  H
 33   35   .   3   8  16  I
 33   40   .   5   8  24  J
 33   45   .   6   9  31  K
 33   50   .   7   9  38  M
 33   55   .   8  10  44  N

 36   10   .   .   .   .  C
 36   15   .   .   .  10  E
 36   20   .   .   5  10  F
 36   25   .   .   9  10  G
 36   30   .   4   8  14  I
 36   35   .   6   8  24  J
 36   40   .   8   8  32  K
 36   45   3   6  10  38  M
 36   50   4   7  10  46  N

 39    8   .   .   .   .  B
 39   10   .   .   .   5  C
 39   15   .   .   4   8  E
 39   20   .   .   8  10  G
 39   25   .   5   7  11  H
 39   30   .   7   8  22  J
 39   35   3   6   9  30  K
 39   40   4   7   9  39  M
 39   45   6   7  10  47  N

 42    7   .   .   .   .  B
 42   10   .   .   .   7  D
 42   15   .   .   6   9  F
 42   20   .   4   7  10  G
 42   25   .   7   8  17  I
 42   30   4   6   8  28  K
 42   35   5   7   9  37  L
 42   40   7   7  10  46  N

 45    7   .   .   .   .  B
 45   10   .   .   .   9  D
 45   15   .   .   8   9  F
 45   20   .   6   7  11  H
 45   25   4   5   8  23  J
 45   30   6   6   9  34  K

 48    6   .   .   .   .  B
 48   10   .   .   .  11  D
 48   15   .   4   6  10  G
 48   20   .   8   8  14  H
 48   25   6   6   8  29  K

 51    6   .   .   .   .  B
 51   10   .   .   5   8  D
 51   15   .   5   7  10  G
 51   20   5   5   8  20  I

 54    5   .   .   .   .  B
 54   10   .   .   6   9  E
 54   15   .   7   7  11  H
 54   20   6   6   8  25  J

VERBATIM

    if ($show_tables)
    {
        store(<<"VERBATIM");
${header}
          Table A:

MDD   DT 12m  9m  6m  3m PG
${text}${footer}
VERBATIM
        return;
    }
    DECO:
    foreach $item (split(/[\r\n]+/, $text))
    {
        $line = $item;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next DECO if $line eq '';
        ($depth,$time,$deco12,$deco9,$deco6,$deco3,$group) = split(' ', $line);
        $line = [$deco12,$deco9,$deco6,$deco3,0,$group];
        foreach $loop (0..3) { $line->[$loop] = 0 unless $line->[$loop] =~ /^\d+$/ }
        $Table_A{$depth}{$time} = $line;
    }
}

sub init_table_Aa
{
    my($text,$item,$line,$loop,$depth,$time,$A,$B,$C,$D,$E,$F,$G,$H,$I,$J,$K,$L,$M,$N,$O);

    $text = <<'VERBATIM';

  6    .   30   60   90  120  150  180  240  300  360  420  480  600  720    .    .
  9  300   30   45   60   90  100  120  150  180  190  210  240  270  300  330  360
 12  150   22   30   40   60   70   80   90  120  130  150    .    .  180    .    .
 15   75   18   25   30   40   50   60   75    .  100    .  120  130  140    .    .
 18   50   14   20   25   30   40   50   60    .   80   90  100  110  120    .    .
 21   35   12   15   20   25   35   40   50   60    .   70   80    .   90  100    .
 24   25   10   13   15   20   25   30   40   50   55   65   70   75   80    .    .
 27   20    9   12   15   20   25   30    .   40   45   50   55   60    .    .    .
 30   15    7   10   12   15   20   25   30   35   40   45   50   55    .    .    .
 33   12    6   10   12   15    .   20   25   30   35   40   45    .   50   55    .
 36   10    5    8   10    .   15   20   25    .   30   35   40    .   45   50    .
 39    8    5    8   10    .   15    .   20   25    .   30   35    .   40   45    .
 42    7    5    7    .   10    .   15   20    .   25    .   30   35    .   40   45
 45    7    4    7    .   10    .   15    .   20    .   25   30    .   35    .   40
 48    6    .    6    .   10    .    .   15   20    .    .   25    .   30   35    .
 51    6    .    6    .   10    .    .   15    .   20    .   25    .   30    .   35
 54    5    .    5    .    .   10    .    .   15    .   20    .    .   25    .   30

VERBATIM

    if ($show_tables)
    {
        store(<<"VERBATIM");
${header}
                                      Table Aa:

MDD  NDL    A    B    C    D    E    F    G    H    I    J    K    L    M    N    O
${text}${footer}
VERBATIM
        return;
    }
    GROUP:
    foreach $item (split(/[\r\n]+/, $text))
    {
        $line = $item;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next GROUP if $line eq '';
        ($depth,$time,$A,$B,$C,$D,$E,$F,$G,$H,$I,$J,$K,$L,$M,$N,$O) = split(' ', $line);
        $line = [$time,$A,$B,$C,$D,$E,$F,$G,$H,$I,$J,$K,$L,$M,$N,$O];
        foreach $loop (0..15) { $line->[$loop] = 0 unless $line->[$loop] =~ /^\d+$/ }
        $Table_Aa{$depth} = $line;
    }
}

sub init_table_B
{
    my($text,$item,$line,$loop,$group,$M15,$M30,$M60,$M90,$H2,$H3,$H4,$H6,$H9,$H12,$H15);

    @Table_B_lo = ( 15, 30, 60, 90, 2*60, 3*60, 4*60, 6*60, 9*60, 12*60, 15*60 );
    @Table_B_hi = @Table_B_lo;
    shift(@Table_B_hi);
    foreach $item (@Table_B_hi) { $item-- };
    push(@Table_B_hi,18*60);

    $text = <<'VERBATIM';

    A  1.4  1.2  1.1  1.1  1.1  1.1  1.1  1.1  1.0  1.0  1.0
    B  1.5  1.3  1.2  1.2  1.1  1.1  1.1  1.1  1.1  1.0  1.0
    C  1.6  1.4  1.3  1.2  1.2  1.2  1.1  1.1  1.1  1.0  1.0
    D  1.8  1.5  1.4  1.3  1.3  1.2  1.2  1.1  1.1  1.0  1.0
    E  1.9  1.6  1.5  1.4  1.3  1.3  1.2  1.2  1.1  1.1  1.0
    F  2.0  1.7  1.6  1.5  1.4  1.3  1.3  1.2  1.1  1.1  1.0
    G   .   1.9  1.7  1.6  1.5  1.4  1.3  1.2  1.1  1.1  1.0
    H   .    .   1.9  1.7  1.6  1.5  1.4  1.3  1.1  1.1  1.1
    I   .    .   2.0  1.8  1.7  1.5  1.4  1.3  1.1  1.1  1.1
    J   .    .    .   1.9  1.8  1.6  1.5  1.3  1.2  1.1  1.1
    K   .    .    .   2.0  1.9  1.7  1.5  1.3  1.2  1.1  1.1
    L   .    .    .    .   2.0  1.7  1.6  1.4  1.2  1.1  1.1
    M   .    .    .    .    .   1.8  1.6  1.4  1.2  1.1  1.1
    N   .    .    .    .    .   1.9  1.7  1.4  1.2  1.1  1.1
    O   .    .    .    .    .   2.0  1.7  1.4  1.2  1.1  1.1

VERBATIM

    if ($show_tables)
    {
        $line = '';
        foreach $item (@Table_B_lo) { $line .= sprintf(" %4d", $item); };
        $loop = '';
        foreach $item (@Table_B_hi) { $loop .= sprintf(" %4d", $item); };
        store(<<"VERBATIM");
${header}
                            Table B:

     ${line}
         :    :    :    :    :    :    :    :    :    :    :
   PG${loop}
${text}${footer}
VERBATIM
        return;
    }
    FACTOR:
    foreach $item (split(/[\r\n]+/, $text))
    {
        $line = $item;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next FACTOR if $line eq '';
        ($group,$M15,$M30,$M60,$M90,$H2,$H3,$H4,$H6,$H9,$H12,$H15) = split(' ', $line);
        $line = [$M15,$M30,$M60,$M90,$H2,$H3,$H4,$H6,$H9,$H12,$H15];
        foreach $loop (0..10) { $line->[$loop] = 0 unless $line->[$loop] =~ /^\d+\.\d+$/ }
        $Table_B{$group} = $line;
    }
}

sub init_table_C
{
    my($text,$item,$line,$loop,$depth,@list);
    my(@factor) = ( 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0 );

    $text = <<'VERBATIM';

  9  272  250  230  214  200  187  176  166  157  150
 12  136  125  115  107  100   93   88   83   78   75
 15   60   55   50   45   41   38   36   34   32   31
 18   40   35   31   29   27   26   24   23   22   21
 21   30   25   21   19   18   17   16   15   14   13
 24   20   18   16   15   14   13   12   12   11   11
 27   16   14   12   11   11   10    9    9    8    8
 30   13   11   10    9    9    8    8    7    7    7
 33   10    9    8    8    7    7    6    6    6    6
 36    8    7    7    6    6    6    5    5    5    5
 39    7    6    6    5    5    5    4    4    4    4
 42    6    5    5    5    4    4    4    3    3    3
 45    5    5    4    4    4    3    3    3    3    3

VERBATIM

    if ($show_tables)
    {
        $line = 'MDD';
        foreach $loop (0..9) { $line .= sprintf("  %3.1f", $factor[$loop]); }
        store(<<"VERBATIM");
${header}
                       Table C:

${line}
${text}${footer}
VERBATIM
        return;
    }
    LIMIT:
    foreach $item (split(/[\r\n]+/, $text))
    {
        $line = $item;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next LIMIT if $line eq '';
        ($depth,@list) = split(' ', $line);
        foreach $loop (0..9)
        {
            $Table_C{$depth}{$factor[$loop]} = $list[$loop];
        }
    }
}

sub process_query_string
{
    my $query = $ENV{'QUERY_STRING'} || $ENV{'REDIRECT_QUERY_STRING'} || '';
    my(@pairs) = split(/&/, $query);
    my($pair,$var,$val);

    foreach $pair (@pairs)
    {
        ($var,$val) = split(/=/,$pair,2);
        $var =~ s!\+! !g; $var =~ s!%([a-fA-F0-9][a-fA-F0-9])!pack("C", hex($1))!eg;
        $val =~ s!\+! !g; $val =~ s!%([a-fA-F0-9][a-fA-F0-9])!pack("C", hex($1))!eg;
        $var =~ s!^\s+!!; $var =~ s!\s+$!!; $var = uc($var);
        $val =~ s!^\s+!!; $val =~ s!\s+$!!; $val = uc($val);
        if ($var =~ m!^[A-Z]+$!)
        {
            if    ($var eq 'MD' or $var eq 'MDD')
            {
                if ($val ne '' and $val =~ m!^[0-9]*\.?[0-9]*$!) { $max_depth = $val + 0; }
            }
            elsif ($var eq 'BT' or $var eq 'DT')
            {
                if ($val ne '' and $val =~ m!^[0-9]*\.?[0-9]*$!) { $bottom_time = $val + 0; }
            }
            elsif ($var eq 'IN')
            {
                if ($val =~ m!^[0-9]+$!) { $includes_descent = $val ? 1 : 0; }
            }
            elsif ($var eq 'TV')
            {
                if ($val ne '' and $val =~ m!^[0-9]*\.?[0-9]*$!) { $tank_vol = $val + 0; }
            }
            elsif ($var eq 'TP')
            {
                if ($val ne '' and $val =~ m!^[0-9]*\.?[0-9]*$!) { $tank_pre = $val + 0; }
            }
            elsif ($var eq 'SAC')
            {
                if ($val ne '' and $val =~ m!^[0-9]*\.?[0-9]*$!) { $sac = $val + 0; }
            }
            elsif ($var eq 'DR')
            {
                if ($val ne '' and $val =~ m!^[0-9]*\.?[0-9]*$!) { $descent_rate = $val + 0; }
            }
            elsif ($var eq 'AR')
            {
                if ($val ne '' and $val =~ m!^[0-9]*\.?[0-9]*$!) { $ascent_rate = $val + 0; }
            }
            elsif ($var eq 'DS')
            {
                if ($val =~ m!^[0-9]+$!) { $deep_stops = $val ? 1 : 0; }
            }
            elsif ($var eq 'SS')
            {
                if ($val ne '' and $val =~ m!^[0-9]*\.?[0-9]*$!) { $safety_stop = $val + 0; }
            }
            elsif ($var eq 'GR')
            {
                if ($val ne '' and $val =~ m!^[0-9]*\.?[0-9]*$!) { $time_step = $val + 0; }
            }
            elsif ($var eq 'RD')
            {
                if ($val =~ m!^[0-9]+$!) { $repetitive_dive = $val ? 1 : 0; }
            }
            elsif ($var eq 'PG')
            {
                if ($val =~ m!^[A-O]$!) { $pressure_group = $val; }
            }
            elsif ($var eq 'SI')
            {
                if ($val ne '')
                {
                    if    ($val =~ m!^[0-9]*\.?[0-9]*$!)       { $surface_interval = $val + 0;     }
                    elsif ($val =~ m!^([0-9]+):$!)             { $surface_interval = $1 * 60;      }
                    elsif ($val =~ m!^([0-9]+):([0-5][0-9])$!) { $surface_interval = $1 * 60 + $2; }
                }
            }
            elsif (($var eq 'SHOW') and ($val eq 'TABLES')) { $show_tables = 1; }
        }
    }
}

sub print_page
{
    print <<"VERBATIM";
Content-type: text/html; charset="iso-8859-1"

<HTML>
<HEAD>
    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso-8859-1">
    <TITLE>Steffen Beyer's Dive Plan Calculator</TITLE>

<script type="text/javascript">
function grayout()
{
    DivePlan.PG.disabled = !DivePlan.RD.checked;
    DivePlan.SI.disabled = !DivePlan.RD.checked;
}
onload = grayout;
</script>

</HEAD>
<BODY BGCOLOR="#FFFFFF" BACKGROUND="/~sb/layout/img/udjat.gif">
<CENTER>

<P>
<HR NOSHADE SIZE="2">
<P>

<H1>Steffen Beyer's Dive Plan Calculator</H1>

<TABLE WIDTH="30%" BGCOLOR="#F4F4F4" CELLSPACING="1" CELLPADDING="7" BORDER="2">
<TR>
<TD>
Uses the NOB ("Nederlandse Onderwatersport Bond") dive tables,
based on the Canadian DCIEM ("Defense and Civil Institute of
Environmental Medicine") dive tables, considered to be safer
than most other diving tables.
</TD>
</TR>
</TABLE>

<P>
<HR NOSHADE SIZE="2">
<P>

<TABLE BGCOLOR="#E0E0E0" CELLSPACING="1" CELLPADDING="7" BORDER="2">

<FORM NAME="DivePlan" METHOD="GET" ACTION="">

<TR>
<TD VALIGN="middle" ALIGN="right" ><B>PARAMETER</B></TD>
<TD VALIGN="middle" ALIGN="center"><B>VALUE</B></TD>
<TD VALIGN="middle" ALIGN="left"  ><B>UNIT</B></TD>
<TD VALIGN="middle" ALIGN="left"  ><B>OPTIONS/COMMENTS</B></TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Maximum Depth:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="MD" VALUE="$max_depth"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >m</TD>
<TD VALIGN="middle" ALIGN="left"  >&nbsp;</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Bottom Time:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="BT" VALUE="$save_time"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >min</TD>
<TD VALIGN="middle" ALIGN="left"  >
    <INPUT TYPE="radio" NAME="IN" VALUE="1"$inc_flag[1]>&nbsp;includes time for descent</INPUT>
<HR NOSHADE SIZE="1">
    <INPUT TYPE="radio" NAME="IN" VALUE="0"$inc_flag[0]>&nbsp;is true bottom time</INPUT>
</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Tank Volume:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="TV" VALUE="$tank_vol"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >l</TD>
<TD VALIGN="middle" ALIGN="left"  >&nbsp;</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Tank Pressure:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="TP" VALUE="$tank_pre"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >bar</TD>
<TD VALIGN="middle" ALIGN="left"  >&nbsp;</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >SAC Rate:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="SAC" VALUE="$sac"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >l/min</TD>
<TD VALIGN="middle" ALIGN="left"  >(&quot;Surface Air Consumption&quot;)</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Descent Rate:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="DR" VALUE="$descent_rate"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >m/min</TD>
<TD VALIGN="middle" ALIGN="left"  >&nbsp;</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Ascent Rate:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="AR" VALUE="$ascent_rate"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >m/min</TD>
<TD VALIGN="middle" ALIGN="left"  >(&lt;= 10 m/min)</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Deep Stops:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="checkbox" NAME="DS" VALUE="1"$deep_flag></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >&nbsp;</TD>
<TD VALIGN="middle" ALIGN="left"  >(Use &quot;Pyle&quot; stops)</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Safety Stop:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="SS" VALUE="$safety_stop"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >m</TD>
<TD VALIGN="middle" ALIGN="left"  >(Set to 0 to disable)</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Time Increments:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="GR" VALUE="$time_step"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >min</TD>
<TD VALIGN="middle" ALIGN="left"  >(Granularity)</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Repetitive Dive:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="checkbox" NAME="RD" VALUE="1"$rep_flag onchange="grayout()"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >&nbsp;</TD>
<TD VALIGN="middle" ALIGN="left"  >&nbsp;</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Pressure Group:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="PG" VALUE="$pressure_group"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >&nbsp;</TD>
<TD VALIGN="middle" ALIGN="left"  >[A..O]</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="right" >Surface Interval:</TD>
<TD VALIGN="middle" ALIGN="center">
    <INPUT TYPE="text" SIZE="4" MAXLENGTH="6" NAME="SI" VALUE="$surface_interval"></INPUT>
</TD>
<TD VALIGN="middle" ALIGN="left"  >min</TD>
<TD VALIGN="middle" ALIGN="left"  >or HH:MM</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="center" COLSPAN="4">
    <INPUT TYPE="reset" VALUE="Reset"></INPUT>
</TD>
</TR>

<TR>
<TD VALIGN="middle" ALIGN="center" COLSPAN="4">
    <INPUT TYPE="submit" VALUE="Calculate"></INPUT>
</TD>
</TR>

</FORM>

<FORM NAME="DiveTables" METHOD="GET" ACTION="">
<TR>
<TD VALIGN="middle" ALIGN="center" COLSPAN="4">
    <INPUT TYPE="hidden" NAME="show" VALUE="tables"></INPUT>
    <INPUT TYPE="submit" VALUE="Show Dive Tables"></INPUT>
</TD>
</TR>
</FORM>

</TABLE>

<P>
<HR NOSHADE SIZE="2">
<P>

VERBATIM

    if ($show_tables)
    {
        print $plan;
    }
    else
    {
        print <<"VERBATIM";
${header}${plan}${footer}
<A TARGET="_blank" HREF="${diveplan}">Download this dive plan</A>
<P>
VERBATIM
    }

    print <<"VERBATIM";
<A TARGET="_blank" HREF="diveplan.pl">Download this software</A>
<P>
Download <A TARGET="_blank" HREF="Handleiding_NOB_Sportduiktabellen.pdf">Handleiding NOB Sportduiktabellen</A> (PDF 6.7MB)

<P>
<HR NOSHADE SIZE="2">
<P>

</CENTER>
</BODY>
</HTML>
VERBATIM

    unless ($show_tables)
    {
        umask(022);
        chmod(0644,$diveplan);
        unlink($diveplan);
        open(PLAN,">$diveplan") and print(PLAN "$plan\n") and close(PLAN);
    }
}

__END__

