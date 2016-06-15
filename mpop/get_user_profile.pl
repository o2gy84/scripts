#!/usr/bin/perl

use strict;
use IO::Socket::INET;
use lib qw(/usr/local/mpop/lib/i386-linux-thread-multi/ /usr/local/mpop/lib);
use DBI;
use mPOP;
use mPOP::Profile;
use mPOP::Domain (preload=>1);

if (not defined $ARGV[0])
{
    print "need filename as cmd argument\n";
    exit 0;
}

my $pmPOP = mPOP::Get();
my $sleep_sec = 0.01;   # 100 millisec

my @users;

read_users($ARGV[0], \@users);
process(\@users);

sub read_users
{
    my $file = shift;
    my $data = shift;

    open my $fh,"<$file" or die "cant open file: $file";
    while (<$fh>)
    {
        if (length ($_))
        {
            $_ =~ s/^\s+//;
            $_ =~ s/\s+$//;
            push (@{$data}, $_);
        }
    }
    close $fh;
}

sub process
{
    my $list = shift;

    for my $userid (@{$list})
    {
        eval
        {
            my $pUser = mPOP::User->New(mPOP::Get());
            $pUser->LookupByID( $userid );

            my $email = $pUser->{Username} . '@' . $pUser->{_pDomain}->{Domain};

            my $pProfile = mPOP::Profile->New($pmPOP);
            $pProfile->Open(undef, undef, $userid, 1);
            if ($pProfile->IsOpen())
            {
                my $val = $pProfile->GetField('AccountType');
                $pProfile->Close();
                print "id: $userid, email: $email, accout: $val\n";
            }
            $pmPOP->Free();
        };

        select(undef, undef, undef, $sleep_sec);
    }
}
