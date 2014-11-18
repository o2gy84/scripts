#!/usr/bin/perl

use strict;
use lib qw(/usr/local/mpop/lib /usr/local/mpop/lib/x86_64-linux-thread-multi/ /usr/local/mpop/lib/i386-linux-thread-multi/);
use DBI;
use mPOP;
use mPOP::Domain (preload=>1);
use MR::IProto::XS;
use MR::Mescalito::XS;
use Data::Dumper;

my $pmPOP = mPOP::Get();

my $limit = 10000;
my $sleep_sec = 0.1;   # 100 millisec
my $select_timeout = 100; # ms, select from mescalito

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

if(defined $ARGV[0] && $ARGV[0] > 0)
{
    my $q = $dbh->query("select rpop.imap.ID, rpop.imap.UserId, rpop.imap.UserEmail from rpop.imap where rpop.imap.ID = $ARGV[0] and rpop.imap.flags&512");
    my @a = $q->fetchrow();
    if(scalar(@a) == 0)
    {
        printf "not found\n";
        exit 1;
    }
    my $stpath_arr = mPOP::Capron::GetStPath($a[2], no_stpath_autofix=>1);
    my $full_stpath = $stpath_arr->[2];
    my @tmp = split(':', $full_stpath);
    my $ip = $tmp[0];
    my ($username, $domain) = split(/\@/, $a[2], 2);
    $domain = 'external' if (not mPOP::Domain::is_our_domain($domain));
    my $stpath = '/var/mail/vdomains/' . $domain . '/' . $tmp[1];
    print "email: " . $a[2] . ", stpath: " . $stpath . ", ip: $ip\n";
    my $res = process_user($a[1], $ip, $stpath, 500000);
    print Dumper $res;
    exit 1;
}

my $count = 0;
my $errors = 0;
while( ($offset - $limit) < $max_id)
{
    my $threshold = $offset + $limit;
    my $q = $dbh->query("select rpop.imap.ID, rpop.imap.UserId, rpop.imap.UserEmail from rpop.imap where rpop.imap.ID >= $offset AND rpop.imap.ID < $threshold and rpop.imap.flags&512");

    while(my @a = $q->fetchrow())
    {
        $count = $count + 1;
        my $userid = $a[1];
        my $usermail = $a[2];
        my $res;

        eval
        {
            my $stpath_arr = mPOP::Capron::GetStPath($usermail, no_stpath_autofix=>1);
            my $full_stpath = $stpath_arr->[2];
            my @tmp = split(':', $full_stpath);
            my $ip = $tmp[0];

            my ($username, $domain) = split(/\@/, $usermail, 2);
            $domain = 'external' if (not mPOP::Domain::is_our_domain($domain));
            my $stpath = '/var/mail/vdomains/' . $domain . '/' . $tmp[1];

            $res = process_user($userid, $ip, $stpath, 500000);
            $pmPOP->Free();
        };
        if($@)
        {
            print "$usermail, uid: $userid, error: $@";
            $errors ++;
        }
        else
        {
            my $capron_err = $res->{-1} || 0;
            my $inserts = $res->{1} || 0;
            my $add_weights = $res->{0} || 0;
            my $update_names = $res->{2} || 0;
            print "$usermail, uid: $userid, error: success [msgs: $res->{msgs}, capron: $capron_err, insert: $inserts, add_weight: $add_weights, update_name: $update_names]\n";
        }
    }

    print "===============================\n";
    print "progress: $offset from $max_id\n";
    select(undef, undef, undef, $sleep_sec);
    $offset = $offset + $limit;
}

print "users count: $count\n";
print "errors: $errors\n";

sub process_user($$$$)
{
    my ($uid, $ip, $path, $fld_id) = @_;
    my %ret = ();

    my $req = MR::Mescalito::XS::pack_request({
        select => {
            path => $path,
            request => [{
                index => XINDEX_INDEX_MSG_FLD_GROUP(),
                message => {
                    field => [qw(to cc uidl)],
                    where => {
                        fld_id => $fld_id,
                    }
                },
            }]
        }
    });

    my $iproto = MR::IProto::XS->new(masters => ["$ip:1665"]);
    my $iproto_resp = $iproto->do({
        request => $req,
        timeout => $select_timeout,
        code => MESCALITO_MSG_SELECT(),
    }) or die "iproto failed";

    die "iproto failed: $iproto_resp->{'error'}" if(defined $iproto_resp->{'error'} and $iproto_resp->{'error'} ne 'ok');

    my $resp = MR::Mescalito::XS::unpack_response({
        msg => MESCALITO_MSG_SELECT(),
        data => $iproto_resp->{data}
    });

    die "Bad response from mescalito: `$resp->{ret}'"
        unless $resp->{ret} == MESCALITO_RET_OK();

    $ret{msgs} = scalar(@{ $resp->{response}[0]});

    for my $msg (@{ $resp->{response}[0] })
    {
        my $address_string = $msg->{'to'};
        if(length($msg->{'cc'}) > 0)
        {
            if(length($address_string) > 0 )
            {
                $address_string = $address_string . ',' . $msg->{'cc'};
            }
            else
            {
                $address_string = $msg->{'cc'};
            }
        }
        
        my $ts = substr($msg->{'uidl'}, 0, 10);
        my @pair = Mailbox::SplitAddressList($address_string);
        foreach my $elem (@pair)
        {
            my @pp = rfc822::SplitAddress($elem, save_quotes => 1);   # pp[0] - name, pp[1] - email
            $pp[0] = '"'.$pp[0].'"' if (substr($pp[0], 0, 1) ne '"' && index($pp[0], ',') >= 0);

            my $email = $pp[1] || '';
            $email = Encode::decode('UTF-8', $email);
            $email = mPOP::Utils::DecodePunycodeEmail($email);

            my $name = $pp[0] || '';
            $name = Encode::decode('UTF-8', $name);
 
            my $status = send_to_ab($uid, $email, $name, $ts);
            #status:
            # -1 - ошибка
            #  0 - у контакта увеличен вес
            #  1 - добавлен новый контатк
            #  2 - у контакта изменено имя

            $ret{$status} ++;
        }
    }
    return \%ret;
}

sub send_to_ab($$$$)
{
    my ($uid, $email, $name, $ts) = @_;

    my $capron = mPOP::Capron::GetCapron();
    if (!$capron)
    {
        printf "Error get capron\n";
        return -1;
    }

use bytes;  # fuuuuck! need interpret binary strings as bytes, not as utf symbols

    my $res = $capron->Chat(
            msg => 25,
            body => pack('LL(L/a*)(L/a*)L', 4, $uid, $email, $name, $ts)
            );

    if (length($res) != 12)
    {
        printf "Capron AB fetch error\n";
        return -1;
    }

    my ($ret_msg, $err_code, $status) = unpack('LLL', $res);

    if($ret_msg != 4)
    {
        printf "unexpected reply from capron\n";
        return -1;
    }
    if($err_code != 0)
    {
        printf "capron returns error: $err_code\n";
        return -1;
    }

    return $status;
}
