#!/usr/bin/perl
#
# google_monitor - report status of Google services
#
# Jason White <jdwhite@menelos.com>
# 8-Feb-2014 (initial release)
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
# This program fetches the google services logs in JSON format and creates
# Xymon tests.
#
# Initial indentation of is done with tabs; successive alignment is done 
# with spaces. To format this code per your indentation preference, say, 
# 4 spaces per tab stop:
#	  less -x4
#	  nano -T4
#	  vim (set tabstop=4 (also in .vimrc))
#	  vi  (set ts=4 (also in .exrc))
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# 1) Install this file in $XYMONHOME/ext/
#
# 2) Create $XYMONHOME/etc/tasks.d/google with this block:
#    -or-
#    Modify $XYMONHOME/etc/tasks.cfg and add this block:
#
# # Google Monitor
# [googlemon]
#	  ENABLED
#	  ENVFILE $XYMONHOME/etc/xymonserver.cfg
#	  CMD $XYMONHOME/ext/google_monitor
#	  LOGFILE $XYMONHOME/logs/google_monitor.log
#	  INTERVAL 10m
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
# I recommend using a real, resolvable host name for this test so the 
# conn test works.  This will keep Xymon from generating a ton of alerts 
# in the event of transient network outages.
#
# hosts.cfg
# ---------
# 0.0.0.0         apps.google.com                 # conn NAME:"Google Services"
#
#use strict;
use warnings;

use LWP::UserAgent;
use Text::Wrap;
use JSON;
use Data::Dumper;

## Globals ##
$main::URL          = "http://www.google.com/appsstatus";
$main::URL_JSON     = "http://www.google.com/appsstatus/json/en";
#$main::MACHINE     = $ENV{MACHINE};
$main::MACHINE      = "apps,google,com"; # What we report as.
#$main::MACHINEDOTS = $ENV{MACHINEDOTS}; # unused

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
	# What google serves isn't (apparently) valid JSON, so fix it.
	$main::json_service_log =~ s/^dashboard.jsonp\(//;
	$main::json_service_log =~ s/\);$//;
}
else {
	print "Error reading service statuslog - ".$resp->status_line."\n";
	exit;
}

# Decode JSON into a hash, converting any UTF-8 characters in the process.
$main::EVENTLOG = decode_json $main::json_service_log;
#print Dumper $main::EVENTLOG; exit;

#
# ::EVENTLOG is a hash that contains two keys used by this test: 
#
#  services - an array of hashes created from the following example data:
#
#     {"id":1,"sort":1,"name":"Gmail","type":0}
#
#     This test uses 'id' and 'name'.  'id' is an integer used to 
#     identify a service named by 'name'. 'id' is used to reference an 
#     array of hashes containing log events in the 'messages' array
#     of hashes below to reference a hash of events.
#
#     Note: 'type' field; boolean indicating Premier service.
#
#   messages - an array of hashes created from the following example data:
#
#     {"service":1,
#     "outageId":"8201b96db60ea3ccc26c53a4487c5492", 
#     "time":1390613580000,
#     "pst":"January 24, 2014 5:33:00 PM PST", 
#     "message":"The problem with Gmail should be resolved. We apologize 
#     for the inconvenience and thank you for your patience and 
#     continued support. Please rest assured that system reliability is 
#     a top priority at Google, and we are making continuous 
#     improvements to make our systems better.",
#     "type":3, 
#     "resolved":true,
#     "premier":false,  
#     "additionals":["An incident report for this issue is available in 
#     the form of a [[http://googleblog.blogspot.com/2014/01/todays-outage-for-several-google.html][blog
#     post]] on the official Google blog."]}
#
#     This test uses fields from each hash to create an log of events 
#     for a particular service.
#
#     Note: 'type' field; integer indicating state of service.
#     Note: 'time' field; time_t in milliseconds. Divide by 1000 to get 
#           traditional time_t suitable for localtime() call.
#

# Define message type codes into Xymon color markers.
%main::MESSAGE_TYPE_COLOR = (
	"1" => "yellow", # Service disruption.
	"2" => "red",    # Service outage?? (need outage example)
	"3" => "green",  # Service restored.
	"4" => "green"   # Incident report posted.
);	

%main::MESSAGE_TYPE_STRING = (
	"1" => "Service disruption",
	"2" => "Service outage",    # need confirmation
	"3" => "OK",
	"4" => "OK; incident report posted"
);

#
# Create message log hash keyed by service ID.
#
%main::MESSAGES_BY_SERVICEID = ();
foreach my $event (@{$main::EVENTLOG->{messages}}) {
	#print Dumper $event,"\n"; next;
	push(@{$main::MESSAGES_BY_SERVICEID{$event->{service}}}, $event);
}

