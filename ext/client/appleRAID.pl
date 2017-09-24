#!/usr/bin/perl
#
# appleRAID - appleRAID volume test
#
# Jason White <jdwhite@menelos.com>
#
=begin License

The MIT License (MIT)

Copyright (c) 2016 Jason White <jdwhite@menelos.com>

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
# # appleRAID
# [appleRAID]
#         ENABLED
#         ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
#         CMD $XYMONCLIENTHOME/ext/appleRAID
#         LOGFILE $XYMONCLIENTHOME/logs/raidframe.log
#         INTERVAL 5m
#
$::TEST	= 'appleRAID';
#
#close(STDERR);

## Globals ##
$::condition = "green";
$::DATA = "";

open(DISKUTIL, "diskutil ar list |") || die "$!";
while(<DISKUTIL>) {
	my($current_condition) = "";

	if (/^Status:\s+(\S+)/io) {
		# RAIDset Status
		my $devstate = $1;
		if ($devstate eq "Online") {
			$current_condition = "green";
		}
		elsif ($devstate eq "Degraded") {
			$current_condition = "yellow";
		}
		elsif ($devstate eq "Offline?") {
			$current_condition = "red";
		}
		else {
			# What state is this?
			$current_condition = "yellow";
		}
	}
	elsif (/^[\d\-]\s+(\S+)\s+[0-9ABCDEF\-]{36}\s+(\d+)%/o) {
		# Rebuilding status
		my $percent = $3;
		if ($percent != 100) {
			$current_condition = "yellow";
		}
		else {
			$current_condition = "green";
		}
	}
	elsif (/^(\d|\-)\s+(\S+)\s+[0-9ABCDEF\-]{36}\s+(\S+)/o) {
		# Non-Rebuilding status
		my $dev_status = $3;
		if ($parity ne "Online") {
			$current_condition = "green";
		}
		elsif ($parity ne "Missing/Damaged") {
			$current_condition = "red";
		}
		else {
			# What state is this?
			$current_condition = "yellow";
		}
	}

	if ($current_condition ne "") {
		$DATA .= "&${current_condition}";
	} else {
		$DATA .= "&nbsp;&nbsp;";
	}
	$DATA .= $_;

	if ($current_condition eq "red") {
		$::condition = $current_condition;
	}
	elsif ($current_condition eq "yellow" && $::condition eq "green") {
		$::condition = $current_condition;
	}
}
close(DISKUTIL);

##
## Generate status report
##

$STATUS = "$::condition $::TEST ";
$STATUS .= ($::condition eq "green") ? "OK" : "appleRAID Problem Detected";

$DATE = scalar(localtime(time));

$LINE = "status $ENV{MACHINE}.${::TEST} $STATUS $DATE\n\n";
$LINE .= "$DATA";

#
# Send to Xymon or to stdout if run interactively.
#
if (defined($ENV{XYMON})) {
	system("$ENV{XYMON} $ENV{XYMSRV} \"$LINE\"");
} else {
	print "*** Not invoked by Xymon; spewing to stdout ***\n\n";
	print("$ENV{XYMON} $ENV{XYMSRV} \"$LINE\"");
}

exit;

__END__

AppleRAID sets (1 found)
===============================================================================
Name:                 Toybox HDD
Unique ID:            69777530-378B-4E5E-9CF4-E9125AC23A49
Type:                 Mirror
Status:               Online
Size:                 3.0 TB (3000248991744 Bytes)
Rebuild:              automatic
Device Node:          disk10
-------------------------------------------------------------------------------
#  DevNode   UUID                                  Status     Size
-------------------------------------------------------------------------------
0  disk3s2   0926EBB8-4F4A-4F13-974C-C49CBC625BCD  Online     3000248991744
1  disk4s2   14CE0E85-3EBF-4730-9911-DD57DBD9CE00  Online     3000248991744
===============================================================================


AppleRAID sets (1 found)
===============================================================================
Name:                 fud
Unique ID:            E28A6457-D197-4C0A-A5A5-BA62F970D477
Type:                 Mirror
Status:               Degraded
Size:                 199.7 GB (199705657344 Bytes)
Rebuild:              automatic
Device Node:          disk12
-------------------------------------------------------------------------------
#  DevNode   UUID                                  Status     Size
-------------------------------------------------------------------------------
0  disk10s2  188034CC-58C4-4E8A-B419-30500A13A129  Online     199705657344
-  -none-    E359E660-2E69-4F67-B2DF-4FE4127B4383  Missing/Damaged
===============================================================================

