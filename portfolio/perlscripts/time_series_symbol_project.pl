#!/usr/bin/perl -w

use Getopt::Long;

$#ARGV>=2 or die "usage: time_series_symbol_project.pl symbol steps-ahead model \n";

$symbol=shift;
$steps=shift;
$model=join(" ",@ARGV);

system "/home/bsr618/www/portfolio/perlscripts/get_data.pl --notime --close $symbol > /home/bsr618/www/portfolio/perlscripts/_data.in";
system "/home/bsr618/www/portfolio/perlscripts/time_series_project /home/bsr618/www/portfolio/perlscripts/_data.in $steps $model 2>/dev/null";

