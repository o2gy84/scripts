#!/usr/bin/perl

use strict;
use warnings;
use utf8;

if(not defined $ARGV[0])
{
    print "need BASE_DIR for tests (like A-1, A-2, ... A-N) as cmd argument\n";
    exit 0;
}

sub process_dat_text
{
# chomp last LF symbol

	my $text = shift;
	my $len = length ($text);
	if( $len > 1)
	{
		while(1)
		{
			my $last_char = substr($text, -1);
			if(ord($last_char) == 10)
			{
				$text = substr($text, 0, -1) if(ord($last_char) == 10);
			}
			else
			{
				last;
			}
		}
	}

	return $text;
}

sub process_dat_file
{
	my $file = shift;
	open FILE, "<", $file or die $!;
	binmode FILE;
	my ($buf, $data, $n);
	while (($n = read FILE, $data, 128) != 0)
	{
		$buf .= $data;
	}
	close(FILE);

	if(defined $buf && length($buf) > 0)
	{
		my $valid_text = process_dat_text($buf);
		if($valid_text ne $buf)
		{
			print "file was corrected: $file\n";
			open FILE, ">", $file or die $!;
			binmode FILE;
			print FILE $valid_text;
			close(FILE);
		}
	}
	else
	{
		print "file '$file': empty test\n";
	}
}

sub process_test_dir
{
	my $dir = shift;
	opendir(DIR_LOCAL, $dir) or die "no valid test dir founded in '$dir': $!";
	while (my $file = readdir(DIR_LOCAL))
	{
		next unless ($file =~ /.dat$/);
#print "file: " . $file . "\n";
		process_dat_file("$dir/$file");
	}
	closedir(DIR_LOCAL);
}

opendir(DIR, $ARGV[0]) or die $!;

while (my $file = readdir(DIR))
{
	my $dir = "$ARGV[0]/$file";
	next if ($file =~ m/^\./);
	next unless (-d $dir);
	print "process test directory: $dir\n";

	$dir .= "/tests";
	process_test_dir($dir);
}

closedir(DIR);
exit 0;
