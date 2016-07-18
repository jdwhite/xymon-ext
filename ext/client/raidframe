#!/usr/bin/perl
#
# raidframe - NetBSD raidframe test
#
# Jason White <jdwhite@menelos.com>
# 5-Jan-2014
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
# # Raidframe
# [raidframe]
#         ENABLED
#         ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
#         CMD $XYMONCLIENTHOME/ext/raidframe
#         LOGFILE $XYMONCLIENTHOME/logs/raidframe.log
#         INTERVAL 5m
#
# Modify /etc/sudoers as follows:
#
#  1) Comment out "Defaults    requiretty" since user xymon has no tty when
#     running this script.
#
#  2) Add the following line to the bottom of the config file to allow
#     user xymon to execute the raidctl command without a password:
#
#       xymon   ALL= NOPASSWD: /sbin/raidctl
#
$::SUDO		= '/usr/pkg/bin/sudo';
$::RAIDCTL	= '/sbin/raidctl';
$::TEST	= 'raidframe';
#
#close(STDERR);

## Globals ##
$::condition = "green";
@::devices = ();
$::DATA = "";

# Get list of raid devices.
open(IOSTAT, "iostat -x |") || die "iostat: $!";
while(<IOSTAT>) {
	next unless /^(raid\d+)/o;
	push(@devices, $1);
}
close(IOSTAT);

foreach my $device (@devices) {
	open(RAIDCTL, "${::SUDO} ${::RAIDCTL} -s $device |") || die "$!";
	while(<RAIDCTL>) {
		my($current_condition) = "";
		# Reconstructing spares sometimes have a null 
		# character as the raid level.
		s/\000//o; 

		if (/^\s+\/dev\/.+: (\S+)\s*$/o ||
		    /^\s+component\d+: (\S+)\s*$/o) {
			my $devstate = $1;
			if ($devstate eq "optimal" ||
			    $devstate eq "spare" ||
			    $devstate eq "spared" ||
			    $devstate eq "used_spare") {
				$current_condition = "green";
			}
			elsif ($devstate eq "reconstructing") {
				$current_condition = "yellow";
			}
			elsif ($devstate eq "failed") {
				$current_condition = "red";
			}
			else {
				$current_condition = "yellow";
			}
		}
		elsif (/^Parity status: (\S+)/o) {
			my $parity = $1;
			if ($parity ne "clean") {
				$current_condition = "red";
			}
			else {
				$current_condition = "green";
			}
		}
		elsif (/is (\d+)% complete\./o) {
			my $percent = $1;
			if ($percent != 100) {
				$current_condition = "yellow";
			}
			else {
				$current_condition = "green";
			}
		}

		chomp;
		$DATA .= "$_";
		if ($current_condition ne "") {
			$DATA .= " &${current_condition}";
		}
		$DATA .= "\n";

		if ($current_condition eq "red") {
			$::condition = $current_condition;
		}
		elsif ($current_condition eq "yellow" && $::condition eq "green") {
			$::condition = $current_condition;
		}
	}
	close(RAIDCTL);
}


##
## Generate status report
##

$STATUS = "$::condition $::TEST ";
$STATUS .= ($::condition eq "green") ? "OK" : "Raidframe Problem Detected";

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
