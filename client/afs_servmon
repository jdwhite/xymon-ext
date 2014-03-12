#!/usr/pkg/bin/perl
#
# afs_servmon - monitor afs server procs and status
#
# Jason White <jdwhite@menelos.com>
#
#  8-Jan-2014  jdwhite	Initial version.
#  2-Feb-2014  jdwhite	Cleanup.
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
#   # AFS Service Monitor
#   [afs-servmon]
#           ENABLED
#           ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
#           CMD $XYMONCLIENTHOME/ext/afs_servmon
#           LOGFILE $XYMONCLIENTHOME/logs/afs_servmon.log
#           INTERVAL 5m
#
$::BOS     = '/usr/pkg/bin/bos';
$::RXDEBUG = '/usr/pkg/sbin/rxdebug';

# ::TESTNAME - the title of the test column.
$::TESTNAME	= 'afs';

# ::MACHINE/DOTS - host this test is reporting for as defined in hosts.cfg.
#$::MACHINE    = "some,machine,domain,com"; # If reporting for another host.
$::MACHINE     = $ENV{MACHINE};
$::MACHINEDOTS = $ENV{MACHINEDOTS};

# Points at which waiting call count triggers particular status.
$::red_calls_waiting    = 50;
$::yellow_calls_waiting = 8;

# ::COLOR - the canonical test color.
$::COLOR = "clear";

# ::RXD_DATA - rxdebug diagnostic data
# ::SERV_DATA - 'bos status' diagnostic data
$::RXD_DATA	= "";
$::SERV_DATA	= "";

# ::HAVE_BOS/RXDATA - indicates whether command returned output.
#    If true, performs processing of collected data.
$::HAVE_RXDATA  = 0;
$::HAVE_BOSDATA = 0;

# ::PRIORITY - the relative weight of test colors, used for determining
#       when to update $::COLOR while evaluating test criterion.
%::PRIORITY = (
	"red"    => 6,
	"yellow" => 5,
	"green"  => 4,
	"blue"   => 1,
	"clear"  => 1
);

#=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

##
## Check server status.
##
open(BOS, "${::BOS} status -noauth -local -server localhost |") || do {
	$::SERV_DATA = "ERROR INVOKING 'bos status': $! &red\n";
	$::COLOR = "red";
};
#close(BOS);

%::instance_status = ();
while(<BOS>) {
	$::HAVE_BOSDATA = 1;
	my($instance) = "";
	my($line_color) = "";

	if (/^Instance (\S+),/) {
		my $instance = $1;
		#print "DEBUG: instance='${instance}'\n";
		if (/currently running normally\.\s*$/io) {
			$line_color = "green";
		}
		elsif (/, disabled, currently shutdown\./io) {
			$line_color = "green";
		}
		else {
			$line_color = "red";
		}

		$::instance_status{$instance} = $line_color;
	}
	elsif (/^\s*Auxiliary status is: (.+)$/io) {
		my $aux_status = $1;
		if ($aux_status =~ /file server running/io) {
			$line_color = "green";
		}
		elsif ($aux_status =~ /salvaging file system/io) {
			$line_color = "yellow";
		}
		else {
			$line_color = "red";
		}
	}
	elsif (/failed to contact host\'s bosserver/io) {
		$line_color = "yellow";
	} 

	chomp;
	$::SERV_DATA .= $_;

	if ($line_color ne "") {
		$::SERV_DATA .= " \&${line_color}\n";

		if ($::PRIORITY{$line_color} > $PRIORITY{$::COLOR}) {
			$::COLOR = $line_color;
		}
	}
}

if ($::HAVE_BOSDATA != 1) {
	$::SERV_DATA .= "ERROR: BOS STATUS RETURNED NO DATA &red\n";
	$::COLOR = "red";
}

#
# Check for calls awaiting a thread.
#
open(RXD, "$::RXDEBUG localhost 7000 -noconn -rxstats |") || do {
	$::RXD_DATA .= "UNABLE TO GET RXDEBUG DATA: $! &red\n";
	$::COLOR = "red";
};
$rxd_lines_read = 0;
while(<RXD>) {
	if (/Free packets: (\d+).*?, packet reclaims: \d+, calls: (\d+)/io) {
		$::HAVE_RXDATA = 1;
		$rxd_lines_read++;
		$free_packets = $1;
		$calls = $2;
	}
	if (/(\d+) calls waiting for a thread/io) {
		$rxd_lines_read++;
		$calls_waiting = $1;
	}
	if (/(\d+) threads are idle/io) {
		$rxd_lines_read++;
		$threads_idle = $1;
	}
	if (/rx stats: free packets \d+, allocs (\d+)/io) {
		$rxd_lines_read++;
		$allocs = $1;
	}
	if (/packets read: data \d+ ack \d+ busy (\d+) abort (\d+) ackall (\d+) challenge (\d+) response (\d+)/io) {
		$rxd_lines_read++;
		$read_busy = $1;
		$read_abort = $2;
		$read_ackall = $3;
		$read_challenge = $4;
		$read_response = $5;
	}
	if (/other read counters: data (\d+), ack (\d+), dup (\d+),? spurious (\d+)/io) {   
		$rxd_lines_read++;
		$read_data = $1;
		$read_ack = $2;
		$read_dup = $3;
		$read_spurious = $4;
	}
	if (/packets sent: data \d+ ack \d+ busy (\d+) abort (\d+) ackall (\d+) challenge (\d+) response (\d+)/io) {
		$rxd_lines_read++;
		$sent_busy = $1;
		$sent_abort = $2;
		$sent_ackall = $3;
		$sent_challenge = $4;
		$sent_response = $5;
	}
	if (/other send counters: ack (\d+), data (\d+)[^,]*, resends (\d+),/io) {
		$rxd_lines_read++;
		$sent_ack = $1;
		$sent_data = $2;
		$sent_resent = $3;
	}
	if (/(\d+) server connections, (\d+) client connections, (\d+) peer structs, (\d+) call structs, (\d+) free call structs/io) {
		$rxd_lines_read++;
		$server_conns = $1;
 		$client_conns = $2;
		$peer_structs = $3;
		$call_structs = $4;
		$free_calls = $5;
	}
	if (/noPackets (\d+)/io) {
		$rxd_lines_read++;
		$no_packets=$1;
	}
}
close(RXD);

