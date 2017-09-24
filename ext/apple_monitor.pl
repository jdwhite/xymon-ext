#!/usr/bin/perl
#
# apple_monitor - report status of Apple's services.
#
# Jason White <jdwhite@menelos.com>
#
=begin License

The MIT License (MIT)

Copyright (c) 2015 Jason White <jdwhite@menelos.com>

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
# This test can be installed as a client or server test, though a server
# test makes more sense given the client we're testing is not the local host.
#
# Install in $XYMONHOME/etc/tasks.d/apple_monitor
#  or add to $XYMONHOME/etc/tasks.cfg

#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# # Apple Monitor
# [applemon]
#         ENABLED
#         ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
#         CMD $XYMONCLIENTHOME/ext/apple_monitor
#         LOGFILE $XYMONCLIENTHOME/logs/apple_monitor.log
#         INTERVAL 10m
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
# The apple status page currently contains 45 Services. Since displaying 
# all 45 columns in a single host is visually disturbing, I recommend 
# placing this host on a separate 'vpage' so that the the tests are 
# displayed vertically like they are hosts.
#
# I recommend using a real, resolvable host name so that conn test 
# works. This will keep Xymon from generating a ton of alerts in the 
# event of transient network outages.
#
# hosts.cfg
# ---------
# vpage apple Apple Services
# 0.0.0.0         www.apple.com                   # conn NAME:"Apple Services"
#

use strict;
use warnings;
use LWP::UserAgent;
use Text::Wrap;
use JSON;
use English;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib/perl5';
use lib dirname(abs_path $0) . '/../lib/perl5';
use XymonEXT;


## Globals ##
# main::URL is for the reference on the status page.
$main::URL      = "http://www.apple.com/support/systemstatus/";
# Note: substitute the "en_US" suffix in URL_JSON to reflect your own locale.
$main::URL_JSON = "http://www.apple.com/support/systemstatus/data/system_status_en_US.js";

#
# Fetch JSON service log.
#
my($ua) = LWP::UserAgent->new;
my($req) = HTTP::Request->new(
	GET => $main::URL_JSON
);

# Pass request to the user agent and get a response.
my($resp) = $ua->request($req);

# Check the outcome of the response.
$main::json_service_log = "";
if ($resp->is_success) {
	$main::json_service_log = $resp->content;
} else {
	print "Error reading service statuslog - ".$resp->status_line."\n";
	exit;
}

# Decode JSON into a hash, converting any UTF-8 characters in the process.
$main::EVENTLOG = decode_json $main::json_service_log;

#
# $main::EVENTLOG is a hash that contains two keys used by this test:
#
# dashboard->services - a hash arrays with the key being the service name and the 
#                       value being an array of hashes containing metadata regarding
#                       the current status.
#
# detailedTimeline - an array of hashes containing previous events for the last N days.
#                    (I believe N is 3, but not confirmed.)
#

#
# Process each service; send status update.
#
foreach my $service (keys %{$main::EVENTLOG->{dashboard}->{Services}}, "Timeline")
{
	my($testname) = $service;
	my($status) = "OK";
	my($message) = "";
	my($eventlog) = "";

	set_testcolor("clear");

	# Host this test is reporting for as defined in hosts.cfg.
	set_machinename("www,apple,com");

	# Munge test names to deal with problematic characters.
	$testname =~ s/[\(\)]//go;
	$testname =~ s/\s/_/go;
	$testname =~ s/\./,/go;
	$testname =~ s/\&/and/go;
	
	if ($service ne "Timeline" &&
	    scalar(@{$main::EVENTLOG->{dashboard}->{Services}->{$service}}) != 0)
	{
		#
		# Process service events
		#
		foreach my $item (@{$main::EVENTLOG->{dashboard}->{Services}->{$service}})
		{
			$status = $item->{statusType};
			$status =~ s/([a-z]+)([A-Z])/$1 $2/g;

			if ($status eq "Maintenance" ||
			    $status eq "Service Issue") {
				set_testcolor("yellow");
			} elsif ($status eq "Service Outage") {
				set_testcolor("red");
			} else {
				set_testcolor("yellow");
			}

			$eventlog = sprintf("===== %s - %s =====\n".
			                    "Posted: %s\n".
			                    "  Type: %s\n".
			                    " Issue: %s\n\n",
			                    $item->{messageTitle}, $item->{usersAffected},
			                    $item->{datePosted},
			                    $status,
			                    $item->{shortMessage},
			);
		}
	}
	else
	{
		#
		# No event data for this service.
		#
		set_testcolor("green") unless ($service eq "Timeline");
	}

	set_summary($status);
	set_testname($testname);

	if ($service ne "Timeline") {
		$message .= sprintf("%s: %s &%s\n", $service, $status, get_testcolor());
	}
	$message .= "\n";

	if ($eventlog ne "") {
		$message .= "${eventlog}\n";
	}

	#
	# Check detailed timeline message titles for entries matching current
	# service title and append timeline entry to service information page.
	#
	my($timeline_header) = 0;
	foreach my $event (@{$main::EVENTLOG->{detailedTimeline}})
	{
		if ($service eq "Timeline" || $event->{messageTitle} =~ /^${service}/i)
		{
			if ($timeline_header == 0)
			{
				my($TimelineName) = ($service eq "Timeline" ? "All Services" : $service);
				
				$timeline_header = 1;
				$message .= "<<<< Detailed Service Timeline: $TimelineName >>>>\n\n";
			}
			$event->{message} =~ s/^\s*//;
			my($status) = $event->{statusType};
			$status =~ s/([a-z]+)([A-Z])/$1 $2/g;

			my($entry) = sprintf("===== %s - %s [%s] =====\n".
			                     "Posted: %s\n".
			                     "  Type: %s\n".
			                     "  Date: %s - %s\n".
			                     " Issue: %s\n\n",
		        	         $event->{messageTitle}, $event->{usersAffected},
			                 ($event->{endDate} !~ /^\s*$/) ? "resolved" : "open",
			                 $event->{datePosted},
			                 $status,
			                 $event->{startDate}, $event->{endDate},
			                 wrap("", "        ", $event->{message})
			);
			$message .= $entry;
		}
	}

	$message .= "Source: <A HREF=\"${main::URL}\">${main::URL}</a>\n";

	#
	# == Report findings ==
	#
	# Note send_status() takes a hash of arguments; it's like varargs for perl. :)
	# Arguments are:
	#
	#   "lifetime" - lifetime of the report.
	#   "group"    - reporing group
	#   "hostname" - name of machine we report as
	#   "testname" - name of test
	#   "color"    - canonical test color to report
	#   "message"  - the body of the rest report (diagnostic information)
	#   "summary"  - brief text shown on first line after date and test name
	#

	send_status(
		"message"  => $message,
	);
}

exit;
