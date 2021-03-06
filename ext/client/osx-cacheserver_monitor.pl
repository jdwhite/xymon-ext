#!/usr/bin/env perl
#
# osx-cacheserver_monitor - report OS X Server caching server status and usage.
#
# Jason White <jdwhite@menelos.com>
# 8-Mar-2014 (first release)
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
# Install in $XYMONCLIENTHOME/client/ext/.
# Modify $XYMONCLIENTHOME/etc/clientlaunch.cfg and add this block:
#
# # OS X Server caching server
# [osx_cacheserver_mon]
#	  ENABLED
#	  ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
#	  CMD $XYMONCLIENTHOME/ext/osx-cacheserver_monitor
#	  LOGFILE $XYMONCLIENTHOME/logs/osx-cacheserver_monitor.log
#	  INTERVAL 5m
#
# serveradmin must run as root. Modify /etc/sudoers as follows:
#
#   * Add the following line to the bottom of the config file to allow
#     user xymon to execute the serveradmin command without a password:
#
#        xymon   ALL= NOPASSWD: /Applications/Server.app/Contents/ServerRoot/usr/sbin/serveradmin,/usr/bin/sqlite3
#

use strict;
use warnings;
use Number::Format qw(:subs :vars);

## Globals ##

#
# $main::base tells the Number::Format module how to convert byte values.
# If you want to use the traditional SI units (kilo, mega, giga -- 
# powers of 2) representation of a kilobyte as 1024 bytes, set to 1024.
# If you want to use what Apple and drive manufactures use to inflate 
# their numbers, set to 1000.
#
#$main::base = 1024; # Author's preference.
$main::base = 1000;  # What Apple uses.

$main::TESTNAME = 'cacheserver';
$main::COLOR    = "clear"; # uncertain by default
$main::DATA     = "";
$main::MACHINE  = $ENV{MACHINE};

$main::SERVERADMIN =
	"/Applications/Server.app/Contents/ServerRoot/usr/sbin/serveradmin";

%main::stats = ();
%main::settings = ();
@main::cachedetails = ();
@main::peerdetails = ();

# Timestamp for logfile.
#print scalar(localtime(time)),"\n";

my $megafmt = new Number::Format(
	-thousands_sep => '', # rrd doesn't like separators.
	#-MEGA_SUFFIX  => ' M'
);

#
# Get caching server settings.
#
open(SETTINGS,"sudo ${main::SERVERADMIN} settings caching |") || do {
	$main::COLOR = "red";
	$main::status = "Error getting cache settings - $!";
};
while(<SETTINGS>) {
	s/^caching://;
	chomp;

	my($key, $val) = split(/ = /, $_);
	$val =~ s/\"//go;

	$main::settings{$key} = $val;
}
close(SETTINGS);

#
# Fetch cached item count.
#
$main::DBPath = "$main::settings{DataPath}/AssetInfo.db";
open(DB, "sudo sqlite3 $main::DBPath 'select count(*) from ZASSET' |");
chomp($main::stats{CachedItemCount} = <DB>);
close(DB);

#
# Read status information and process.
#
my(@details);
open(STATUS,"sudo ${main::SERVERADMIN} fullstatus caching |") || do {
	$main::COLOR = "red";
	$main::status = "Error getting cache status - $!";
};

while(<STATUS>) {
	s/^caching://;
	chomp;
	
	if (/^CacheDetails:_array_index:(\d+):(.+)\s=\s(.+)$/io) {
		#
		# These are the caching details broken down by data type.
		#
		my($element, $key, $val) = ($1, $2, $3);
		$val =~ s/\"//go;
		$main::cachedetails[$element]{$key} = $val;
	}
	elsif (/^Peers:_array_index:(\d+):(.+)\s=\s(.+)$/io) {
		#
		# These are the caching details broken down by data type.
		#
		my($element, $key, $val) = ($1, $2, $3);
		$val =~ s/\"//go;
		$main::peerdetails[$element]{$key} = $val;
	}
	else {
		#
		# Metadata regarding the cache (status, size, utilization, etc.)
		#
		my($key, $val) = split(/ = /, $_);
		$val =~ s/\"//go;
		$val =~ s/_empty_array/none/;
		$main::stats{$key} = $val;
	}
}
close(STATUS);

