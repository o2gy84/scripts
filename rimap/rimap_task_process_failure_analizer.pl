#!/usr/bin/perl -w

use strict;
my $TRESHOLD = 0;           # show errors, whose count is greater than the threshold

if(not defined $ARGV[0])
{
    print "need filename as cmd argument\n";
    exit 0;
}

my %data;
foreach my $file (@ARGV)
{
    process_file_task_process_failed(\%data, $file);
    #process_file_server_answer_NO(\%data, $file);
    #process_file_mparser_failed(\%data, $file);
    #process_file_rimap_failure(\%data, $file);
    #process_file_instant_exceptions(\%data, $file);
}

=k
data - is hash:
'error1_text' => [ { 'mail.tesco.net' => 'AAA@tesco.net', }, { 'mail.tesco.net' => 'BBB@tesco.net' } ],
'error2_text' => [ { 'mail.tesco.net' => 'AAA@tesco.net'  } ],
=cut

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

    print "\n============================================================\n";
}

sub process_file_task_process_failed
{
=k
[#70212838:proboszcz22@vp.pl@external <== proboszcz22@vp.pl [imap.poczta.onet.pl]] Task process failed: connect failed : Connection timed out
=cut
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {
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

sub process_file_mparser_failed
{
=k
    [#11306358:sergey.belozor@azurair.com@external <== sergey.belozor@azurair.com [mail.azurair.com]] [MPARSER] Failed move msg [uidl: 1449146632:1, folder_from: 3, folder_to: 950]: unknown error
=cut
    my $data = shift;
    my $file = shift;

    open my $fh,"<$file" or die "cant open file";
    while (<$fh>)
    {

        if($_ =~ / <==\s(.*)\s\[(.*)\]\]\s\[.*\]:\s(.*)/)
        {
            #print "user: $1\n";
            #print "serv: $2\n";
            #print "err: $3\n";

            my %tmp;
            $tmp{$2} = $1;

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

            $error =~ s/Server answer:\s(\d*)\s/Server answer: xx /;
            $error =~ s/Refer to server log for more information. \[.*\]/Refer to server log for more information. \[yy\]/;
            $error =~ s/Failed to delete folder\s(.*)\s*sc=.*/Failed to delete folder $1 sc=zzz/;
            $error =~ s/\.$//;
            $error =~ s/NO RESPONSE upon command: SELECT\[\]. Server answer: xx NO .* doesn't exist/NO RESPONSE upon command: SELECT[]. Server answer: xx NO ccc doesn't exist/;
            $error =~ s/DELETE command failed: backend error: Failed to delete folder (.*)\ssc=zzz/DELETE command failed: backend error: Failed to delete folder vvvv  sc=zzz/;
            $error =~ s/reque?st:\s(\d*)\sAPPEND ".*" \(.*\) \{.*\}, response:\s(\d*)\sOK \[APPENDUID\s\d*\s\d*\] APPEND Completed/requst: bb APPEND "fname" (flags) {size}, response: bb OK [APPENDUID nn] APPEND Completed/;
            $error =~ s/Duplicate folder name\s(.*)\s\(Failure\)/Duplicate folder name sssss (Failure)/;
            $error =~ s/xx BAD Server error: .*$/xx BAD Server error: LLLL/;
            $error =~ s/can not find the mail,id\s(\d*)/can not find the mail,id xx/;
            $error =~ s/marker:\s(.*)$/marker: ololo/;
            $error =~ s/request:\s(\d*)\sAPPEND "Sent" \(.*\) \{(\d*)\}/request: 1 APPEND "Sent" (\\Seen) {777}/;
            $error =~ s/response:\s(\d*)\sOK \[APPENDUID\s(\d*)\s(\d*)\] APPEND completed]/response: 2 OK [APPENDUID 111 222] APPEND completed]/;

            push (@{$data->{$error}}, \%tmp);
        }
    }
    close $fh;
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

