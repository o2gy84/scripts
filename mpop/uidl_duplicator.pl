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

while (my @res = each %data)
{
    my $dups = get_duplicates($res[1]);

    if (keys %{$dups})
    {
        foreach my $dup (keys %{$dups})
        {
            foreach my $folders (@{$dups->{$dup}})
            {
                foreach my $folder (keys %{$folders})
                {
                    print "email: $res[0], uid: $dup, folder: $folder, count: $folders->{$folder}\n";
                }
            }
        }
    }
}

sub get_duplicates
{
    my $ids = shift;

    my %result;

    foreach my $id (keys %{$ids})
    {
        my %dups_hash;

        my $folders_array = $ids->{$id};
        for my $folder (@{$folders_array})
        {
            $dups_hash{$folder}++;
        }

        foreach my $folder (keys %dups_hash)
        {
            if ($dups_hash{$folder} > 1)
            {
                my $dup = {$folder => $dups_hash{$folder}};
                push @{$result{$id}}, $dup;
            }
        }
    }

    return \%result;
}

sub process_file
{
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {
        if($_ =~ /\s<== (.*) \[(.*)\]\]\s\[STORE\] (OK|FAIL), uid: (\d*),\stime:\s(\d*)\(threshold:\s(\d*)\),\sfrom:\s.*,\sto:\s(\d*),/)
        {
            #print "email: $1\n";
            #print "server: $2\n";
            #print "RESULT: $3\n";
            #print "uid: $4\n";
            #print "time: $5\n";
            #print "folder_to: $7\n";

            next if ($3 eq 'FAIL');

            my $email = $1;
            my $id = $4;
            my $folder = $7;

            push @{$data->{$email}{$id}}, $folder;
        }
    }
    close $fh;
}
