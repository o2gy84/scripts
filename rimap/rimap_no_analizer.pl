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
    process_file_server_answer_NO(\%data, $file);
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
    my $arr = shift;    # server => user
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
            print "\t\t$email, times: $result_count_hash{$email}\n";
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

    print "\n============================================================\n";
}

sub process_file_server_answer_NO
{
=k
[#65306:eliseev56@list.ru <== a22011956e@yandex.ru [imap.yandex.ru]] [SERVER] NO: SELECT> (*.). Server answer: 18 NO [NONEXISTENT] Unknown Mailbox: ololo(*). Rimap line: 18 SELECT (*)
=cut
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {
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
            $error =~ s/Refer to server log for more information\. (.*)/Refer to server log for more information/;
            $error =~ s/\s*(\d*)\s/1 /;
            $error =~ s/MARKER:(.*)/MARKER: /;
            $error =~ s/marker: (.*)/marker: /;
            $error =~ s/\d+ NO sock->write\(FETCH uid,(\d+),\(RFC822.SIZE BODY.PEEK\[\]\)\) FAILED/num NO sock->write(FETCH uid,num,(RFC822.SIZE BODY.PEEK[])) FAILED/;
            $error =~ s/\d+ NO STATUS Mailbox not found: (.*)/num NO STATUS Mailbox not found: folder_name/;
            $error =~ s/\d+ NO STATUS failed: Can't get status of mailbox (.*): no such mailbox/num NO STATUS failed: Can't get status of mailbox ** folder_name **: no such mailbox/;
            $error =~ s/\d+ NO Mailbox doesn't exist:(.*)/num NO Mailbox doesn't exist: folder_name/;
            $error =~ s/\d+ NO Invalid mailbox name:(.*)/num NO Invalid mailbox name: folder_name/;
            $error =~ s/For input string: (.*)/For input string: "ololo"/;
            $error =~ s/NO Unrecognized internal error:(.*)/NO Unrecognized internal error: ololo/;
            $error =~ s/NO Unable to open file(.*)/NO Unable to open file ololo/;

            push (@{$data->{$error}}, \%tmp);
        }
    }
    close $fh;
}

