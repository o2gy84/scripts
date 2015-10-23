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

my %sorted_keys;
while (my @tmp = each %data)
{
    my $arr_len = scalar(@{$tmp[1]});
    $sorted_keys{$tmp[0]} = $arr_len;
}

my @k = sort { $sorted_keys{$b} <=> $sorted_keys{$a};} keys %sorted_keys;

foreach my $key (@k)
{
    my $arr_len = scalar(@{$data{$key}});
    print "count: $arr_len, e: $key\n";
    print_error_stat( $data{$key} );
}

sub print_error_stat
{
    my $arr = shift;    # arr - ýòî ìàññèâ õåøåé, server => user
    my %result_hash;
    my %result_count_hash;

    foreach my $elem (@$arr)                    # elem = (server, email)
    {
        my ($key, $value) = each %{$elem};      # òóò âñåãäà 1 ýëåìåíò
        push( @{$result_hash{$key}}, $value);
        $result_count_hash{$value}++;
    }

    foreach my $el (keys (%result_hash) )
    {
        my %tmp = map {$_ => 1} @{$result_hash{$el}};
        my @uniq = keys %tmp;
        $result_hash{$el} = \@uniq;
    }

    foreach my $element (keys (%result_hash) )
    {
        print "\t[$element]\n";
        foreach my $email ( @{$result_hash{$element}} )
        {
            print "\t\t$email, times: $result_count_hash{$email}\n";
        }
    }
    print "\n";
}

sub process_file
{
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {
=k
[#65306:eliseev56@list.ru <== a22011956e@yandex.ru [imap.yandex.ru]] [SERVER] NO: SELECT> (*.). Server answer: 18 NO [NONEXISTENT] Unknown Mailbox: ololo(*). Rimap line: 18 SELECT (*)
=cut
        if($_ =~ /#\d*:(.*)\s<==\s.*\s\[(.*)\]\]\s\[SERVER\] NO:\s.*\sServer answer:(.*)\. Rimap line: /)
        {
            my $user = $1;
            my $server = $2;
            
            my %tmp;
            $tmp{$server} = $user;

            my $error = $3;
            next if $error =~ /Unknown http code/;
            next if $error =~ /skipped because not founded remote_folder_id for id/;

            $error =~ s/Try later. sc=(.*)/Try later. sc=/;
            $error =~ s/.*NO \[UNAVAILABLE\] XLIST Backend error.*/NO \[UNAVAILABLE\] XLIST Backend error/;
            $error =~ s/sc=.*$/sc=/;
            $error =~ s/.*\sNO \[NONEXISTENT\] Unknown Mailbox: .*/1 NO [NONEXISTENT] Unknown Mailbox: name/;
            $error =~ s/\s*(\d*)\s/1 /;

            push (@{$data->{$error}}, \%tmp);
        }
    }
    close $fh;
}
