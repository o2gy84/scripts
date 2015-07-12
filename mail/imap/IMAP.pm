package IMAP;
use strict;
use Encode;
use IO::File;
use IO::Socket;
use MIME::Base64;

use vars qw[$VERSION];

sub new {
    my ( $class, $server, %opts) = @_;

    my $timeout = 60;
    my $self = bless {
        count => ($opts{startid} ? $opts{startid} : -1),
    } => $class;
    my ($srv, $prt) = split(/:/, $server, 2);
    $prt ||= ($opts{port} ? $opts{port} : ($opts{ssl} ? 993 : 143));

    $self->{server} = $srv;
    $self->{port} = $prt;
    $self->{timeout} = ($opts{timeout} ? $opts{timeout} : $self->_timeout);
    $self->{use_v6} = ($opts{use_v6} ? 1 : 0);
    $self->{bindaddr} = $opts{bindaddr};
    $self->{use_select_cache} = $opts{use_select_cache};
    $self->{select_cache_ttl} = $opts{select_cache_ttl};
    $self->{debug} = $opts{debug};
    $self->{ssl} = $opts{ssl};
    $self->{starttls} = $opts{starttls};

    # Pop the port off the address string if it's not an IPv6 IP address
    if(!$self->{use_v6} && $self->{server} =~ /^[A-Fa-f0-9]{4}:[A-Fa-f0-9]{4}:/ && $self->{server} =~ s/:(\d+)$//g){
        $self->{port} = $1;
    }
#connect
    unless($self->{sock} = $self->_connect){
	$@ =~ s/IO::Socket::INET6?: //g;
#	$errstr = "connection failed $@";
	return;
    }
#read banner
    unless ($self->{greeting} = read_line($self->sock,$timeout)) {
        $@ = "banner read timeout";
        return;
    }
    if ($self->{starttls}) {
        return $self->starttls;
    }
    return $self;
}

sub _connect {
    my ($self) = @_;
    my $sock;
    if($self->{use_v6}){
	require 'IO::Socket::INET6';
	import IO::Socket::INET6;
    }
    if($self->{ssl}) {
        eval "require IO::Socket::SSL";
	require IO::Socket::SSL;
        if ($@) {
            $self->_seterrstr("Unable to load 'IO::Socket::SSL': $@");
            return undef;
        }
        $sock = IO::Socket::SSL->new(
	    PeerAddr => $self->{server},
	    PeerPort => $self->{port},
	    Timeout  => $self->{timeout},
SSL_version => 'TLSv1',
	    Proto    => 'tcp',
	    ($self->{bindaddr} ? { LocalAddr => $self->{bindaddr} } : ())
        );
    } else {
        $sock = $self->_sock_from->new(
	    PeerAddr => $self->{server},
	    PeerPort => $self->{port},
	    Timeout  => $self->{timeout},
	    Proto    => 'tcp',
	    ($self->{bindaddr} ? { LocalAddr => $self->{bindaddr} } : ())
        );
    }
    return $sock;
}

sub starttls {
    my ($self) = @_;

    my $resp = $self->_process_cmd (cmd => ['STARTTLS']);
    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        if ($resp->{tagged}->{message} ne 'Starting TLS.') {
            $self->_seterrstr("STARTTLS got unexpected message '$resp->{tagged}->{message}'");
            return 0;
        }
    } else {
        $self->_seterrstr("STARTTLS error: '$resp->{tagged}->{raw}'");
        return 0;
    }

    my $ioclass  = eval "require IO::Socket::SSL";
    if ($@) {
        $self->_seterrstr("Unable to load 'IO::Socket::SSL': $@");
        return undef;
    }

    my $sock     = $self->{sock};
    my $blocking = $sock->blocking;

    # BUG: force blocking for now
    $sock->blocking(1);

    unless ( IO::Socket::SSL->start_SSL( $sock ) ) {
        $self->_seterrstr( "Unable to start TLS: " . IO::Socket::SSL->errstr );
        return undef;
    }

    $sock->blocking($blocking);

    return $self;
}

sub is_ssl {
    $_[0]->{ssl} || $_[0]->{starttls};
}

*read_all = \*_read_wait;

sub read_line {
    return _read_wait(@_,1)
}

sub _read_wait {
    my ($sock, $timeout,$line) = @_;
    my $res = '';
    my $s = IO::Select->new();
    $s->add($sock);
    $timeout = 0.25 unless (defined $timeout);
    while ($s->can_read($timeout)) {
        my $ret = sysread($sock,my $buf,10240);
        if (not defined $ret ) {
            return wantarray ? (undef, "$!") : undef ;
        } elsif ($ret == 0) {
            return wantarray ? (undef, "unexpected eof") : undef;
        } else {
            $res .= $buf;
            return $res if ($line and $buf =~ /\n/);
        }
    }
    return $res;
}

sub sock        { $_[0]->{sock}  }
sub _count       { $_[0]->{count} }
sub response     { $_[0]->{response}  }
sub _timeout     { 90             }
sub _retry       { 1              }
sub _retry_delay { 5              }
sub _sock_from   { $_[0]->{use_v6} ? 'IO::Socket::INET6' : 'IO::Socket::INET' }
sub nvl { defined $_[0] ? $_[0] : '(undef)' }

