#!/usr/bin/perl
#
# box_monitor - report status of Box.com services
#
# Jason White <jdwhite@menelos.com>
# 12-Feb-2014 (initial version)
#
=begin License

The MIT License (MIT)

Copyright (c) 2017 Jason White <jdwhite@menelos.com>

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
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# 1) Install this file in $XYMONHOME/ext/
#
# 2) Create $XYMONHOME/etc/tasks.d/box with this block:
#    -or-
#    Modify $XYMONHOME/etc/tasks.cfg and add this block:
#
# # Box.com Monitor
# [boxmon]
#	  ENABLED
#	  ENVFILE $XYMONHOME/etc/xymonserver.cfg
#	  CMD $XYMONHOME/ext/box_monitor
#	  LOGFILE $XYMONHOME/logs/box_monitor.log
#	  INTERVAL 10m
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
# I recommend using a real, resolvable host name for this test so the 
# conn test works.  This will keep Xymon from generating a ton of alerts 
# in the event of transient network outages.
#
# hosts.cfg
# ---------
# 0.0.0.0         status.box.com                 # conn NAME:"Box Services"
#

use DateTime;
use LWP::UserAgent;
use HTML::FormatText::WithLinks;
use Data::Dumper;

## Globals ##
$main::BASEURL  = "http://status.box.com"; # main
$main::MACHINE  = "status,box,com"; # What we report as.

# Fetch main status page HTML.
$main::HTML = &http_fetch($main::BASEURL);

#
# Trim down HTML for easier parsing and debugging.
#
#$main::HTML =~ s/^.+<tbody>(.+)<\/tbody>.+$/$1/ism;

#
# Box has four current status states and the following has provides a 
# translation table.
#
#  'Operational           - all good.
#  'Degraded Performance' - something's amiss.
#  'Partial Outage'       - self explanatory.
#  'Major Outage'         - totally borked.
#
%main::BOX2XYMONCOLOR = (
	'Operational'          => 'green',
	'Degraded Performance' => 'yellow',
	'Partial Outage'       => 'yellow',
	'Major Outage'         => 'red'
);

# ## DEBUG ##
#print Dumper $main::HTML;
#exit;

#
# Each service has a <div class="component-container..." block.
#
while ($main::HTML =~ /<span\s+class=\"name\">\s*([^<\n]+)\s*.+?<span class=\"component-status\">\s*([^<\n]+)\s*.+?\<\/span>/iogsm) {
	my($TESTNAME) = $1;
	my($status) = $2;
	my($COLOR);
	my($DATA) = "";
	my($service) = $TESTNAME;

	#print "DEBUG: TESTNAME='$TESTNAME'  status='$status'\n";
	#next;

	if (defined($main::BOX2XYMONCOLOR{$status})) {
		$COLOR = $main::BOX2XYMONCOLOR{$status};
	}
	else {
		$status = "UNKNOWN STATUS '${status}'";
		$COLOR = "red";
	}

	$DATA .= "${service}: $status &$COLOR\n\n";

	# Reference.
	$DATA .= "Source: <A HREF=\"${main::BASEURL}\">${main::BASEURL}</A>\n";

	#
	# Generate status report.
	#
	# SUMMARY - datestamp and summary of the test.
	my($SUMMARY) = scalar(localtime(time))." - ${TESTNAME}: $status";

	# STATUS - Canonical status of test and its lifetime: status[+LIFETIME]
	$TESTNAME =~ s/\s/\-/go;
	my($STATUS) = "status ${main::MACHINE}.${TESTNAME} ${COLOR}";

	# MESSAGE - status, summary, diagnostic data combined.
	my($MESSAGE) = "${STATUS} ${SUMMARY}\n\n${DATA}";

	#
	# Send to Xymon or to stdout if run interactively.
	#
	if (defined($ENV{XYMON})) {
		# "at" sign as argument means "read message data from stdin".
		# DON'T USE A DASH AS THE xymon USAGE MESSAGE SHOWS ELSE ONLY
		# THE SUMMARY INFORMATION IS DISPLAYED AND NONE OF ${DATA}.
		# THE MANPAGE USAGE OF "@" IS CORRECT.

		open(XYMON, "| $ENV{XYMON} $ENV{XYMSRV} @") || do {
			print "Error invoking $ENV{XYMON} $ENV{XYMSRV} @ - $!";
			exit;
		};
		select(XYMON);
	}
	else {
		print STDERR "*** Not invoked by Xymon; ".
		             "sending to stdout ***\n\n";
	}

	print $MESSAGE;
	close(XYMON);
}

exit;

#
# Fetch page by URL.
#
sub http_fetch
{
	my($URL) = shift(@_);
	my($ua) = LWP::UserAgent->new;
	my($HTML);
	my($req) = HTTP::Request->new(
		GET => $URL
	);

	# Pass request to the user agent and get a response.
	my($resp) = $ua->request($req);

	# Check the outcome of the response.
	if ($resp->is_success) {
		$HTML = $resp->content;
	}
	else {
		print STDERR "Error reading $URL - ".$resp->status_line."\n";
	}

	return($HTML);
}