if ($::HAVE_RXDATA == 1) {
	$calls_waiting_color = "clear";

	if ($calls_waiting !~ /^\s*$/o) {
		if ($calls_waiting < $::yellow_calls_waiting) {
			$calls_waiting_color = "green";
		}
		elsif ($calls_waiting >= $::yellow_calls_waiting) {
			$calls_waiting_color = "yellow";
		}
		elsif ($calls_waiting >= $::red_calls_waiting) {
			$calls_waiting_color = "red";
		}
	}
	else {
		$calls_waiting = "??";
		$calls_waiting_color = "yellow";
	}

	$calls_waiting_status = "calls waiting: $calls_waiting".
				" \&${calls_waiting_color}";

	if ($::PRIORITY{$calls_waiting_color} > $PRIORITY{$::COLOR}) {
		$::COLOR = $calls_waiting_color;
	}

	$RXD_DATA .= "free packets: $free_packets\n".
		"$calls_waiting_status\n".
		"threads idle: $threads_idle\n".
		"server connections: $server_conns\n".
		"client connections: $client_conns\n".
		"peer structs: $peer_structs\n".
		"call structs: $call_structs\n".
		"free calls: $free_calls\n".
		"packet allocation failures: $no_packets\n".
		"calls: $calls\n".
		"allocs: $allocs\n".
		"read data: $read_data\n".
		"read ack: $read_ack\n".
		"read dup: $read_dup\n".
		"read spurious: $read_spurious\n".
		"read busy: $read_busy\n".
		"read abort: $read_abort\n".
		"read ackall: $read_ackall\n".
		"read challenge: $read_challenge\n".
		"read response: $read_response\n".
		"sent data: $sent_data\n".
		"sent resent: $sent_resent\n".
		"sent ack: $sent_ack\n".
		"sent busy: $sent_busy\n".
		"sent abort: $sent_abort\n".
		"sent ackall: $sent_ackall\n".
		"sent challenge: $sent_challenge\n".
		"sent response: $sent_response\n";

	if ($rxd_lines_read != 10) {
		print "NOTE: Matched $rxd_lines_read lines, instead of 10\n";
	}
}
else {
	$RXD_DATA .= "ERROR: RXDEBUG RETURNED NO DATA &red\n";
	if ($instance_status{"fs"} eq "green") {
		$::COLOR = "yellow";
	}
	else {
		$::COLOR = "yellow";
	}
}

##
## Generate status report
##

# STATUS - Canonical status of test and its lifetime: status[+LIFETIME]
#$STATUS = "status+25h ${::MACHINE}.${::TESTNAME} ${::COLOR}";
$STATUS = "status ${::MACHINE}.${::TESTNAME} ${::COLOR}";

# SUMMARY - datestamp and summary of the test.
$SUMMARY = scalar(localtime(time))." - ${::TESTNAME}: ";
$SUMMARY .= ($::COLOR eq "green") ? "OK" : "NOT OK";

$MESSAGE = "${STATUS} ${SUMMARY}\n\n${::RXD_DATA}\n${::SERV_DATA}";

##
## Send to Xymon or to stdout if run interactively.
##
if (defined($ENV{XYMON})) {
	# "at" sign as argument means "read message data from stdin".
	# DON'T USE A DASH AS THE xymon USAGE MESSAGE SHOWS ELSE ONLY
	# THE SUMMARY INFORMATION IS DISPLAYED AND NONE OF $::DATA.
	# THE MANPAGE USAGE OF "@" IS CORRECT.
	open(XYMON, "| $ENV{XYMON} $ENV{XYMSRV} @") || do {
		print "Error invoking $ENV{XYMON} $ENV{XYMSRV} @ - $!";
		exit;
	};
	select(XYMON);
}
else {
        print STDERR "*** Not invoked by Xymon; spewing to stdout ***\n\n";
}

print $MESSAGE;
close(XYMON);

exit;

__DATA__
opus:/home/jdwhite# bos status localhost -local
Instance buserver, temporarily disabled, stopped for too many errors, 
currently shutdown.
Instance ptserver, temporarily disabled, stopped for too many errors, 
currently shutdown.
Instance vlserver, temporarily disabled, stopped for too many errors, 
currently shutdown.
Instance fs, currently running normally.
    Auxiliary status is: file server running.


opus:/usr/pkg/etc/xymon# bos status localhost -local
Instance buserver, currently running normally.
Instance ptserver, currently running normally.
Instance vlserver, currently running normally.
Instance fs, currently running normally.
    Auxiliary status is: file server running.
