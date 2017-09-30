#!/usr/bin/perl
#
# dropbox_monitor - report status of Dropbox services.
#
# Jason White <jdwhite@menelos.com>
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
# This test can be installed as a client or server test, though a server
# test makes more sense given the client we're testing is not the local host.
#
# Install in $XYMONHOME/etc/tasks.d/dropbox_monitor
#  or add to $XYMONHOME/etc/tasks.cfg

#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# # Dropbox Monitor
# [dropboxmon]
#         ENABLED
#         ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
#         CMD $XYMONCLIENTHOME/ext/dropbox_monitor.pl
#         LOGFILE $XYMONCLIENTHOME/logs/dropbox_monitor.log
#         INTERVAL 5m
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

use strict;
use warnings;
use LWP::UserAgent;
use Text::Wrap;
use English;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib/perl5';
use lib dirname(abs_path $0) . '/../lib/perl5';
use XymonEXT;

## Globals ##
# main::URL is for the reference on the status page.
$main::URL = "http://status.dropbox.com";

#
# Fetch status page.
#
my($ua) = LWP::UserAgent->new;
my($req) = HTTP::Request->new(
	GET => $main::URL
);

# Pass request to the user agent and get a response.
my($resp) = $ua->request($req);

# Check the outcome of the response.
if ($resp->is_success) {
	$main::HTML = $resp->content;
}
else {
	print "Error reading $main::URL - ".$resp->status_line."\n";
	exit;
}

$main::HTML =~ s/\&nbsp;/ /go;

#
# Process each service; send status update.
#
while($main::HTML =~ /<div\s+.*?\sclass="component-inner-container\s+status-(\w+).+?<span class="name">\s*([^<]+)<\/span>.+?<span class="component-status">\s*([^<]+).+?<\/div>/iogsm)
{
	my($testcolor) = $1;
	my($service) = $2;
	my($status) = $3;
	my($message) = "";
	my($eventlog) = "";

	# Zorch trailing garbage.	
	$testcolor =~ s/[\s\n\r]+$//o;
	$service   =~ s/[\s\n\r]+$//o;
	$status    =~ s/[\s\n\r]+$//o;

	my($testname) = $service;
	#print "color='$testcolor'  testname='$testname'   status='$status'\n"; next;

	# Xymon doesn't have an orange status.
	$testcolor =~ s/orange/yellow/;

	set_testcolor("$testcolor");

	# Machine name this test is reporting for as defined in hosts.cfg.
	set_machinename("status,dropbox,com");

	# Munge test names to deal with problematic characters.
	$testname =~ s/[\(\)]//go;
	$testname =~ s/\s/_/go;
	$testname =~ s/\./,/go;
	$testname =~ s/\&/and/go;

	set_summary($status);
	set_testname($testname);

	$message .= sprintf("&%s %s: %s\n", &get_testcolor(), $service, $status);
	$message .= "\nSource: <A HREF=\"${main::URL}\">${main::URL}</a>\n";

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
