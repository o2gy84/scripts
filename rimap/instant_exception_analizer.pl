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
    process_file_instant_exceptions(\%data, $file);
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

sub process_file_instant_exceptions
{
=k
[IGNORED] sync folder exception: Server returned BAD RESPONSE upon command:     FETCH[13:Junk]. Server answer: 9 BAD Error in IMAP command FETCH: Invalid messageset. Rimap line: 9 FETCH 126:* (UID FLAGS)
=cut
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {
        if($_ =~ /#\d*:(.*)\s<==\s.*\s\[(.*)\]\]\s.*\bexception: (.*)/)
        {
            my $user = $1;
            my $server = $2;
 
            # $message !~ "\bCan't lock user\b"
            my %tmp;
            $tmp{$server} = $user;

            my $error = $3;

            $error =~ s/FETCH\[(\d+):(\w+)\]/FETCH[num:Folder]/;
            $error =~ s/Rimap line: (\d+) FETCH/Rimap line: num FETCH/;
            $error =~ s/Server answer: (\d+) BAD/Server answer: num BAD/;
            $error =~ s/ETCH (\d+):/ETCH num:/;

            $error =~ s/Server returned BAD RESPONSE upon command: FETCH(.*)\sServer answer: (\d*) BAD Error in IMAP command FETCH: Invalid messageset. (.*)/Server returned BAD RESPONSE upon command: FETCH[num:Folder]. Server answer: num BAD Error in IMAP command FETCH: Invalid messageset. Rimap line: xxx/;

            $error =~ s/Server returned BAD RESPONSE upon command: FETCH(.*)\sServer answer: (\d*) BAD \[CLIENTBUG\] FETCH Bad sequence in the command. (.*)/Server returned BAD RESPONSE upon command: FETCH[num:Folder]. Server answer: num BAD [CLIENTBUG] FETCH Bad sequence in the command. Rimap line: yyy/;

            $error =~ s/Server returned BAD RESPONSE upon command: FETCH(.*). Server answer: (\d*) BAD parse error: invalid message sequence number: 1:*. Rimap line: (\d*) FETCH 1:* (UID FLAGS)/Server returned BAD RESPONSE upon command: FETCH[13:Junk]. Server answer: 97 BAD parse error: invalid message sequence number: 1:*. Rimap line: num FETCH 1:* (UID FLAGS)/;

            push (@{$data->{$error}}, \%tmp);
        }
    }
    close $fh;
}

