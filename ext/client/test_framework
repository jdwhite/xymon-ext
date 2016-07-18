#!/usr/bin/env perl
#
# test_framework - a framework for creating Xymon tests
#
# Jason White <jdwhite@menelos.com>
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
# A note on the Xymon namespace usage.
# ====================================
# I started using the "Xymon" package namespace here as a prelude to putting 
# those package vars/functions in their own module. When that happens, 
# only the function calls will be exported and all package variables will 
# remain private. Coming in a future release.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Install in $XYMONCLIENTHOME/client/ext/.
# Modify $XYMONCLIENTHOME/etc/clientlaunch.cfg and add this block:
#
# # ##Test Title Here##
# [##TESTNAME##]
# 	ENABLED
# 	ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
# 	CMD $XYMONCLIENTHOME/ext/##TESTNAME##
# 	LOGFILE $XYMONCLIENTHOME/logs/##TESTNAME##.log
# 	INTERVAL 1h
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#

use strict;
#use warnings;
use Data::Dumper;
use English; # $PROGRAM_NAME

#
# == Initialize Xymon Namespace ==
# Call this before using any Xymon:: functions.
&Xymon::init_xymon_namespace;

#
# Initialize some defaults.
#
&Xymon::set_testname("##TESTNAME##");

$main::message = "";

#
# == Run Tests ==
#
# Here is where you'd perform the testing, adding to $main::message
#
# * To set the overall, canonical, test color:
#      &Xymon::set_testcolor("##COLOR##");
#   where ##COLOR## is one of green, yellow, red, or clear.
#
# * To set the test summary string:
#      &Xymon::set_summary("host unreachable");
#
# * To set the name of the test (column):
#      &Xymon::set_testname("footest");
#
# * To set the name of the machine we report as:
#      &Xymon::set_machinename("machine1,example,com");
#
# Note that the preceeding "setter" subroutines also have
# corresponding "getter" subroutines that return their current value.
#

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

&Xymon::send_status(
	"message"  => $main::message,
);

exit;


#============================================================================
#
# Xymon package starts here
#
#============================================================================
package Xymon;

sub init_xymon_namespace
#
# Initialize variables in the Xymon namespace
#
{
	%Xymon::COLOR_PRIORITY = (
		'red'    => 4,
		'yellow' => 3,
		'green'  => 2,
		'clear'  => 1
	);

	$Xymon::TESTNAME        = "default-test";
	$Xymon::MACHINE         = $ENV{MACHINE};
	$Xymon::SUMMARY         = "";
	$Xymon::COLOR           = "clear";

	1;
}

sub send_status
#
# Send a status update to the Xymon display server.
#
# usage: send_status(%validargs)
#	
{
	#
	# Valid arguments (named same as xymon(1) manpage).
	#
	my %validargs = (
		"lifetime"  => 1,
		"group"     => 1,
		"hostname"  => 1,
		"testname"  => 1,
		"color"     => 1,
		"message"   => 1,
		"summary"   => 1,
	);

	my %args = @_;

	#
	# Validate passed arguments; warn if invalid.
	#
	foreach my $key (keys %args) {
		if (! defined($validargs{$key})) {
			print STDERR "${main::PROGRAM_NAME}: in send_staus(): ".
			             "invalid argument $key\n";
		}
	}

	my($LIFETIME)  = exists $args{lifetime}
	                 ? "+$args{lifetime}" : "";
	my($GROUP)     = exists $args{group}
	                 ? "/group:$args{group}" : "";
	my($TESTNAME)  = exists $args{testname}
	                 ? $args{testname}
	                 : &Xymon::get_testname;
	my($COLOR)     = exists $args{color}
	                 ? $args{color}
	                 : &Xymon::get_testcolor;
	my($MACHINE)   = exists $args{hostname}
	                 ? $args{hostname}
	                 : &Xymon::get_machinename;
	my($DIAGINFO)  = exists $args{message}
	                 ? $args{message}
	                 : "";
	my($SUMMARY)   = exists $args{summary}
	                 ? $args{summary}
	                 : &Xymon::get_summary;

	my($MESSAGE)   = sprintf("status%s%s %s.%s %s %s - %s: %s\n%s",
		$LIFETIME, $GROUP, $MACHINE, $TESTNAME, $COLOR,
		scalar(localtime(time)), $TESTNAME, $SUMMARY, $DIAGINFO);

	#
	# Send to Xymon or to stdout if run interactively.
	#
	if (defined($ENV{XYMON})) {
		# "at" sign as argument means "read message data from 
		# stdin". DON'T USE A DASH AS THE xymon USAGE MESSAGE 
		# SHOWS ELSE ONLY THE SUMMARY INFORMATION IS DISPLAYED 
		# AND NONE OF ${DATA}. THE MANPAGE USAGE OF "@" IS 
		# CORRECT.

		my($cmd) = "$ENV{XYMON} $ENV{XYMSRV} @";
		open(XYMON, "| ${cmd}") || do {
			print "Error invoking ${cmd} - $!";
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

sub set_testcolor
#
# Set the canonical test color. Returns the canonical test color.
#
{
	my($new_testcolor) = shift(@_);

	if (! defined($Xymon::COLOR_PRIORITY{$new_testcolor})) {
		return &Xymon::get_testcolor;
	}	
	
	if ($Xymon::COLOR_PRIORITY{$Xymon::COLOR} <
	    $Xymon::COLOR_PRIORITY{$new_testcolor}) {
		$Xymon::COLOR = $new_testcolor;
	}

	return &Xymon::get_testcolor;
}

sub get_testcolor
#
# Returns the canonical test color.
#
{
	return $Xymon::COLOR;
}	    

sub set_summary
#
# Set the status summary text.
#
{
	$Xymon::SUMMARY = shift(@_);
}

sub get_summary
#
# Returns the status summary color.
#
{
	my($SUMMARY) = $Xymon::SUMMARY;

	if ($SUMMARY =~ /^\s*$/o) {
		if ($Xymon::COLOR_PRIORITY{$Xymon::COLOR} >
		    $Xymon::COLOR_PRIORITY{"green"}) {
			$SUMMARY = "NOT OK";
		}
		else {
			$SUMMARY = "OK";
		}
	}

	return $SUMMARY;
}

sub set_testname
#
# Set the test name.
#
{
	$Xymon::TESTNAME = shift(@_);
}

sub get_testname
#
# Returns the test name.
#
{
	return $Xymon::TESTNAME;
}

sub set_machinename
#
# Set the test name.
#
{
	$Xymon::MACHINE = shift(@_);
}

sub get_machinename
#
# Returns the test name.
#
{
	my($MACHINE) = $Xymon::MACHINE;
	if ($MACHINE =~ /^\s*$/) { $MACHINE = "dummy,example,com"; }

	return $MACHINE;
}
