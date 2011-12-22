#!/usr/bin/env perl

use strict;
use warnings;

use RRDs;
use Data::Dumper;

my $fn = $ARGV[0];

my $end_time = time - 60*10;
my $start_time = $end_time - 86400;

my ($start, $step, $names, $data) = RRDs::fetch(
    $fn,
    "MAX", # consolidation function
    "--start" => $start_time,
    "--end" => $end_time,
);

print Dumper($data);
