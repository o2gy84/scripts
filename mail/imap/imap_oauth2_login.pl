#!/usr/bin/env perl

use strict;
use AnyEvent::Handle;
use AnyEvent::Socket;
use EV;
use MIME::Base64 'encode_base64';

sub b64($) {
    my $enc = encode_base64($_[0]);
    $enc =~ s{\r?\n}{}sg;
    return $enc;
}

my $user = 'imap_test_13@yahoo.com';
my $token = 'Ienkvyrx5z0YM0xT.NR5lAidWOFc4szXzeaekYaZIkxjVAn46q6Y4.Crq9BTfQiLwJi1099lnbwbtHuHbu_5esrN838uLzw._J0qvkB3UfBDCpSwXIavyMtP3.EFIK4qeA8YUjnezFuX8WpUW5IqC.hWpteWSK_m3k8WqnUqUGj3duinKRzaPGDJjM7LSeOUFKUlenH6ix1AFXhC._zlMbrN_qFifyrW2PexEkORNxVR687SW3dU3xngv.tN9oFx95i3dPqZCK8Vi7OWMpVkWNVr8uWwEmNs_HHOHZQS2ZAgGq.3GzfAgDTfDjX6eTtHcjcXfA97TLynr9m.MRe6yvvXDaA2U_7BzigBJQkfJsxVCj._TLVHF9e4JFHSKXMExBxpSgnFYzvpaYhk5dDUFSCFm_FxtEZy3TIsPsdo15IEa0FiBFwqRrfqswmTDZpL4N2aDqjvW6IAhDOpqXro0q4m2GTzljD2sKiy1rWaAT79KORCJdG6d0kmQ3vaEgmDYvC62GRwAu0vcTl0DPtl3nzl8Il03MmJYTLfjC8w6_4jLNU.DxUlTkmMY6vMBrqJqdNPHXxg7eojEUi.Ei7ZagPuBstJq7Zn2GDzLNJZCxRtRxmJtj0MrTHrtQmFT_Ugv6r6b7qLmzUCVh_bW_pkicG6tljzv1epeycr2Vl1UgarFs2OrSOwsINGbbVgCt1mI.elO9OySiGj7J3FYMkPdKE3dIsE4nvO_l2DtqWGrRDGb7zsUE.w0_PUCklXnAj.kuwv7MvOX_aS8s3yHxxtcuA26Bvm8r0ISBxDqM3j1Rx6XodfbTHq9lrVz1PWdPr834Gwn85Kucrb9AX5heBUXIpEKqVaBYueA0Yk9aPJSf2Np0xLHZUnizEQaSmXZe4Gu6Wp.9TFvQ';
my $server = 'imap.mail.yahoo.com';


#my $token = 'ya29.1.AADtN_VMLof3_5ZaeFL_gAGFMJrOE5Byn9YvMXeqNRiCtTvDC2roTGGkGRXzrh_u';
#my $user = 'timjaic@gmail.com';
#my $server = 'imap.gmail.com';

tcp_connect $server,993, sub {
    my $fh = shift or return;
    my $h = AnyEvent::Handle->new(
        fh => $fh,
    );
    $h->starttls('connect');
    my $sent = 0;
    $h->on_read(sub {
        warn $h->{rbuf};
        $h->{rbuf} = '';
        unless ($sent++) {
            my $X = "\x01";
            my $buf = "A01 AUTHENTICATE XOAUTH2 ".b64(
                "user=$user${X}auth=Bearer $token${X}${X}"
            )."\r\n";

            warn "BUF: $buf";
            
            $h->push_write($buf);
        }
    });
};

EV::loop;

