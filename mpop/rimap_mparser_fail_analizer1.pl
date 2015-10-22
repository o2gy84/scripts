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
    # Теперь %data содержит хеш, в котором ключ - это строка с ошибокй,
    # а значение - это массив из хешей, в каждом из которых ключ -
    # это имап-сервер, а значение - емейл юзера.
    # Пример:
=k

'Server returned NO RESPONSE upon command: UID COPY[]. Server answer: xx NO UID COPY failed 111' => [
                                                                                                       {
                                                                                                        'mail.tesco.net' => 'AAA@tesco.net'
                                                                                                       },
                                                                                                       {
                                                                                                        'mail.tesco.net' => 'BBB@tesco.net'
                                                                                                       }
                                                                                                      ],
'Server returned NO RESPONSE upon command: UID COPY[]. Server answer: xx NO UID COPY failed 222' => [
                                                                                                     {
                                                                                                      'mail.tesco.net' => 'AAA@tesco.net'
                                                                                                     }
                                                                                                    ],
=cut
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

# Перебираем ключи в таком порядке: сначала идут те ошибки,
# которые встречались чаще
foreach my $key (@k)
{
    my $arr_len = scalar(@{$data{$key}});
    print "count: $arr_len, e: $key\n";
    print_error_stat( $data{$key} );
}

sub print_error_stat
{
    my $arr = shift;    # arr - это массив хешей, server => user
    my %result_hash;
    my %result_count_hash;

    foreach my $elem (@$arr)                    # elem = (server, email)
    {
        my ($key, $value) = each %{$elem};      # тут всегда 1 элемент
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
