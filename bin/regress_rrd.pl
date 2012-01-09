#!/usr/bin/env perl

use strict;
use warnings;

use RRDs;
use Time::Piece;

my $BEGIN = time;

# Date range which we do regression on.
my $end_time = $BEGIN - 60*30;
my $start_time = $end_time - 86400*7;

# How far into the future will we predict disc full?
my $TIME_AFTER_WHICH_WE_NO_LONGER_CARE = $BEGIN+86400*60;

my @ttl;

foreach my $rrd (</var/lib/rrd/munin/*/*-df-_*.rrd>) {
    my $ls = rrd_least_squares($start_time, $end_time, $rrd);

    if (!defined $ls) {
#        print "no data for $rrd\n";
        next;
    }
    elsif ($ls == -1) {
        # Usage flat, ignore.
        next;
    }
    elsif ($ls > $BEGIN && $ls < $TIME_AFTER_WHICH_WE_NO_LONGER_CARE) {

        push @ttl, [
            $rrd, $ls
        ];
    }
}

@ttl = sort { $a->[1] <=> $b->[1] } @ttl;

foreach my $t (@ttl) {
    $t->[0] =~ /\/([^\/]+)-df-_(.+)\.rrd/;

    print "$1,$2,".Time::Piece->new($t->[1])->datetime."\n";
}


exit 0;

sub rrd_least_squares {
    my ($start_time, $end_time, $filename) = @_;

    my ($start, $step, $names, $data) = RRDs::fetch(
        $filename,
        "MAX", # consolidation function
        "--start" => $start_time,
        "--end" => $end_time,
    );


    my $now = $start;

    my $x_sum=0;
    my $y_sum=0;
    my $points=0;

    foreach my $row (@{ $data }) {
        if (defined $row->[0]) {
            $x_sum += $now;
            $y_sum += $row->[0];

            $points++;
        }

        $now += $step;
    }

    return unless $points;

    my $x_avg = $x_sum / $points;
    my $y_avg = $y_sum / $points;

    my $nom = 0;
    my $dem = 0;

    $now = $start;

    foreach my $row (@{ $data }) {
        if (defined $row->[0]) {
            $nom += ($now - $x_avg) * ($row->[0] - $y_avg);
            $dem += ($now - $x_avg)*($now - $x_avg);
        }

        $now += $step;
    }

    # If disc space usage is flat.
    return -1 unless $nom;

    my $m = $nom / $dem;

    my $c = $y_avg - $m*$x_avg;

    # y = mx+c
    # Find x for y=100
    # x = (y-c)/m

    my $x_fail = (100-$c)/$m;

    return $x_fail;
}
