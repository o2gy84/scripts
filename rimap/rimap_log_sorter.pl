#!/usr/bin/perl

use Time::Local;
use POSIX qw( strftime );

use strict;

if (not defined $ARGV[0])
{
    print "need filename as cmd argument\n";
    exit 0;
}

my %data;
foreach my $file (@ARGV)
{
    process_file(\%data, $file);
}

#use Data::Dumper;
#warn Dumper \%data;

foreach my $key (sort {$a <=> $b} keys %data)
{
    my $dt = strftime("%b %d %H:%M:%S", localtime($key));
    foreach my $logstring (@{$data{$key}})
    {
        print "$dt " . $logstring . "\n";
    }
}

sub month_to_num
{
    my $m = shift;
    return  0 if $m eq 'Jan';
    return  1 if $m eq 'Feb';
    return  2 if $m eq 'Mar';
    return  3 if $m eq 'Apr';
    return  4 if $m eq 'May';
    return  5 if $m eq 'Jun';
    return  6 if $m eq 'Jul';
    return  7 if $m eq 'Aug';
    return  8 if $m eq 'Sep';
    return  9 if $m eq 'Oct';
    return 10 if $m eq 'Nov';
    return 11 if $m eq 'Dec';
    die "bad date!";
}

sub process_file
{
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {
        #Apr  2 12:20:36 collector11 collector[5532]:
        #Apr 28 04:46:22 collector10
        if ($_ =~ /(\w\w\w)\s\s?(\d*?)\s(.*?)\s(.*?)\s(.*?)\s(.*)/)
        {
            my $month = month_to_num($1);
            my $day = $2;
            my ($hour, $min, $sec) = split(':', $3);
            my $time = timelocal($sec, $min, $hour, $2, month_to_num($1), 2015);
            my $serv = $4;
            my $log_string = $4 . ' ' . $6;
            push (@{$data->{$time}}, $log_string);
            push (@{$data->{$time}}, "+++\n") if($_ =~ /\[UNLOCK\]:/);
        }
    }
    close $fh;
}