#
# Check overall state.
#
if ($main::stats{state} eq "RUNNING") {
	$main::COLOR = "green";
	$main::status = $main::stats{state};
}
elsif ($main::stats{state} eq "STOPPED") {
	# A stopped caching server doesn't provide cache size info.
	$main::COLOR = "yellow";
	$main::status = $main::stats{state};
}
else {
	$main::COLOR = "red"; # unknown state
	$main::status = $main::stats{state};
}

#
# Status data.
#
foreach my $field (sort keys %main::stats) {
	$main::DATA .= sprintf("%25s: ",
		spacer($field));

	if ($field =~ /Bytes/) {
		$main::DATA .= sprintf("%s",
			format_bytes($main::stats{$field},
			    base => $main::base));
	}
	elsif ($field =~ /Cache(Free|Limit|Used)/) {
		$main::DATA .= sprintf("%s",
			format_bytes($main::stats{$field},
			    base => $main::base));

		if ($field eq "CacheUsed") {
			my($percent_used) = 0;
			if ($main::stats{CacheLimit} > 0) {
				$percent_used = ($main::stats{CacheUsed} /
				                 $main::stats{CacheLimit}) * 100;
			}

			$main::DATA .= sprintf(" (%0.1f%%)", $percent_used);
		}
	}
	else {
		$main::DATA .= sprintf("%s",
			 $main::stats{$field});
	}

	if ($field eq "Port") {
		$main::DATA .=
		    ($main::settings{Port} == 0) ? " (dynamic)" : " (static)";
	}

	if ($field =~ /TotalBytesReturned/) {
		my($percent_efficient) = 0;
		if ($main::stats{TotalBytesReturned} > 0) {
			$percent_efficient = (
			    100 - 
			    ($main::stats{"TotalBytesRequested"} /
			    $main::stats{TotalBytesReturned})
			    * 100
			);
		}
			
		$main::DATA .= sprintf(" (%.1f%% efficiency)", $percent_efficient);
	}
	
	if ($field =~ /RegistrationStatus/) {
		my(@regstatus) = ("NOT YET REGISTERED", "Registered");
		$main::DATA .= sprintf(" (%s)",
			$regstatus[$main::stats{$field}]);
	}
	
	$main::DATA .= "\n";
}

#
# Peer info.
#
foreach my $hash (@main::peerdetails) {
	$main::DATA .= "\n";
	foreach my $key (sort keys %$hash) {
		$main::DATA .= sprintf("%25s: %s\n", 
			"Peer $key", $hash->{$key});
	}
}

#
# Display usage by type.
#
$main::DATA .= "\n";
foreach my $hash (@main::cachedetails) {
	# I chose to display these values in megabytes for graphing purposes.
	# If you're not going to be graphing this data, you may wish to 
	# modify the format_bytes call below to match the others.
	$main::DATA .= sprintf("%25s: %6s\n", 
		$hash->{LocalizedType},
		$megafmt->format_bytes($hash->{BytesUsed},
			base => $main::base,
			unit => 'M', precision => 0));
}

##
## Generate status report.
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

sub spacer
#
# Add spaces before a series of one or more capitalized letters in a string.
# I.E. "TotalBytesRequested" => "Total Bytes Requested".
#
{
        my($string) = shift(@_);
        $string =~ s/([^A-Z\s])([A-Z])/$1 $2/g;

        return $string;
}

__END__