sub login {
 my ( $self, $user, $pass ) = @_;
#todo
# $pass = _escape($pass);
    my $ret = 1;
    $self->{response} = {};
    my $resp = $self->_process_cmd (
	cmd     => [LOGIN => qq[$user "$pass"]],
    );
    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        my $msg = 'Authentication successful';
        if ($resp->{tagged}->{message} ne $msg) {
            $ret++;
            $self->_seterrstr("LOGIN got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->_seterrstr("LOGIN error: '$resp->{tagged}->{raw}'");
        return 0;
    }
    return $ret;
}

=pod                                                                                                                                                                                          
                                                                                                                                                                                              
=item fetch

    my $num_messages = $imap->select($folder);

return array of hashes so $imap->fetch('1:2','(UID RFC822.SIZE)') return
[
          {
            'UID' => '77',
            'id' => 1,
            'RFC822.SIZE' => '967'
          },
          {
            'UID' => '78',
            'id' => '2',
            'RFC822.SIZE' => '2349'
          }
        ];
];
it also add special field id 
=cut

sub fetch {
    return _fetch_cmd(@_);
}

sub uid_fetch {
    return _fetch_cmd(@_,{cmd=>'UID FETCH'});
}

sub _fetch_cmd {
    my ( $self, $sel, $args, $params ) = @_;
    my $cmd = (exists $params->{cmd}) ? $params->{cmd} : 'FETCH';
    $self->{response} = [];
    my $ret = 1;
    my $resp = $self->_process_cmd(
	cmd     => [$cmd => "$sel $args"]
    );
    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        if ($resp->{tagged}->{message} ne 'FETCH done') {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->_seterrstr("$cmd error: '$resp->{tagged}->{raw}'");
        return 0;
    }

    (my $orderargs = $args) =~ s/(^\(|\)$)//g; #remove first and last ( )
    my @orderargs = sort {
0
#wo sort
#                             my ($first,$second) = (0,0);
#                             $first = 1 if ($a =~ /^(body\[.*|rfc822(?!\.s))$/i);
#                             $second = 1 if ($b =~ /^(body\[.*|rfc822(?!\.s))$/i);
#                             $first <=> $second;
                         } map { s/^(body)\.peek/$1/i;
                                    (uc $_ eq 'ALL') ? ('FLAGS', 'INTERNALDATE', 'RFC822.SIZE', 'ENVELOPE') :
                                    (uc $_ eq 'FAST') ? ('FLAGS', 'INTERNALDATE', 'RFC822.SIZE') :
                                    (uc $_ eq 'FULL') ? ('FLAGS', 'INTERNALDATE', 'RFC822.SIZE', 'ENVELOPE','BODY') :
                                    $_
                               } split (/\s+(?![^\[]*])/, $orderargs); # fix me. it work but it not right
    unshift @orderargs, 'UID' if ($cmd =~ /uid fetch/i and uc $orderargs[0] ne 'UID');

    my @tempresp;
    for (my $i = 0; $i <= $#{$resp->{untagged}};$i++) {
        my $untagstr = $resp->{untagged}[$i];
        if (ref $untagstr eq 'ARRAY') {
            if ((scalar @$untagstr) % 2 != 0) {
                $self->_seterrstr("wrong parsing untagged return");
                $ret++;
            }
            if ($untagstr->[-1] !~ /[\n\r\) ]+/) {
                $self->_seterrstr("body should be last");
                $ret++;
            }
#            my $str = shift( @$untagstr) . pop( @$untagstr);
            
        } else {
           $untagstr = [ $untagstr ];
        }
#        unless ($untagstr->[0] =~ s/^ (\d+) FETCH (\(?)/ /) {
        unless ($untagstr->[0] =~ s/^ (\d+) FETCH \(/ /) {
            if (my $stat_update = check_status_update($self,$untagstr->[0])) {
                # status update without fetch flags
                push @{$self->{response}}, $stat_update;
                next;
            } else {
                $self->_seterrstr("$cmd error: cant parse untagged string '$untagstr->[0]'");
                return 0;
            }
        }
        my %hash = (id => $1);
        if (@tempresp) {
            if ($1 <= $tempresp[-1]->[0]->[1]) {
                $self->_seterrstr("id should be in ascending order got $1 after $tempresp[-1]->[0]->[1]");
                $ret++;
            }
        }
#to do remove ' '
        if (not $untagstr->[-1] =~ s/\)$//) {
            $self->_seterrstr("$cmd error: cant remove trailing ) '$untagstr->[-1]'");
            return 0;
        }

        push my @resp, get_tokens($untagstr->[0]);

        if ($#{$untagstr} > 0) {
            if ($#{$untagstr} > 1) {
                for (my $i=1;$i<$#$untagstr;$i+=3) {
                    push @resp, [$untagstr->[$i],${$untagstr->[$i+1]}];
                    push @resp, get_tokens($untagstr->[$i+2]);
                }
            }
        }

#check number of returned param
        if ($#orderargs != $#resp) {
            if (my $stat_update = check_status_update($self,$untagstr->[0])) {
                #fetch flags
                push @{$self->{response}}, $stat_update;
                next;
            }
            $self->_seterrstr("expected ".scalar @orderargs." values, but got " . scalar @resp );
            $ret++;
        }
        for (my $i = 0; $i <= $#resp; $i++) {
            unless ($resp[$i]->[0] =~ /\Q$orderargs[$i]\E/i) {
                $self->_seterrstr("wrong response order got '$resp[$i]->[0]' on $i, expected '$orderargs[$i]'");
                $ret++;
            }
            if (exists $hash{$resp[$i]->[0]}) {
                 if ($hash{$resp[$i]->[0]} ne $resp[$i]->[1]) {
                     $self->_seterrstr("FETCH return two different responses in one '$hash{$resp[$i]->[0]}' and '$resp[$i]->[1]'");
                     return 0;
                 }
            } else {
                 $hash{$resp[$i]->[0]} = $resp[$i]->[1];
            }
        }
        push @{$self->{response}}, \%hash;
    }
    return $ret;
}

