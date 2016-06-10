#!/usr/bin/perl

use Time::Local;
use POSIX qw( strftime );
use Data::Dumper;

use strict;

if (not defined $ARGV[0])
{
    print "need filename as cmd argument\n";
    exit 0;
}

my $looking_forward_for_N_seconds_first_threshold = 20;   # в течении этого времени определяем, сколько писем скачали в какие папки

my %data;
foreach my $file (@ARGV)
{
    process_file(\%data, $file);
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

sub get_timestamp_from_log_string
{
    #Apr  2 12:20:36 collector11 collector[5532]:
    #Apr 28 04:46:22 collector10

    my $line = shift;

    # empty lines
    return 0 if length($line) < 3;

    if ($line =~ /(\w\w\w)\s\s?(\d*?)\s(.*?)\s(.*?)\s(.*?)\s(.*)/)
    {
        my $month = month_to_num($1);
        my $day = $2;
        my ($hour, $min, $sec) = split(':', $3);
        my $time = timelocal($sec, $min, $hour, $day, month_to_num($1), 2016);
    }
    else
    {
        die "bad date: $line\n";
    }
}

sub process_file
{
    my $data = shift;
    my $file = shift;
    
    open my $fh,"<$file" or die "cant open file";
    chomp (my @lines = <$fh>);
    
    my $count = scalar(@lines);

    for (my $i = 0; $i < $count; $i++)
    {
        my $line = $lines[$i];

        if ($line =~ /collector(\d+)\s.+\s<==\s([^ ]+)\s.+\s\[COLLECTOR\] first collect at:\s(\d+) sec/)
        {
            my $collector = $1;
            my $user = $2;
            my $first_collect_at = $3;

            # надо заглянуть вперед на N секунд, и посмотреть сколько писем успели скачать
            my $time_first_collect = get_timestamp_from_log_string($line);
            my $time_in_future = $time_first_collect + $looking_forward_for_N_seconds_first_threshold;
            my $first_success_at = -1;
            my $read_failed = 0;
            my $no_msg = 0;
            my $invalid_token = 0;
            my $no_token = 0;
            my $have_messages_from_inbox = 0;
       
            my %messages;

            for (my $j = $i + 1; $j < $count; $j++)
            {
                my $inner_line = $lines[$j];
                #print "[DEBUG] inner line: $inner_line\n";

                # надо пропускать все строчки, которые не относятся к юзеру $user
                if ($inner_line =~ /\s<==\s([^ ]+)\s/)
                {
                    my $inner_user = $1;
                    next if $inner_user ne $user;
                }
                else
                {
                    next;
                }

                my $cur_time = get_timestamp_from_log_string($inner_line);

                if ($inner_line =~ /\[STORE\] (OK|FAIL), .*, from: ([^,]+),/)
                {
                    # записываем инфу о сохраненных письмах только в пределах указанного временного диапазона
                    my $store_ok = ($1 eq 'OK')? 1 : 0;
                    my $folder = $2;
                    if ($folder =~ /'(.+)'/) { $folder = $1; }

                    if ($cur_time <= $time_in_future)
                    {
                        $messages{$folder}++ if $store_ok == 1;
                    }
                    else
                    {
                        # по крайней мере были попытки сохранить в inbox
                        $have_messages_from_inbox = 1 if ($folder =~ /^inbox$/i);
                    }
                }
                elsif ($inner_line =~ /\[COLLECTOR\] first success at:\s(\d+) sec/)
                {
                    $first_success_at = $1;
                }
                elsif ($inner_line =~ /\[RIMA\] success put force newuser_priority task/)
                {
                    $read_failed = 1;
                    last;
                }
                elsif ($inner_line =~ /\[SESSION\] folders: \d+, synced: \d+, debt: \[\d+,0,/)
                {
                    # дальше этой строчки пасить сессию не имеет смысла
                    $no_msg = 1;
                    last;
                }
                elsif ($inner_line =~ /Fake server message, to emulate extra_auth/)
                {
                    $no_token = 1;
                    last;
                }
                elsif ($inner_line =~ /\[XOAUTH2\] Old token is invalid/)
                {
                    # дальше этой строчки пасить сессию не имеет смысла
                    $invalid_token = 1;
                    last;
                }
                elsif ($inner_line =~ /\]\] Failure: collected\s/)
                {
                    last;
                }
                elsif ($inner_line =~ /\]\] Success: collected\s/)
                {
                    last;
                }
            }

            print "$user collector$collector ts:$time_first_collect collect_at:$first_collect_at success_at:$first_success_at ";
            print "readfail:$read_failed nomsg:$no_msg inboxnot1:$have_messages_from_inbox badtoken:$invalid_token notoken:$no_token";
            foreach my $key (keys %messages)
            {
                print " '$key:$messages{$key}'";
            }
            print "\n";
        }
    }
    close $fh;
}

