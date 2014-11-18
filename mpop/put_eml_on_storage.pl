#!/usr/bin/perl
$|=1;
use strict;
use lib '/usr/local/mpop/lib';
use mPOP;
use mPOP::Domain (preload=>1);

my $pmPOP = mPOP::Get();

my ($username, $domain) = split ('@',shift,2);
die "Usage: $0 <email> <msg_file> <folder_id>\n" unless ($username and $domain);

my $file = shift or die "Usage: $0 <email> <msg_file> <folderid>\n";

my $folderid = shift || 0;

my $path = $pmPOP->GetMailboxPath($username, $domain,1) or die 'Cannot get path for mailbox';
print "path is: $path\n";
my $pMailbox = Mailbox::open($path) or die 'Cannot open mailbox!';

my $message=LoadFromFile($file);
my $Message=$pMailbox->Add($folderid,0,0);
$Message->Put($message);
print $Message->Flush(0),"\n";
$pMailbox->Close();

sub LoadFromFile {
    my $file = shift;
    local $/ = undef;
    open my $fh, "<$file" or die "cant open file $file";
    my $message= <$fh>;
    close $fh;
    return $message;
}