# Server running normally.
caching:Active = yes
caching:state = "RUNNING"
caching:CacheUsed = 1812413411
caching:Port = 51332
caching:TotalBytesRequested = 0
caching:RegistrationStatus = 1
caching:CacheLimit = 78503358335
caching:CacheFree = 76690944924
caching:Peers = _empty_array
caching:TotalBytesFromPeers = 0
caching:StartupStatus = "OK"
caching:TotalBytesFromOrigin = 0
caching:CacheStatus = "OK"
caching:TotalBytesReturned = 0
caching:CacheDetails:_array_index:0:BytesUsed = 1583108743
caching:CacheDetails:_array_index:0:LocalizedType = "Mac Software"
caching:CacheDetails:_array_index:0:MediaType = "Mac Software"
caching:CacheDetails:_array_index:0:Language = "en"
caching:CacheDetails:_array_index:1:BytesUsed = 161476803
caching:CacheDetails:_array_index:1:LocalizedType = "iOS Software"
caching:CacheDetails:_array_index:1:MediaType = "iOS Software"
caching:CacheDetails:_array_index:1:Language = "en"
caching:CacheDetails:_array_index:2:BytesUsed = 1726668
caching:CacheDetails:_array_index:2:LocalizedType = "Books"
caching:CacheDetails:_array_index:2:MediaType = "Books"
caching:CacheDetails:_array_index:2:Language = "en"
caching:CacheDetails:_array_index:3:BytesUsed = 0
caching:CacheDetails:_array_index:3:LocalizedType = "Movies"
caching:CacheDetails:_array_index:3:MediaType = "Movies"
caching:CacheDetails:_array_index:3:Language = "en"
caching:CacheDetails:_array_index:4:BytesUsed = 0
caching:CacheDetails:_array_index:4:LocalizedType = "Music"
caching:CacheDetails:_array_index:4:MediaType = "Music"
caching:CacheDetails:_array_index:4:Language = "en"
caching:CacheDetails:_array_index:5:BytesUsed = 66101197
caching:CacheDetails:_array_index:5:LocalizedType = "Other"
caching:CacheDetails:_array_index:5:MediaType = "Other"
caching:CacheDetails:_array_index:5:Language = "en"


# Sever in stopped state.
caching:CacheStatus = "OK"
caching:CacheDetails:_array_index:0:BytesUsed = 1583108743
caching:CacheDetails:_array_index:0:LocalizedType = "Mac Apps"
caching:CacheDetails:_array_index:0:MediaType = "Mac Apps"
caching:CacheDetails:_array_index:0:Language = "en"
caching:CacheDetails:_array_index:1:BytesUsed = 161476803
caching:CacheDetails:_array_index:1:LocalizedType = "iOS Apps"
caching:CacheDetails:_array_index:1:MediaType = "iOS Apps"
caching:CacheDetails:_array_index:1:Language = "en"
caching:CacheDetails:_array_index:2:BytesUsed = 1726668
caching:CacheDetails:_array_index:2:LocalizedType = "Books"
caching:CacheDetails:_array_index:2:MediaType = "Books"
caching:CacheDetails:_array_index:2:Language = "en"
caching:CacheDetails:_array_index:3:BytesUsed = 0
caching:CacheDetails:_array_index:3:LocalizedType = "Movies"
caching:CacheDetails:_array_index:3:MediaType = "Movies"
caching:CacheDetails:_array_index:3:Language = "en"
caching:CacheDetails:_array_index:4:BytesUsed = 0
caching:CacheDetails:_array_index:4:LocalizedType = "Music"
caching:CacheDetails:_array_index:4:MediaType = "Music"
caching:CacheDetails:_array_index:4:Language = "en"
caching:CacheDetails:_array_index:5:BytesUsed = 66101197
caching:CacheDetails:_array_index:5:LocalizedType = "Other"
caching:CacheDetails:_array_index:5:MediaType = "Other"
caching:CacheDetails:_array_index:5:Language = "en"
caching:state = "STOPPED"
caching:CacheUsed = 1812413411
