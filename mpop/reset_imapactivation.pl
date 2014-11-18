#!/usr/bin/perl

use strict;
use IO::Socket::INET;
use lib qw(/usr/local/mpop/lib/i386-linux-thread-multi/ /usr/local/mpop/lib);
use DBI;
use mPOP;
use mPOP::Profile;
use mPOP::Domain (preload=>1);

my $pmPOP = mPOP::Get();

my $limit = 100000;
my $sleep_sec = 0.1;   # 100 millisec

my $offset = 0;
my $max_id = 0;

my $dbh = mPOP::GetRPOPDB();
my $q = $dbh->query("select MAX(rpop.imap.ID) from rpop.imap");
if(my @a = $q->fetchrow()) {
    $max_id = $a[0];
}

if($max_id == 0)
{
    print "error to calculate max id\n";
    return 1;
}
else
{
    print "max_id: $max_id\n";
}

my $count = 0;
my $affected_count = 0;
while( ($offset - $limit) < $max_id)
{
    my $threshold = $offset + $limit;
    my $q = $dbh->query("select rpop.imap.ID, rpop.imap.UserId from rpop.imap where rpop.imap.ID >= $offset AND rpop.imap.ID < $threshold");

    while(my @a = $q->fetchrow())
    {
        $count = $count + 1;
        my $userid = $a[1];

        eval
        {
            my $pProfile = mPOP::Profile->New($pmPOP);
            $pProfile->Open(undef, undef, $userid, 1);
            if ($pProfile->IsOpen())
            {
                my $val = $pProfile->GetField('ImapActivationInProgress');
                if( !defined $val || $val ne '0' )
                {
                    $affected_count = $affected_count + 1;
                    $pProfile->SetFields({'ImapActivationInProgress' => 0});
                }
                $pProfile->Close();
            }
            $pmPOP->Free();
        };
    }

    print "progress: $offset from $max_id\n";
    select(undef, undef, undef, $sleep_sec);
    $offset = $offset + $limit;
}

print "count: $count, affected: $affected_count\n";

