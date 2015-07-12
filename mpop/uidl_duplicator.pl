#!/usr/bin/perl -w

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

my $dup_count = 0;
while (my @res = each %data)
{
    $dup_count += 1 if (duplicate_test($res[0], $res[1]) == 1);
}
print "duplicated id: $dup_count\n";

sub duplicate_test
{
    my $imap_id = shift;
    my $array = shift;

    my %hash;
    foreach my $element (@$array)
    {   
        $hash{$element}++;
    }   

    foreach my $element (keys (%hash))
    {   
        if($hash{$element} > 1)
        {   
            print "duplicate: $imap_id, folder: $element, times: $hash{$element}\n";
            return 1;
        }   
    }   
    return 0;
}

sub process_file
{
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {
        if($_ =~ /\s<== (.*) \[(.*)\]\]\s\[STORE\] uid: (\d*),\stime:\s(\d*)\(threshold:\s(\d*)\),\sfolder:\s(\d*)/)
        {
            #print "email: $1\n";
            #print "server: $2\n";
            #print "time: $4\n";
            my $id = $3;
            my $folder = $6;

            # is message stored, or deleted ?
            my $result_of_store = undef;
            while (<$fh>)
            {
                if ($_ =~ /Store message OK \[uid: (\d*)]/)
                {
                    next if ($1 != $id);
                    $result_of_store = 1;
                    last;
                }
                elsif ($_ =~ /Error storing message:\s(.*?)\s\[uid: (\d*),/)
                {
                    next if ($2 != $id);
                    $result_of_store = 0;
                    last;
                }
            }

            if (!defined ($result_of_store))
            {
                print "LOG FILE IS BROKEN: $file\n";
                exit 1;
            }

            next if ($result_of_store == 0);

            push (@{$data->{$id}}, $folder);
        }
    }
    close $fh;
}