#
# Iterate through entries in service hash, pick out the service IDs, and 
# check for messages by ID.
#
foreach my $entry (@{$main::EVENTLOG->{services}}) {
	#print "DEBUG: ".$entry->{name}."=".$entry->{id},"\n";
	#print Dumper $entry,"\n";

	my($TESTNAME) = $entry->{name}; # Xymon column name
	my($sid)      = $entry->{id};   # Google Service ID
	my($DATA)     = "";             # Diagnostic data (service log)
	my($service)  = $entry->{name}; # Full service name.
	my($COLOR);
	my($status);

	# Remove redundant info.
	$TESTNAME =~ s/^Google\+*\s+//;
	$TESTNAME =~ s/\s+/_/g;

	# Sort the messages for a given service by time, descending.
	my(@servicelog) = @{$main::MESSAGES_BY_SERVICEID{$sid}};
	if (scalar(@{$main::MESSAGES_BY_SERVICEID{$sid}}) > 1) {
		@servicelog = sort {$b->{time} <=> $a->{time}} 
		              @{$main::MESSAGES_BY_SERVICEID{$sid}};
	}

	#
	# Determing the overall service status by looking at the value 
	# of the 'type' key in most recent event log.  If no entries in 
	# $servicelog, assume the service is available (green).
	#
	if (defined($servicelog[0])) {
		$COLOR = $main::MESSAGE_TYPE_COLOR{$servicelog[0]->{type}};
		$status = $main::MESSAGE_TYPE_STRING{$servicelog[0]->{type}};
	}
	else {
		$COLOR = "green";
		$status = "OK";
	}

	# Check for new/unknown type codes and alert if unknown.
	if (defined($servicelog[0]) &&
	    ! defined($main::MESSAGE_TYPE_COLOR{$servicelog[0]->{type}})) {
		$COLOR = "yellow";
		$status = "UNKNOWN STATUS TYPE $servicelog[0]->{type}";
	}

	$DATA .= sprintf("%s: %s &%s\n\n", $service, $status, $COLOR);

	# Append diagnostic data regarding unknown type code.
	if (defined($servicelog[0]) &&
	    ! defined($main::MESSAGE_TYPE_COLOR{$servicelog[0]->{type}})) {
		$DATA .= Dumper(@servicelog);
	}

	# Add service log entries to diagnostic data.
	foreach my $event (@servicelog) {
		$Text::Wrap::columns = 100;		
		$DATA .= sprintf("&%s %s%s\n%s\n\n",
			$main::MESSAGE_TYPE_COLOR{$event->{type}},
			scalar(localtime(int($event->{time}/1000))),
			($event->{resolved} == 1) ? " [resolved]" : "",
			wrap("   ", "   ",
				&mangle_text($event->{message})
			)
		);

		# Check for additional data and display;
		if (defined($event->{additionals})) {
			$DATA .= "   Additional Info\n   ---------------\n";
			foreach my $note (@{$event->{additionals}}) {
				## Don't wrap text because it destroys URLs.
				#$DATA .= "      * ".&mangle_text($note)."\n";
				# Wrapping may destroy URLs, but looks much nicer
				# then whole paragraph on a single line.
				$DATA .= sprintf("%s\n",
				                 wrap("   ", "   ",
				                      &mangle_text($note)));
			}
			$DATA .= "\n";
		}
	}
	#if ($COLOR ne "green") {
	$DATA .= "\nSource: <A HREF=\"${main::URL}\">${main::URL}</a>\n";
	#}

	#
	# Generate status report.
	#
	# STATUS - Canonical status of test and its lifetime: status[+LIFETIME]
	my($STATUS) = "status ${main::MACHINE}.${TESTNAME} ${COLOR}";

	# SUMMARY - datestamp and summary of the test.
	my($SUMMARY) = scalar(localtime(time))." - ${TESTNAME}: $status";

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

sub
mangle_text
{
	my($text) = shift(@_);

	# Convert links in the form of [[URL][linkname]] to HTML.
	$text =~ s/\[\[([^\]]+?)\]\[([^\]]+?)\]\]/\<A HREF=\"$1\"\>$2\<\/A\>/gi;

	# Convert date stamps in form of {{`/bin/date`}{{time_t*1000}} to
	# localtime.
	$text =~ s/\{\{[^\}]+?\}\{(\d+)\}\}/scalar(localtime(int($1\/1000)))/egi;

	return $text;
}
