#!/usr/pkg/bin/perl
#
# wins - Xymon server-side WINS resolver test
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
# This test uses Samba's nmblookup command to query WINS servers.
#
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# 1) Install this file in $XYMONHOME/ext/
#
# 2) Create $XYMONHOME/etc/tasks.d/wins with this block:
#    -or-
#    Modify $XYMONHOME/etc/tasks.cfg and add this block:
#
# [wins]
# 	ENVFILE $XYMONHOME/etc/xymonserver.cfg
# 	CMD $XYMONHOME/ext/wins
# 	LOGFILE $XYMONSERVERLOGS/ext/wins.log
#	INTERVAL 5m
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Path to Samba's nmblookup.
$::NMBLOOKUP = '/usr/pkg/bin/nmblookup';

# Xymon Files/Programs
$Xymon::XYMONGREP = "$ENV{XYMONHOME}/bin/xymongrep";

%Xymon::STATUSCOLOR_PRIORITY = (
	'red'    => 4,
	'yellow' => 3,
	'green'  => 2,
	'clear'  => 1
);

$::HOSTTAG = 'wins';
#-----------------------------------------------------------------------------

#
# Define the queries to perform and their expected IP address response.
# format: 'query' => 'expected response'
#
%::test_hosts = (
	'windc1' => '129.186.6.1',
	'windc3' => '129.186.78.28',
	'windc4' => '129.186.124.249',
	'windc5' => '129.186.88.245'
);

##
## Start of Test
##

#
# Scan hosts.cfg for 'wins' tag.
#
# Note: while Perl is perfectly capable of scanning a file and picking 
# out keywords, there's no reason to reinvent the wheel. Plus, xymongrep 
# supports additional options which makes it even more pointless to 
# reimplement in Perl.
#
open(XYMONGREP, "$Xymon::XYMONGREP wins |") || die "$!";
while(<XYMONGREP>) {
	next if /^#/o;  # Skip comments.
	chomp;
	my($ipaddr, $host, $flags) = split(/\s+/, $_, 3);
	#print "${ip_addr}:${host}:${flags}\n";
	&wins_check($ipaddr, $host);
}
close(XYMONGREP);

exit;

sub
wins_check
{
	#
	# Query each host.
	#
	my($MACHINEADDR) = shift(@_);
	my($MACHINEDOTS) = shift(@_);

	my($TESTNAME) = $::HOSTTAG;	
	my($MACHINE) = $MACHINEDOTS;
	$MACHINE =~ s/\./\,/go;
	my($DIAGINFO) = "";

	my($hosts) = join(" ", sort keys %::test_hosts);

	$Xymon::STATUS_COLOR = "clear";

	open(NMBLOOKUP, "$::NMBLOOKUP -U $MACHINEADDR -R $hosts |") || die "$!";
	while(<NMBLOOKUP>) {
		#print "debug:=>$_";
		next if /^\s*$/o;
		chomp;
		my($LINECOLOR) = "";
		if (/^name_query failed to find name/io) {
			$LINECOLOR = "red";
		}
		elsif (/^(\d+\.\d+\.\d+\.\d+)\s(.+?)\</i) {
			my($ip, $hostresp) = ($1, $2);
			#print "DEBUG: ip=$ip, hostresp=$hostresp\n";

			if ($::test_hosts{$hostresp} eq $ip) {
				$LINECOLOR = "green";
			} else {
				$DIAGINFO .= "MISMATCH! ".
					"expected=$::test_hosts{$hostresp}, ".
					"received=";
				$LINECOLOR = "red";
			}
		}

		if (/^querying (\S+)/) {
			s/querying (\S+) on \d+\.\d+\.\d+\.\d+/Query: $1 => /;
		}

		$DIAGINFO .= $_;
		if ($LINECOLOR ne "") {
			$DIAGINFO .= " &${LINECOLOR}";
			&Xymon::set_testcolor($LINECOLOR);
		}

		if (! /^Query: /io) {
			$DIAGINFO .= "\n";
		}
	}
	close(NMBLOOKUP);

	#
	# Generate message.
	#
	my($STATUS_SUMMARY) = (&Xymon::get_testcolor() eq "green") ?
	                      "OK" : "NOT OK";
	my($LIFETIME) = "";
	my($GROUP) = "";
	my($COLOR) = &Xymon::get_testcolor;

	my($MESSAGE) = sprintf("status%s%s %s.%s %s %s - %s: %s\n\n%s",
	               $LIFETIME, $GROUP, $MACHINE, $TESTNAME, $COLOR,
	               scalar(localtime(time)), $TESTNAME, $STATUS_SUMMARY,
	               $DIAGINFO);

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
		print STDERR "*** Not invoked by Xymon; sending to stdout ***\n\n";
	}

	print $MESSAGE;
	close(XYMON);
}

sub Xymon::set_testcolor
#
# Set the canonical test color. Returns the canonical test color.
#
{
	my($new_testcolor) = shift(@_);

	if (! defined($Xymon::STATUSCOLOR_PRIORITY{$new_testcolor})) {
		return &Xymon::get_testcolor;
	}

	if ($Xymon::STATUSCOLOR_PRIORITY{$Xymon::STATUS_COLOR} <
	  $Xymon::STATUSCOLOR_PRIORITY{$new_testcolor}) {
		$Xymon::STATUS_COLOR = $new_testcolor;
	}

	return &Xymon::get_testcolor;
}

sub Xymon::get_testcolor
#
# Returns the canonical test color.
#
{
	return $Xymon::STATUS_COLOR;
}
