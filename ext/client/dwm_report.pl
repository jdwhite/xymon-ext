#!/usr/bin/perl
#
# dwm_report - push NetBSD daily/weekly/monthly output logs and annotate.
#
# Jason White <jdwhite@menelos.com>
#
=begin License

The MIT License (MIT)

Copyright (c) 2014 Jason White <jdwhite@menelos.com>

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=end License
=cut

#
# Install in $XYMONCLIENTHOME/client/ext/.
# Modify $XYMONCLIENTHOME/etc/clientlaunch.cfg and add this block:
#
# # Daily/Weekly/Monthly Report
# [dwmreport]
#         ENABLED
#         ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
#         CMD $XYMONCLIENTHOME/ext/dwm_report
#         LOGFILE $XYMONCLIENTHOME/logs/dwm_report.log
#         INTERVAL 1d
#
# To get security reports, they need to be included in the daily.out 
# file rather than emailed. For NetBSD versions supporting the 
# separate_security_email option:
#     grep -i separate /etc/defaults/daily.conf
#     separate_security_email=YES
# disable this by setting to NO in daily.conf. Support for this 
# directive can be easily added to older systems' /etc/daily script. 
#

## Globals ##
$::TESTNAME	= 'dwm';
$::COLOR	= "green";
$::DATA = "";

@::files = (
	"/var/log/daily.out",
	"/var/log/weekly.out",
	"/var/log/monthy.out"
);

%::PRIORITY = (
	"red"    => 6,
	"yellow" => 5,
	"green"  => 4,
	"blue"   => 1,
	"clear"  => 1
);

foreach my $reportfile (@::files) {
	if (! -e "$reportfile") {
		$reportfile =~ /\/([^\/]+)\.out$/;
		my($type) = $1;
		my $msg = "No $type report available.";
		$DATA .= "=" x length($msg)."\n";
		$DATA .= "$msg\n";
		$DATA .= "=" x length($msg)."\n";
		next;
	}

	open(LOG, "$reportfile") || do {
		$DATA .= "Unable to open $reportfile - $! &red\n";
	};
	while(<LOG>) {
		my($line_color) = "";
		next if /^To: root\s*$/o;
		if (/^Subject:/) {
			s/^Subject:\s+//;
			chomp;
			$DATA .= "=" x length($_)."\n";
			$DATA .= "$_\n";
			$DATA .= "=" x length($_)."\n";
			next;
		}
		chomp;
		$DATA .= $_;

		if (/failed\s/io) {
			$line_color = "red";
		}
		elsif (/(Error|Cannot)\s/o) {
			if (! /makemandb: Error in indexing/io) {
				$line_color = "yellow"
			}
		}
		elsif (/Possible core dumps:/io) {
			$line_color = "yellow";
		}
		elsif (/^(type|gid|user)\s+\(/io) {
			$line_color = "yellow";
		}
		elsif (/^(permissions)\s+\(/io) {
			$line_color = "red";
		}
		elsif (/^missing:\s+/io) {
			$line_color = "yellow";
		}
		elsif (/no such file or directory/io) {
			$line_color = "yellow";
		}
		elsif (/^user\s.*?\smailbox/io) {
			$line_color = "yellow";
		}

		if ($line_color ne "") {
			$DATA .= " \&${line_color}";

			if ($::PRIORITY{$line_color} > $::PRIORITY{$::COLOR}) {
				$::COLOR = $line_color;
			}
		}

		$DATA .= "\n";
	}
	close(LOG);

	$DATA .= "\n";
}

##
## Generate status report
##
$STATUS = "status+25h $ENV{MACHINE}.${::TESTNAME} ${::COLOR}";
$SUMMARY = "${::TESTNAME}: ";
$SUMMARY .= ($::COLOR eq "green") ? "OK" : "Something Potentially Odd";

$DATE = scalar(localtime(time));

$MESSAGE = "$STATUS ${DATE} ${SUMMARY}\n\n";
$MESSAGE .= $DATA;

#
# Send to Xymon server or stdout if run interactively.
#
if (defined($ENV{XYMON})) {
	open(XYMON, "| $ENV{XYMON} $ENV{XYMSRV} @") || die "$!";
	select(XYMON);
} else {
	print "*** Not invoked by Xymon; spewing to stdout ***\n\n";
}
print $MESSAGE;
close(XYMON);

exit;
