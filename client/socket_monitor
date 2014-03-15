#!/usr/bin/perl
#
# socket_monitor - report network socket usage.
#
# Jason White <jdwhite@menelos.com>
# 17-Jan-2014 (initial release)
#
=begin License

The MIT License (MIT)

Copyright (c) 2014 Jason White <jdwhite@menelos.com>

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
# This program fetches the box.com service page and creates Xymon tests.
#
# I wrote this to track excessive socket usage reported in this thread:
# https://discussions.apple.com/thread/5551686
# "My network connection completely died - "failed: 49 - Can't assign 
#  requested address"
#
# Also configured Xymon to collect and graph the values collected.
#
# Initial indentation of is done with tabs; successive alignment is done 
# with spaces. To format this code per your indentation preference, say, 
# 4 spaces per tab stop:
#	less -x4
#	nano -T4
#	vim (set tabstop=4 (also in .vimrc))
#	vi  (set ts=4 (also in .exrc))
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Install in $XYMONCLIENTHOME/client/ext/.
# Modify $XYMONCLIENTHOME/etc/clientlaunch.cfg and add this block:
#
# # Network Socket Monitor
# [socketmon]
#	  ENABLED
#	  ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
#	  CMD $XYMONCLIENTHOME/ext/socket_monitor
#	  LOGFILE $XYMONCLIENTHOME/logs/socket_monitor.log
#	  INTERVAL 2m
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#

use strict;
#use warnings;

## Globals ##
# ::MACHINE/DOTS - host this test is reporting for as defined in hosts.cfg.
#$main::MACHINE     = "some,machine,domain,com"; # If reporting for another host.
$main::MACHINE	    = $ENV{MACHINE};
$main::MACHINEDOTS  = $ENV{MACHINEDOTS};

# ::TESTNAME - the title of the test column.
$main::TESTNAME     = 'socket';

# ::COLOR - the canonical test color.
$main::COLOR        = "clear";

# ::DATA - diagnostic data sent to the server along with status and summary.
$main::DATA	= "";

# ::PRIORITY - the relative weight of test colors, used for determining
#	when to update $main::COLOR while evaluating test criterion.
%main::PRIORITY = (
	"red"    => 4,
	"yellow" => 3,
	"green"  => 2,
	"clear"  => 1
);

#=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

$main::YELLOW_MARK = 500;
$main::RED_MARK    = 700;

$main::NETSTAT_CMD = "netstat -an -f inet";

$main::DATA .= "Results of \"$main::NETSTAT_CMD\"\n\n";

#
# Gather socket stats.
#
open(NETSTAT, "${main::NETSTAT_CMD}|") || do {
	$main::DATA .= "Error running \"${main::NETSTAT_CMD}\": $!";
	$main::COLOR = "red";
};

%main::count = (
	"CLOSED"      => 0,
	"LISTEN"      => 0,
	"SYN_SENT"    => 0,
	"SYN_RCVD"    => 0,
	"ESTABLISHED" => 0,
	"CLOSE_WAIT"  => 0,
	"LAST_ACK"    => 0,
	"FIN_WAIT_1"  => 0,
	"FIN_WAIT_2"  => 0,
	"CLOSING"     => 0,
	"TIME_WAIT"   => 0
);

while(<NETSTAT>) {
	next unless /^tcp/io;
	chomp;
	my($proto, $rq, $sq, $local, $foreign, $state) = split(/\s+/, $_);
	$main::count{$state}++;
}
close(NETSTAT);

foreach my $state (sort keys %main::count) {

	my($line_color);
	if ($main::count{$state} < $main::YELLOW_MARK) {
		$line_color = "green";
		$main::status = "OK";
	}
	elsif ($main::count{$state} >= $main::YELLOW_MARK) {
		$line_color = "yellow";
		$main::status = "lots of sockets in use";
	}
	elsif ($main::count{$state} >= $main::RED_MARK) {
		$line_color = "red";
		$main::status = "high number of sockets in use";
	}

	$main::DATA .= sprintf("%15s: % 4d", $state, $main::count{$state});

	# Now eveluate the current line's color and see if it's priority
	# is higher than the canonical color. If so, update the
	# canonical color.
	if ($line_color ne "") {
		$main::DATA .= " \&${line_color}";

		if ($main::PRIORITY{$line_color} > $main::PRIORITY{$main::COLOR}) {
			$main::COLOR = $line_color;
		}
	}

	$main::DATA .= "\n";
}

##
## Generate status report
##

# STATUS - Canonical status of test and its lifetime: status[+LIFETIME]
#$STATUS = "status+25h ${main::MACHINE}.${main::TESTNAME} ${main::COLOR}";
$main::STATUS = "status ${main::MACHINE}.${main::TESTNAME} ${main::COLOR}";

# SUMMARY - datestamp and summary of the test.
$main::SUMMARY = scalar(localtime(time))." - ${main::TESTNAME}: $main::status";

# MESSAGE - status, summary, diagnostic data combined.
$main::MESSAGE = "${main::STATUS} ${main::SUMMARY}\n\n${main::DATA}";

##
## Send to Xymon or to stdout if run interactively.
##
if (defined($ENV{XYMON})) {
	# "at" sign as argument means "read message data from stdin".
	# DON'T USE A DASH AS THE xymon USAGE MESSAGE SHOWS ELSE ONLY
	# THE SUMMARY INFORMATION IS DISPLAYED AND NONE OF $main::DATA.
	# THE MANPAGE USAGE OF "@" IS CORRECT.
	open(XYMON, "| $ENV{XYMON} $ENV{XYMSRV} @") || do {
		print "Error invoking $ENV{XYMON} $ENV{XYMSRV} @ - $!";
		exit;
	};
	select(XYMON);
}
else {
	print STDERR "*** Not invoked by Xymon; sending to stdout ***\n\n";
}

print $main::MESSAGE;
close(XYMON);

exit;
