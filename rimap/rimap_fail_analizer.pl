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
    process_file_rimap_failure(\%data, $file);
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

sub process_file_rimap_failure
{
=k
[#65306:eliseev56@list.ru <== a22011956e@yandex.ru [imap.yandex.ru]] Failure: collected 0 messages, 786 bytes in. Time: 0s, Downtime: 928s, DowntimeAfterSuccess: 950072s, SQL: 2ms, KAV: 0ms, KAS: 0ms, MRAS: 0ms, Delivery: 0ms, Contacts: 0ms, UserLookup: 1ms, Connect: 53ms, Read: 232ms, Write: 0ms, Mailbox: 0ms, Network: 190ms, Hermes: 0ms, Rico: 2ms, Mso: 16ms, mmrd: 0, forced: 0, dry: 1  E: parent folder with ID = 5 not found at eliseev56@list.ru
=cut
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {
        if($_ =~ /#\d*:(.*)\s<==\s.*\s\[(.*)\]\]\sFailure:\s.*\sE:(.*)/)
        {
            my $user = $1;
            my $server = $2;
            
            my %tmp;
            $tmp{$server} = $user;

            my $error = $3;
            next if $error =~ /read failed/;
            next if $error =~ /async read timeout/;
            next if $error =~ /Connection reset by peer/;
            next if $error =~ /ParseSyncResponse failure/;
            next if $error =~ /Invalid destination collection ID/;
            next if $error =~ /WBXML Parser Error/;
            next if $error =~ /Error while appending message/;
            next if $error =~ /Unknown http code/;
            next if $error =~ /skipped because not founded remote_folder_id for id/;

            $error =~ s/parent folder with ID =\s(\d*)\snot found at\s(.*)/parent folder with ID = X not found/;
            $error =~ s/Try later. sc=(.*)/Try later. sc=/;
            $error =~ s/.*NO \[UNAVAILABLE\] XLIST Backend error.*/NO \[UNAVAILABLE\] XLIST Backend error/;
            $error =~ s/sc=.*$/sc=/;

            push (@{$data->{$error}}, \%tmp);
        }
    }
    close $fh;
}
