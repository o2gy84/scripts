#!/usr/bin/perl -w

use IMAP;
use Data::Dumper;

my ($HOST,$USERNAME,$DOMAIN,$PASSWORD) = ('imap.gmail.com','imap.test.13','gmail.com','imaptest3');
my ($SSL,$STARTTLS) = (1,0);
my $c;
{ local $/ = undef;  $c = <DATA>;}
$c =~ s/\n/\r\n/g;
print length $c,"\n";

my $folder_to_append = '[Gmail]/&BB4EQgQ,BEAEMAQyBDsENQQ9BD0ESwQ1-';
#my $folder_to_append  = 'INBOX';

append('test');


sub append {
    my $imap = IMAP->new($HOST,'ssl' => $SSL,'starttls'=>$STARTTLS,'debug'=>1,'startid'=>20,'debug'=>1) or die("cant connect to imap server $@\n");

    $imap->login("$USERNAME\@$DOMAIN", $PASSWORD) or die("cant login with '$USERNAME\@$DOMAIN' '$PASSWORD'\n");
#    unless ($imap->create_mailbox($folder)) {
#        die("cant create folder with error: '" . $imap->errstr()."'\n");
#    }
    #if ($imap->append($c,'inbox') != 1) {
    if ($imap->append($c, $folder_to_append) != 1) {
        die("append error '" .$imap->errstr() ."'\n");
    }
    print Dumper $imap->{response};
}

__DATA__
Date: Wed, 21 Dec 2011 20:01:18 +0400 (GMT+04:00)
From: Petya444 <petya@mail.ru>
To: Vasya444 vasya@mail.ru
Subject: Petya Vasya 4445
Message-ID: <6789@mail.ru>

ONE MESSAGE ID
