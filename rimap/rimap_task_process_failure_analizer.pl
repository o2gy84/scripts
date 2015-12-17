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

my $TRESHOLD = 0;
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
    my $arr = shift;
    my %result_hash;
    my %result_count_hash;

    foreach my $elem (@$arr)                    # elem = (server, email)
    {
        my ($key, $value) = each %{$elem};
        push( @{$result_hash{$key}}, $value);
        $result_count_hash{$value}++;
    }

    foreach my $el (keys (%result_hash) )
    {
        my %tmp = map {$_ => 1} @{$result_hash{$el}};
        my @uniq = keys %tmp;
        $result_hash{$el} = \@uniq;
    }

    my %err_frequency;                         # imap.aol.com => 10 times, imap.wp.pl => 1000 times e.t.c.

    foreach my $element (keys (%result_hash) )
    {
        my $total_items = 0;
        foreach my $email ( @{$result_hash{$element}} ) { $total_items += $result_count_hash{$email}; }

        $err_frequency{$element} = $total_items;
        print "\t[$element], total: $total_items\n";
        foreach my $email ( @{$result_hash{$element}} )
        {
            if ($result_count_hash{$email} > $TRESHOLD)
            {
                print "\t\t$email, times: $result_count_hash{$email}\n";
            }
        }
    }

    print "\ntop domains:";
    my $top_count = 0;
    foreach my $server (sort { $err_frequency{$b} <=> $err_frequency{$a} } keys %err_frequency)
    {
        last if ($top_count >= 10);
        print "," if ($top_count > 0);
        printf " $server: " . $err_frequency{$server};
        $top_count += 1;
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
[#70212838:proboszcz22@vp.pl@external <== proboszcz22@vp.pl [imap.poczta.onet.pl]] Task process failed: connect failed : Connection timed out
=cut
        if($_ =~ /#\d*:(.*)\s<==\s.*\s\[(.*)\]\]\sTask process failed:\s(.*)/)
        {
            my $user = $1;
            my $server = $2;
            
            my %tmp;
            $tmp{$server} = $user;

            my $error = $3;
            #next if $error =~ /read failed/;
            #next if $error =~ /async read timeout/;
            #next if $error =~ /Connection reset by peer/;
            #next if $error =~ /ParseSyncResponse failure/;
            #next if $error =~ /Invalid destination collection ID/;
            #next if $error =~ /WBXML Parser Error/;
            #next if $error =~ /Error while appending message/;
            #next if $error =~ /Unknown http code/;
            #next if $error =~ /skipped because not founded remote_folder_id for id/;

            #$error =~ s/parent folder with ID =\s(\d*)\snot found at\s(.*)/parent folder with ID = X not found/;
            #$error =~ s/Try later. sc=(.*)/Try later. sc=/;
            #$error =~ s/.*NO \[UNAVAILABLE\] XLIST Backend error.*/NO \[UNAVAILABLE\] XLIST Backend error/;
            #$error =~ s/sc=.*$/sc=/;

            push (@{$data->{$error}}, \%tmp);
        }
    }
    close $fh;
}

