#!/usr/bin/perl -w

use strict;

if ((not defined $ARGV[0]) || (not defined $ARGV[1]))
{
    print "usage: $0 users1 users2 [users_excluded]\n";
    exit 0;
}

my %aborted_users;
my %users1;
my %users2;

process_file(\%users1, $ARGV[0]);
process_file(\%users2, $ARGV[1]);
process_file(\%aborted_users, $ARGV[2]) if (defined $ARGV[2]);

#use Data::Dumper;
#warn Dumper \%aborted_users;

while (my @tmp = each %users1)
{
    my $user = $tmp[0];
    if (!exists $users2{$user} && !exists $aborted_users{$user})
    {
        print "disapeared: $user\n";
    }
}

sub process_file
{
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {
        chomp($_);
        $_ =~ s/(.*)\@external/$1/;
        $data->{$_} = '';
    }
    close $fh;
}

