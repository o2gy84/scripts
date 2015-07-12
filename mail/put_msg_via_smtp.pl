#!/usr/bin/perl -w

=k

using: ./putmsg.pl eml/message/3/bad_links.eml

deps:
1) sudo yum -y install perl-Authen-SASL
2) perl-SMTP
3) perl-SMTP-SSL

=cut

use Net::SMTP;
use Net::SMTP::SSL;
use strict;

if (not defined $ARGV[0])
{
    print "need filename as cmd argument\n";
    exit 0;
}

my $u = 'email@domain.com';
my $p = 'pass';
my $smptp = 'smtp.mail.ru';

my ($host,$username,$password) = ($smptp, $u, $p);

my @data;
open my $fh,"<$ARGV[0]" or die "cant open";

while (<$fh>) {
    s/^To: [^\n\r]*/To: $username/;
    s/^ReSent-From: [^\n\r]*?(,?\r?)$/ReSent-From: $username$1/;
    push @data,$_;
}
close $fh;
shift @data if $data[0] =~ /From .*\n/;

my $smtp = ($host ne '173.194.71.109') ? Net::SMTP->new($host,Debug=>1) : Net::SMTP::SSL->new($host, Port => 465,Debug=>1);
unless ($smtp) {
    print "error $@\n";
    exit 0;
}
$smtp->auth($username,$password) or print "!!! NO AUTHORIZATION !!!\n";
$smtp->mail($username);
$smtp->to($username);
#$smtp->to('k.valiev@corp.mail.ru');
$smtp->data();
foreach (@data) {
    $smtp->datasend($_);
}
$smtp->datasend();
$smtp->quit;
