#!/usr/bin/perl -w

use strict;

if(not defined $ARGV[0])
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
    #if(($#res + 1))
    #print "$res[0] = $res[1]\n"
    if(maybe_dupl($res[1]) == 1)
    {   
        print "maybe duplicate. uid: $res[0]\n";
    }   
}

sub maybe_dupl
{
    my $array = shift;
    my %hash;
    foreach my $element (@$array)
    {   
        $hash{$element}++;
    }   

    foreach my $element (keys (%hash) )
    {   
        if($hash{$element} > 1)
        {   
            print "found folder: $element, saving $hash{$element} times\n";
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

        if($_ =~ /\@external <== (.*) \[(.*)\]\]\s\[STORE\] uid: (\d*),\stime:\s(\d*)\(threshold:\s(\d*)\),\sfolder:\s(\d*)/)
        {
            #print "email: $1\n";
            #print "server: $2\n";
            #print "uid: $3\n";
            #print "time: $4\n";
            #print "folder: $6\n";

            push (@{$data->{$3}}, $6);
        }
    }
    close $fh;
}