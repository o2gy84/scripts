#!/usr/bin/perl

$|=1;
use strict;
use lib '/usr/local/mpop/lib';
use mPOP;
use mPOP::Domain (preload=>1);

my $pmPOP = mPOP::Get();

my ($username, $domain) = split ('@',shift,2);
my $folderid = shift;
my $foldername = shift;
die "Usage: $0 <email> <folderID> <folder name>\n" unless ($username and $domain and defined $folderid and $foldername);

my $path = $pmPOP->GetMailboxPath($username, $domain) or die 'Cannot get path for mailbox';

my $pMailbox = Mailbox::open($path) or die 'Cannot open mailbox!';

$pMailbox->AddFolder($folderid,$foldername);
$pMailbox->Commit(0);
$pMailbox->Close();
