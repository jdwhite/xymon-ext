#!/usr/bin/env perl
#
# tm_status - report status of Time Machine backups
#
# Jason White <jdwhite@menelos.com>
#
=begin License

The MIT License (MIT)

Copyright (c) 2016 Jason White <jdwhite@menelos.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=end License
=cut

#
# Install in $XYMONCLIENTHOME/client/ext/.
# Modify $XYMONCLIENTHOME/etc/clientlaunch.cfg and add this block:
#
# # Time Machine
# [TimeMachine]
#    ENABLED
#    ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
#    CMD $XYMONCLIENTHOME/ext/tm_status
#    LOGFILE $XYMONCLIENTHOME/logs/tm_status.log
#    INTERVAL 5m
#
# In some cases, 'tmutil listbackups' may require root privlidges.
# Modify /etc/sudoers to allow user xymon to run /usr/bin/tmutil:
#
#        xymon   ALL= NOPASSWD: /usr/bin/tmutil
#

use strict;
use warnings;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib/perl5';
use lib dirname(abs_path $0) . '/../lib/perl5';
use Carp;
use DateTime;
use XymonEXT;

#
# Test configuration.
#
# Number of hours since last backup before reporting non-green.
$main::yellow_hours = 3; 
$main::red_hours    = 24;
set_testname("tm");

#====================================================================

#
# Initialize defaults.
#
$main::message      = "";

#
# Collect basic TM information.
#
open(TMUTIL, "tmutil destinationinfo |") || croak "Error executing 'tmutil destinationinfo' - $!";
while(<TMUTIL>) { $main::message .= "   ".$_; }
close(TMUTIL);

#
# Dump backup list.
#
@main::backuplist = ();
$main::has_machine_directory = 0;
open(TMUTIL, "sudo tmutil listbackups 2>&1 |") || croak "Error executing 'tmutil listbackups' - $!";
#open(TMUTIL, "echo No machine directory found |") || croak "Error executing 'tmutil listbackups' - $!";
while(<TMUTIL>) {
	if (/No machine directory found/io) {
		&set_testcolor("red");
		$main::message .= "\n&red No Time Machine volume mounted.";
		$main::has_machine_directory = 0;
	}
	next unless /\/\d{4}\-\d{2}-\d{2}\-\d{6}$/o;
	$main::has_machine_directory = 1;
	chomp;
	push(@main::backuplist, $_);
}
close(TMUTIL);

#
# Generate backup set data, if available.
#
if ($main::has_machine_directory == 1) {
	my($LocalTZ) = DateTime::TimeZone->new( name => 'local' );

	# Determine oldest backup date.
	my($o_year, $o_mon, $o_day, $o_hour, $o_min, $o_sec)
		= ($main::backuplist[0]
		=~ /\/(\d{4})\-(\d{2})-(\d{2})\-(\d{2})(\d{2})(\d{2})$/);
	my($dt_oldest) = DateTime->new(
		year   => $o_year,
		month  => $o_mon,
		day    => $o_day,
		hour   => $o_hour,
		minute => $o_min,
		second => $o_sec,
		time_zone => $LocalTZ
	);
	#print "o_year=$o_year o_mon=$o_mon o_day=$o_day o_hour=$o_hour o_min=$o_min o_sec=$o_sec\n";

	# Determine latest backup date.
	my($l_year, $l_mon, $l_day, $l_hour, $l_min, $l_sec)
		= ($main::backuplist[$#main::backuplist]
		=~ /\/(\d{4})\-(\d{2})-(\d{2})\-(\d{2})(\d{2})(\d{2})$/);
	my($dt_latest) = DateTime->new(
		year   => $l_year,
		month  => $l_mon,
		day    => $l_day,
		hour   => $l_hour,
		minute => $l_min,
		second => $l_sec,
		time_zone => $LocalTZ
	);
	#print "l_year=$l_year l_mon=$l_mon l_day=$l_day l_hour=$l_hour l_min=$l_min l_sec=$l_sec\n";

	$main::message .= sprintf("   %-14s: %s %s (%s ago)\n",
		"Oldest backup", $dt_oldest->ymd, $dt_oldest->hms,
		&sec2dhms_string(time - $dt_oldest->epoch)
	);

	my($linecolor);
	my($sec_since_last) = time - $dt_latest->epoch;
	if ($sec_since_last >= ($main::yellow_hours * 3600)) {
		$linecolor = "yellow";
	} elsif ($sec_since_last >= ($main::red_hours * 3600)) {
		$linecolor = "red";
	} else {
		$linecolor = "green";
	}
	set_testcolor($linecolor);

	$main::message .= sprintf("&%s %-14s: %s %s (%s ago)\n",
		$linecolor, "Latest backup",
		$dt_latest->ymd, $dt_latest->hms,
		&sec2dhms_string(time - $dt_latest->epoch)
	);

}

send_status(
	"message" => $main::message
);

exit;

sub sec2dhms_string
#
# Take a integer value in seconds and return a string in the form of:
#
#   Xd XhXmXs
#
# Example: sec2dhms_string(7230) returns "2h:0m:30s".
#
{
	my %tm_divisors = (
	        86400 => "d",
	         3600 => "h",
	           60 => "m",
	            1 => "s"
	);

	my $tm_dividend = int($_[0]);
	my $time_str = "";

	foreach my $tm_divisor (sort {$b <=> $a} keys %tm_divisors) {
		my $tm_quotient = int($tm_dividend / $tm_divisor);
		if (($tm_quotient >= 1) ||                   # a non-zero result
		    ($time_str ne "" && $tm_dividend > 0) || # no zero quotient result at start of string
		    ($time_str eq "" && $tm_divisor == 1)    # no results no far; show this quotient
		   ) {
			$tm_dividend = $tm_dividend % $tm_divisor;
			$time_str .= "${tm_quotient}${tm_divisors{$tm_divisor}}";
		}
	}

	$time_str =~ s/(\dd)/$1 /;
	while ($time_str =~ s/(\d[hm])(\d)/$1:$2/) {}

	return $time_str;
}