sub check_status_update {
    my ($self,$str) = @_;
    if ($str =~ /^ (\d+) EXISTS$/) {
        $self->{mbox}->{'exists'} = $1;
        return {'exists' => $1};
    } elsif ($str =~ /^ (\d+) RECENT$/) {
        $self->{mbox}->{recent} = $1;
        return {'recent' => $1};
    } elsif ($str =~ /^ (\d+) EXPUNGE$/) {
        $self->{mbox}->{'exists'}--;
        return {'expunge' => $1};
    } elsif ($str =~ /^ (\d+) FETCH \(FLAGS (\(.*\))\)$/) {
#        return {'id' => $1,'flags'=>[split(' ',$2)]};
        return {'id' => $1,'flags'=>$2};
    }
    return 0;
}

sub get_tokens {
    my $str = shift;
    my @resp = ();
    return unless $str;
    return @resp if ($str eq ' ');
    our $paren_rx;
    local $paren_rx;
    $paren_rx = qr{(?:\((?s:[^\\()]|\\.|(??{$paren_rx}))*\)|[^()\"\' ]+|\"([^"]|\\")*\")};
    while ($str =~ /\G (\S+) ((??{$paren_rx}))/gc) {
        push @resp, [$1, $2];
    }
    my ($rest) = ($str =~ /\G(.*)/);
    if ($rest) {
        #add broke token
        push @resp, $rest;
    }
    return @resp;
}

sub copy {
    return _copy_cmd(@_);
}

sub uid_copy {
    return _copy_cmd(@_,{cmd=>'UID COPY'});
}

sub _copy_cmd {
    my ( $self, $sel, $folder,$params) = @_;
    $self->{response} = {};
    my $cmd = (exists $params->{cmd}) ? $params->{cmd} : 'COPY';
    _escape( $folder );
    my $ret = 1;
    my $resp = $self->_process_cmd(
	cmd     => [$cmd => "$sel $folder"]
    );

    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
#[COPYUID 38505 304,319:320 3956:3958]
        my $uidplus_ext = qr(\[COPYUID (\d+) ([\d,:]+) ([\d,:]+)\] ); # if ($imap->{capability} =~ /UIDPLUS/)
        if ($resp->{tagged}->{message} =~ /^${uidplus_ext}COPY completed$/) {
            $self->{response}->{uidvalidity} = $1;
            my @from = expand_uidlist($2);
            my @to = expand_uidlist($3);
            if (scalar @from != scalar @to) {
                $self->_seterrstr("$cmd error: '$resp->{tagged}->{raw}'");
                return 0;
            }
            for (my $i = 0; $i < scalar @from; $i++) {
                if (exists $self->{response}->{$from[$i]}) {
                    if (ref $self->{response}->{$from[$i]} ne 'ARRAY') {
                        $self->{response}->{$from[$i]} = [$self->{response}->{$from[$i]},$to[$i]];
                    } else {
                        push @{$self->{response}->{$from[$i]}}, $to[$i];
                    }
                } else {
                    $self->{response}->{$from[$i]} = $to[$i];
                }
            }
        } else {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->_seterrstr("$cmd error: '$resp->{tagged}->{raw}'");
        return 0;
    }
    return $ret;
}

sub expand_uidlist {
    my ($str) = @_;
    my @ret;
    foreach (split ',', $str) {
        if (/^(\d+):(\d+)$/) {
            if ($1 < $2) {
                push @ret, $1 .. $2;
            } else {
                push @ret, $_;
            }
        } else {
                push @ret, $_;
        }
    }
    return @ret;
}

sub logout {
    my ($self) = @_;
    my $ret = _one_untagg_cmd($self,undef,{cmd => 'LOGOUT'});
    if (defined read_all($self->{sock})) {
        $ret++;
        $self->_seterrstr("LOGOUT remote connection not close");
    }
    return $ret;
# to do check for close
}

sub id {
    return _one_untagg_cmd(@_,{cmd=>'ID'});
}

sub _one_untagg_cmd {
    my ( $self, $id_string,$params) = @_;
    $self->{response} = [];
    my $cmd = (exists $params->{cmd}) ? $params->{cmd} : 'LOGOUT';
    my $ret = 1;
    my $resp = $self->_process_cmd(
	cmd     => [$cmd => $id_string]
    );

    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        my $msg .= $cmd . ' completed';
        if ($resp->{tagged}->{message} ne $msg) {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->_seterrstr("$cmd error: '".nvl($resp->{tagged}->{raw})."'");
        return 0;
    }
    unless ($#{$resp->{untagged}} == 0) {
        if ($#{$resp->{untagged}} < 0 ) {
            $self->_seterrstr("$cmd no untagged response'");
            return 0;
        } else {
            $ret++;
            $self->_seterrstr("$cmd got unexpected lines:");
            $self->_seterrstr("    '$_'") foreach (@{$resp->{untagged}});
        }
    }
    if ($cmd =~ /^id$/i) {
        unless ($resp->{untagged}->[0] =~ /^ \U$cmd\E (.+)$/) {
            $self->_seterrstr("$cmd cant parse response '$resp->{untagged}->[0]'");
            return 0;
        }
        $self->{response} = $1;
    } else {
        $self->{response} = $resp->{untagged}->[0];
    }

    return $ret;
}

sub append {
    my ( $self, $mail, $folder, $flags, $date, $params) = @_;
    $self->{response} = {};
    my $cmd = (exists $params->{cmd}) ? $params->{cmd} : 'APPEND';
    _escape( $folder );
    my $cmdargs = $folder;
    my $ret = 1;
    $cmdargs .= " $flags" if $flags;
    $cmdargs .= " \"$date\"" if $date;
    $cmdargs .= " {".(length ($mail))."}";
    my $resp = $self->_process_cmd(
	cmd     => [$cmd => $cmdargs],
        cb => sub { my $sock = shift; print $sock $mail."\r\n"; }
    );

    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        my $uidplus_ext = qr(\[APPENDUID (\d+) (\d+)\] ); # if ($imap->{capability} =~ /UIDPLUS/)
        if ($resp->{tagged}->{message} =~ /^${uidplus_ext}Append done$/) {
            $self->{response}->{uid} = $2;
            $self->{response}->{uidvalidity} = $1;
        } else {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->{response}->{message} = $resp->{tagged}->{message} if $resp->{tagged}->{message};
        $self->_seterrstr("$cmd error: '$resp->{tagged}->{raw}'");
        return 0;
    }
    return $ret;
}

sub uid_store {
    my ($self,$sel,$mod,$flags) = @_;
    return noop($self,{cmd=>'UID STORE',args=>"$sel $mod $flags"});
}

sub store {
    my ($self,$sel,$flags) = @_;
    return noop($self,{cmd=>'STORE',args=>"$sel FLAGS $flags"});
}

sub add_flags {
    my ($self,$sel,$flags) = @_;
    return noop($self,{cmd=>'STORE',args=>"$sel +FLAGS $flags"});
}

sub del_flags {
    my ($self,$sel,$flags) = @_;
    return noop($self,{cmd=>'STORE',args=>"$sel -FLAGS $flags"});
}


sub expunge {
    return noop(@_,{cmd=>'EXPUNGE'});
}

sub check {
    return noop(@_,{cmd=>'CHECK'});
}

sub noop {
    my ( $self, $params) = @_;
    $self->{response} = {};
    my $cmd = (exists $params->{cmd}) ? $params->{cmd} : 'NOOP';
    my $args = (exists $params->{args}) ? $params->{args} : undef;
    my $ret = 1;
    my $resp = $self->_process_cmd(
	cmd     => [$cmd => $args],
    );
    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        (my $msg = (uc $cmd)) =~ s/(\S+).*/$1/;
        $msg .= ($cmd =~ /store/i) ? ' done' : ' completed';
        if ($resp->{tagged}->{message} ne $msg) {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->_seterrstr("$cmd error: '$resp->{tagged}->{raw}'");
        return 0;
    }
    for (my $i = 0; $i <= $#{$resp->{untagged}};$i++) {
        my $untagstr = $resp->{untagged}[$i];
        my $stat_update = check_status_update($self,$untagstr);
        if ($stat_update) {
            if ($stat_update->{'exists'}) {
                if (exists $self->{response}->{'exists'}) {
                    $ret++;
                    $self->_seterrstr("$cmd got second EXISTS");
                }
                $self->{response}->{'exists'} = $stat_update->{'exists'};
            } elsif ($stat_update->{'recent'}) {
                if (exists $self->{response}->{'recent'}) {
                    $ret++;
                    $self->_seterrstr("$cmd got second RECENT");
                    }
            $self->{response}->{'recent'} = $stat_update->{'recent'};
            } elsif ($stat_update->{'expunge'}) {
                if (exists $self->{response}->{'exists'}) {
                    $ret++;
                    $self->_seterrstr("$cmd expunge after EXISTS");
                }
                push @{$self->{response}->{'expunge'}}, $stat_update->{'expunge'};
            } elsif ($stat_update->{'flags'}) {
                if (exists $self->{response}->{'flags'}->{$stat_update->{'id'}}) {
                    $ret++;
                    $self->_seterrstr("$cmd return flags for message $stat_update->{'id'} twice");
                }
                $self->{response}->{'flags'}->{$stat_update->{'id'}} = $stat_update->{'flags'};
            } else {
                $self->_seterrstr("$cmd error: unknow string '$untagstr'");
                return 0;
            }
            next;
        } else {
            $self->_seterrstr("$cmd error: cant parse untagged string '$untagstr'");
            return 0;
        }
    }

    return $ret;
}

sub uid_search {
    my ( $self,$args,$params) = @_;
    $params->{cmd} = 'UID SEARCH' unless exists $params->{cmd};
    return search($self,$args,$params);
}

sub search {
    my ( $self,$args,$params) = @_;
    my $cmd = (exists $params->{cmd}) ? $params->{cmd} : 'SEARCH';
    my $ret = 1;
    $self->{response} = [];
    my $resp = $self->_process_cmd(
	cmd     => [$cmd => "$args"]
    );

    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        if ($resp->{tagged}->{message} ne 'SEARCH completed') {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->_seterrstr("$cmd error: '$resp->{tagged}->{raw}'");
        return 0;
    }
    my $str = $resp->{untagged}->[0];
    unless ( $str =~ s/^ SEARCH// or $str =~ s/\r$//) {
        $self->_seterrstr("$cmd error: cant parse untagged string '".nvl($resp->{untagged}->[0])."'");
        return 0;
    }
    if ($str ne "") {
        while ($str =~ /\G (\d+)/gc) {
            push @{$self->{response}}, $1;
        }
        unless ( pos($str) eq length $str) {
                $self->_seterrstr("$cmd error: cant parse untagged part '".substr($str,pos()).
                                  "' string of'".nvl($resp->{untagged}->[0])."'");
                return 0;
        }
    }
    return $ret;
}


sub status {
    my ( $self, $folder,$args,$params) = @_;
    my $cmd = (exists $params->{cmd}) ? $params->{cmd} : 'STATUS';
    _escape( $folder );
    my $ret = 1;
    my $resp = $self->_process_cmd(
	cmd     => [$cmd => "$folder $args"]
    );

    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        if ($resp->{tagged}->{message} ne 'STATUS completed') {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->_seterrstr("$cmd error: '$resp->{tagged}->{raw}'");
        return 0;
    }
#check amount
    unless (scalar @{$resp->{untagged}} == 1) {
        $ret++;
        $self->_seterrstr("$cmd should return only one string, but return " . scalar @{$resp->{untagged}});
    }
#parse
    my @orderargs = split (/\s+/, ($args=~/^\((.*)\)$/ ? $1 : $args));
    $folder = ($folder =~ /^"(.*)"$/ ? $1: $folder);
    unless ( $resp->{untagged}->[0] and $resp->{untagged}->[0] =~ /^ STATUS \U$folder\E \((.+)\)/) {
            $self->_seterrstr("$cmd error: cant parse untagged string '".nvl($resp->{untagged}->[0])."'");
            return 0;
    }
    my $i=0;
    foreach (get_tokens(" $1")) {
        unless ($_->[0] eq $orderargs[$i++]) {
            $ret++;
            $self->_seterrstr("$cmd wrong order: expected '". ($orderargs[$i-1]). "'.got $_->[0]");
        }
        $self->{response}->{$_->[0]} = $_->[1];
    }
    unless ($i == scalar @orderargs) {
        $ret++;
        $self->_seterrstr("$cmd wrong amount of args: got $i expected ".(scalar @orderargs));
    }

    return $ret;
}

sub select {
    return _select_cmd(@_);
}

sub examine {
    return _select_cmd(@_, {cmd=>'EXAMINE'} );
}

sub _select_cmd {
    my ( $self, $mbox, $params ) = @_;
    my $cmd = (exists $params->{cmd}) ? $params->{cmd} : 'SELECT';
    $mbox = 'INBOX' unless $mbox;
#    my $untag = {};
    my $ret = 1;
    my $t_mbox = $mbox;

    my $resp = $self->_process_cmd(cmd     => [$cmd => _escape($t_mbox)]);

    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        my $msg = (uc $cmd eq 'EXAMINE') ? '[READ-ONLY] EXAMINE completed' :
                               '[READ-WRITE] SELECT completed' ;
        if ($resp->{tagged}->{message} ne $msg) {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->_seterrstr("$cmd error: '". nvl($resp->{tagged}->{raw})."'");
        return 0;
    }

    $self->{mbox} = {};
    $self->{mbox}->{name} = $mbox;
    if (scalar @{$resp->{untagged}} != 7 ) {
        $ret++;
        $self->_seterrstr("expected 7 elements but '" .(scalar {$resp->{untagged}} )."' fetched" );
    }
    for (my $i = 0; $i <= $#{$resp->{untagged}};$i++) {
        my $untagstr = $resp->{untagged}[$i];
        if ($untagstr =~ /^ FLAGS \((.*)\)$/) {
            $self->{mbox}->{flags} = [split(/\s+/, $1)];
            if ($i != 0) {
                $ret++;
                $self->_seterrstr("FLAGS on $i position");
            }
        } elsif ($untagstr =~ /^ (\d+) EXISTS$/) {
            $self->{mbox}->{'exists'} = $1;
            if ($i != 1) {
                $ret++;
                $self->_seterrstr("EXISTS on $i position");
            }
        } elsif ($untagstr =~ /^ (\d+) RECENT$/) {
            $self->{mbox}->{recent} = $1;
            if ($i != 2) {
                $ret++;
                $self->_seterrstr("RECENT on $i position");
            }
        } elsif ($untagstr =~ /^ OK \[UNSEEN (\d+)\]$/) {
            $self->{mbox}->{unseen} = $1;
            if ($i != 3) {
                $ret++;
                $self->_seterrstr("UNSEEN on $i position");
            }
        } elsif ($untagstr =~ /^ OK \[UIDVALIDITY (\d+)\]$/) {
            $self->{mbox}->{uidvalidity} = $1;
            if ($i != 4) {
                $ret++;
                $self->_seterrstr("UIDVALIDITY on $i position");
            }
        } elsif ($untagstr =~ /^ OK \[PERMANENTFLAGS \((.*)\)\]$/) {
            $self->{mbox}->{permanentflags} = [split(/\s+/, $1)];
            if ($i != 5) {
                $ret++;
                $self->_seterrstr("PERMANENTFLAGS on $i position");
            }
        } elsif ($untagstr =~ /^ OK \[UIDNEXT (\d+)\]$/) {
            $self->{mbox}->{uidnext} = $1;
            if ($i != 6) {
                $ret++;
                $self->_seterrstr("UIDNEXT on $i position");
            }
        } else {
            $ret++;
            $self->_seterrstr("unknown resp $untagstr");
        }
    }
    return $ret;
}

sub list {
    return _list_cmd(@_);
}

sub xlist {
    return _list_cmd(@_, {cmd=>'XLIST'} );
}

sub lsub {
    return _list_cmd(@_, {cmd=>'LSUB'} );
}

sub _list_cmd {
    my ( $self, $ref, $mbox, $params ) = @_;
    $self->{response} = {};
    my $ret = 1;
    my $t_mbox = $mbox;
    my $t_ref = $ref;
    my $cmd = (exists $params->{cmd}) ? $params->{cmd} : 'LIST';
    my $resp = $self->_process_cmd(
	cmd     => [$cmd => _escape($t_ref) . " " . _escape($t_mbox)]
    );
    if ( $resp->{tagged}->{ok} and $resp->{tagged}->{ok} == 1) {
        my $msg = (uc $cmd) . ' done';
        if ($resp->{tagged}->{message} ne $msg) {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$resp->{tagged}->{message}'");
        }
    } else {
        $self->_seterrstr("$cmd error: '$resp->{tagged}->{raw}'");
        return 0;
    }
    for (my $i = 0; $i <= $#{$resp->{untagged}};$i++) {
        my $untagstr = $resp->{untagged}[$i];
        if (my ($flags,$sep,$name) = ($untagstr =~ /^ \U$cmd\E \((.*)\) \"(.)\" \"(.+)\"$/)) {
            $flags = [split (' ',$flags)];
            if (exists $self->{response}->{$name}) {
                $ret++;
                $self->_seterrstr("$cmd: folder '$name '$untagstr'");
            } else {
                $self->{response}->{$name} = {flags => $flags,separator => $sep};
            }
#            print "flags: $flags, sep: $sep, name: $name\n";
        } else {
            $ret++;
            $self->_seterrstr("$cmd got unexpected message '$untagstr'");
        }
    }
    return $ret;
}

my $re_asis =    qr/(?:[\x20-\x25\x27-\x7e])/; # printable US-ASCII except "&" represents itself
my $re_encoded = qr/(?:[^\x20-\x7e])/; # Everything else are represented by modified base64

sub utf7_encode {
    my ($str, $chk ) = @_;
    my $len = length($str);
    pos($str) = 0;
    my $bytes = '';
    while ( pos($str) < $len ) {
        if ( $str =~ /\G($re_asis+)/ogc ) {
            $bytes .= $1;
        } elsif ( $str =~ /\G&/ogc ) {
            $bytes .= "&-";
        } elsif ( $str =~ /\G($re_encoded+)/ogsc ) {
            my $s = $1;
            Encode::_utf8_on($s);
            my $base64 = encode_base64(encode("UTF-16BE",$s),'');
            $base64 =~ s/=+$//;
            $base64 =~ s/\//,/g;
            $bytes .= "&$base64-";
        } else {
            die "This should not happen! (pos=" . pos($str) . ")";
        }
    }
    $_[1] = '' if $chk;
    return $bytes;
}

sub utf7_decode {
    my ($bytes, $chk ) = @_;
    my $len = length($bytes);
    my $str = "";
    pos($bytes) = 0;
    while ( pos($bytes) < $len ) {
        if ( $bytes =~ /\G([^&]+)/ogc ) {
            $str .= $1;
        } elsif ( $bytes =~ /\G\&-/ogc ) {
            $str .= "&";
        } elsif ( $bytes =~ /\G\&([A-Za-z0-9+,]+)-?/ogsc ) {
            my $base64 = $1;
            $base64 =~ s/,/\//g;
            my $pad = length($base64) % 4;
            $base64 .= "=" x ( 4 - $pad ) if $pad;
            $base64 = decode("UTF-16BE", decode_base64($base64));
            Encode::_utf8_off($base64);
            $str .= $base64;
        } elsif ( $bytes =~ /\G\&/ogc ) {
            $^W and warn "Bad IMAP-UTF7 data escape";
            $str .= "&";
        } else {
            die "This should not happen " . pos($bytes);
        }
    }
    $_[1] = '' if $chk;
    return $str;
}

=pod


=item delete

  print "Gone!" if $imap->delete( $message_number );

This method deletes a message from the selected mailbox. On success it
returns true. False on failure and the errstr() error handler is set with the error message.

=cut

sub delete {
    my ( $self, $number ) = @_;
    
    $self->_process_cmd(
        cmd     => [STORE => qq[$number +FLAGS (\\Deleted)]],
        final   => sub { 1 },
        process => sub { },
    );
}


=item create_mailbox

  print "Created" if $imap->create_mailbox( "/Mail/lists/perl/advocacy" );

This method creates the mailbox named in the required argument. Returns true
on success, false on failure and the errstr() error handler is set with the error message.

=cut

sub create_mailbox {
    my ( $self, $box ) = @_;
    _escape( $box );
    return noop($self,{cmd=>'CREATE',args=>$box});
}

=pod

=item delete_mailbox

  print "Deleted" if $imap->delete_mailbox( "/Mail/lists/perl/advocacy" );

This method deletes the mailbox named in the required argument. Returns true
on success, false on failure and the errstr() error handler is set with the error message.

=cut

sub delete_mailbox {
    my ( $self, $box ) = @_;
    _escape( $box );
    return noop($self,{cmd=>'DELETE',args=>$box});
}

=pod

=item rename_mailbox

  print "Renamed" if $imap->rename_mailbox( $old => $new );

This method renames the mailbox in the first required argument to the
mailbox named in the second required argument. Returns true on success,
false on failure and the errstr() error handler is set with the error message.

=cut

sub rename_mailbox {
    my ( $self, $old_box, $new_box ) = @_;
    _escape( $old_box );
    _escape( $new_box );
    return noop($self,{cmd=>'RENAME',args=>"$old_box $new_box"});
}

=pod

=item folder_subscribe

  print "Subscribed" if $imap->folder_subscribe( "/Mail/lists/perl/advocacy" );

This method subscribes to the folder. Returns true on success, false on failure
and the errstr() error handler is set with the error message.

=cut

sub folder_subscribe {
 my ($self, $box) = @_;
 $self->select($box); # XXX does it matter if this fails?
 _escape($box);
 
 return $self->_process_cmd(
        cmd     => [SUBSCRIBE => $box],
        final   => sub { 1 },
        process => sub { },
 );
}

=pod

=item folder_unsubscribe

  print "Unsubscribed" if $imap->folder_unsubscribe( "/Mail/lists/perl/advocacy" );

This method unsubscribes to the folder. Returns true on success, false on failure
and the errstr() error handler is set with the error message.

=cut

sub folder_unsubscribe {
 my ($self, $box) = @_;
 $self->select($box);
 _escape($box);
 
 return $self->_process_cmd(
        cmd     => [UNSUBSCRIBE => $box],
        final   => sub { 1 },
        process => sub { },
 );
}

sub error {
    my $err = $_[0]->{_errstr};
    $_[0]->{_errstr} = '';
     return $err;
}

sub errstr {
    (my $err = $_[0]->{_errstr}) =~ s/\n/\\n/g;
    $err =~ s/\r/\\r/g;
    $_[0]->{_errstr} = '';
     return $err;
}

sub _nextid       { ++$_[0]->{count}   }

sub _escape {
    $_[0] =~ s/\\/\\\\/g;
    $_[0] =~ s/\"/\\\"/g;
    $_[0] = "\"$_[0]\"";
}

sub _unescape {
    $_[0] =~ s/^"//g;
    $_[0] =~ s/"$//g;
    $_[0] =~ s/\\\"/\"/g;
    $_[0] =~ s/\\\\/\\/g;
}

sub _send_cmd {
    my ( $self, @cmds ) = @_;
    my $sock = $self->sock;
    my $cmd = '';
    my @ids;
    foreach (@cmds) {
        my ($name, $value) = @$_;
        my $id   = $self->_nextid;
        $cmd .= "$id $name" . ($value ? " $value" : "") . "\r\n";
        push @ids, $id;
    }
    $self->_debug(caller, __LINE__, '_send_cmd', $cmd) if $self->{debug};

    { local $\; print $sock $cmd; }
    return @ids;
}

sub _read_multiline {
    my ($self, $count) = @_;

    my $res = '';
    my $buf;
    my $sock = $self->sock;
    my $read_so_far = 0;
    while ($count > 0) {
        my $read = $sock->read($buf, (($count < 10240) ? $count : 10240));
        $count -= $read;
        if (!$read) {
	    $self->_debug(caller, __LINE__, '_read_multiline', "exit after '$res'");
            return undef;
        }
        $res .= $buf;
    }
    if($self->{debug}){
	$self->_debug(caller, __LINE__, '_read_multiline', "got '$res'");
    }

    return \$res;
}

my $paren_rx;
$paren_rx = qr{\((?s:[^\\()]|\\.|(??{$paren_rx}))*\)};

sub _process_cmd {
    my ($self, %args) = @_;
    return unless $args{cmd};
    my $multicommand = (ref $args{cmd}->[0] eq 'ARRAY') ? scalar @{$args{cmd}} : 0;
    my (%id) = map {$_ => 1} $self->_send_cmd($multicommand  ? @{$args{cmd}} : $args{cmd});
    my $sock = $self->sock;

    my @resp;
    my $res;
    for(1 .. ($multicommand ? $multicommand : 1)) {
        while ( $res = $sock->getline ) {
            push @resp, {} if (not defined $resp[-1] or $resp[-1]->{tagged});
	    $self->_debug(caller, __LINE__, '_process_cmd', $res) if $self->{debug};
            if ( $res =~ /^\+/ and exists $args{cb} ) {
                $args{cb}($sock,$res);
            } elsif ( $res =~ /\G\*/gc) {
                my $array=[];
                NEXT:
                if ( $res =~ /\G(.*?
                                 (
                                  ?:\((?!\ )|  # begin (
                                  ^|[^\s\(](?=\ ) #or something else start with not ( and " "
                                 )
                                )
                                \ ?
                                ((?:[^ \[\]\(\)]|\[[^\[\]]*\])+)\ \{(\d+)\}\r$/gxc ) { # some {}
                    my ($rest,$tag) = ($1,$2);
                    if (my $body = $self->_read_multiline($3) ) {
                        push @$array, $rest,$tag,$body;
                        $res = $sock->getline;
                        goto NEXT;
                    } else { 
                        return undef;
                    }
                } else {
                    if($res =~ /\G(.*)\r$/gc) {
                        if (@$array) {
                            push @$array,$1;
                            push @{$resp[-1]->{untagged}},$array;
                        } else {
                            push @{$resp[-1]->{untagged}},$1;
                        }
                    }
                }
            } else {
                $resp[-1]->{tagged}->{raw} = $res;#error \r
                $resp[-1]->{untagged} = [] unless defined $resp[-1]->{untagged};
                if(my ($cmdid,$ok,$error) = ($res =~ /^(\S+) (\S+)(?: (.*))?\r$/)) {
                    if (exists $id{$cmdid}) {
                        delete $id{$cmdid};
                        $resp[-1]->{tagged}->{id} = $cmdid;
                        if (defined $ok) {
                            if ($ok eq 'OK') {
                                $resp[-1]->{tagged}->{ok} = 1;
                            } elsif ($ok eq 'NO') {
                                $resp[-1]->{tagged}->{ok} = 0;
                            } elsif ($ok eq 'BAD') {
                                $resp[-1]->{tagged}->{ok} = -1;
                            } else {
                                $resp[-1]->{tagged}->{ok} = undef;
                            }
                        } else {
                            $resp[-1]->{tagged}->{ok} = undef;
                        }
                        $resp[-1]->{tagged}->{message} = $error;
                    } else {
                        $resp[-1]->{tagged}->{id} = $cmdid;
#add error
                        $resp[-1]->{tagged}->{ok} = undef;
                        $resp[-1]->{tagged}->{message} = $error;
                    }
                } else {
#add error
                    $resp[-1]->{tagged}->{id} =
                    $resp[-1]->{tagged}->{ok} = undef;
	            return;
                }
                last;
            }
        }
    }
    return (not $multicommand and $#resp < 1) ? $resp[0] : \@resp;
}
sub OK {1};
sub NO {0};
sub BAD {-1};

sub _seterrstr {
    my ($self, $err) = @_;
    if ( $self->{_errstr}) {
        $self->{_errstr} .= "\n" unless ($self->{_errstr} =~ /\n$/);
        $self->{_errstr} .= $err;
    } else {
        $self->{_errstr} = $err;
    }
    $self->_debug(caller, __LINE__, '_seterrstr', $err) if $self->{debug};
    return;
}

sub _debug {
    my ($self, $package, $filename, $line, $dline, $routine, $str) = @_;

    $str =~ s/\n/\\n/g;
    $str =~ s/\r/\\r/g;
    $str =~ s/\cM/^M/g;

    $line = "[$package :: $filename :: $line\@$dline -> $routine] $str\n";
    if(ref($self->{debug}) eq 'GLOB'){
        syswrite($self->{debug}, $line);
    } else {
        print STDOUT $line;
    }
}

1;

__END__
