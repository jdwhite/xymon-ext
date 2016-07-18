#!/usr/bin/env perl
#
# audit - audit system for security related information and updates
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
# Supported Environments and Auditors
# ===================================
#
#   - pkgsrc: 'pkg_admin audit'
#   - RHEL/Fedora/CENTOS: yum with the yum-security plugin
#   - OS X: softwareupdate
#
# ToDo:
#   - Debian/Ubuntu-based systems: aptitude
#
# When the test is run, each auditor application is checked for and 
# invoked if it exists. This supports environments that use additional 
# package managers to supplement the base OS software.
#
# /var/xymon/audit/ok file
# ========================
# Audit will check /var/xymon/audit/ok for a list of packages/advisories 
# that will not trigger a non-green state. The format of the entries in this 
# file is detailed below by auditor. Entries should be free of leading and 
# trailing whitespace, but whitespace padding in between should be 
# preserved.
#
# pkg_admin (pkgsrc)
# ------------------
# The entire line from 'pkg_admin audit'; example (URL truncated):
#   Package links-2.8 has a remote-spoofing vulnerability, see http://...
#
# Note that 'pkg_admin fetch-pkg-vulnerabilities' must be run 
# periodically to update the package vulerability database. On NetBSD 
# systems this can be done automatically with a directive in 
# /etc/security.conf.  See the security.conf(1) man page for more 
# information. On other systems this can be run from cron (or 
# equivalent) on a periodic basis, generally daily.
#
# softwareupdate (Darwin)
# -----------------------
# The softwareupdate command returns output over two lines for each 
# available update. This test combines them into one line for 
# displaying. When selecting items to go in the ok file, use the output 
# the audit test displays, NOT the output from softwareupdate. Example:
#
#   JavaForOSX-1.0 - Java for OS X 2012-005 (1.0), 65288K [recommended]
#
# While the updates reported by 'softwareupdate' aren't strictly 
# security related in nature, the majority of them are. Given that these 
# updates are for base system software components, the author feels it 
# appropriate to include them in an audit test.
#
# yum with yum-security plugin
# ----------------------------
# Use the entire line from 'yum updateinfo security'; example:
#   RHSA-2014:0043 Moderate/Sec.  bind-32:9.8.2-0.23.rc1.el6_5.1.x86_64
#
# aptitude
# --------
# [not yet implemented]
#
# A note on the Xymon namespace usage.
# ====================================
# I started using the "Xymon" package namespace here as a prelude to 
# putting those package vars/functions in their own module. When 
# implmented, only the function calls will be exported and all package 
# variables will remain private. Coming in a future release.
#
# Additional Auditor-specific Installation Instructions
# =====================================================
# Systems using yum and running xymon as a non-privledged user will need use 
# sudo to elevate privledges when calling yum.
# 1) Place the following in sudoers or in a separate file in sudoers.d:
#
#      xymon   ALL= NOPASSWD: /usr/bin/yum
#
# 2) In sudoers, comment out "Defaults requiretty" since xymon has no tty when 
#    running this script.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Install in $XYMONCLIENTHOME/client/ext/.
# Modify $XYMONCLIENTHOME/etc/clientlaunch.cfg and add this block:
#
# # Software audit
# [audit]
# 	ENABLED
# 	ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
# 	CMD $XYMONCLIENTHOME/ext/audit
# 	LOGFILE $XYMONCLIENTHOME/logs/audit.log
# 	INTERVAL 1h
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#

use strict;
#use warnings;
#use Data::Dumper;
use English; # $PROGRAM_NAME

#
# Globals
# 
$main::TESTNAME = "audit";
$main::MACHINE  = $ENV{MACHINE};

$main::SUDO	= '/usr/bin/sudo';

# Location of file listing advisories which can be considered green.
$main::OKFILE = "/var/xymon/audit/ok";

%Xymon::STATUSCOLOR_PRIORITY = (
	'red'    => 4,
	'yellow' => 3,
	'green'  => 2,
	'clear'  => 1
);

$Xymon::STATUS_COLOR     = "clear";
$Xymon::STATUS_SUMMARY   = "";
#$Xymon::STATUS_DIAGINFO = "";
#$Xymon::STATUS_LIFETIME = "";
#$Xymon::STATUS_GROUP    = "";

$main::message = "";
$main::summary_info = "";

#
# Read contents of OK file; entries in this file will be flagged green.
#
open(OK, "$main::OKFILE");
while(<OK>) {
	next if /^\s*$/o;
	chomp;
	s/^\s+//;
	s/\s+$//;
	$main::ok_entries{$_} = 1;
}
close(OK);

#
# Run the audits.
#

# OS X softwareupdate
(-x "/usr/sbin/softwareupdate") && do {
	$main::message .= &audit_softwareupdate();
};

# yum
(-x "/usr/bin/yum")  && do {
	$main::message .= &audit_yum_security();
};

# pkgsrc's pkg_admin
(-x "/usr/pkg/sbin/pkg_admin") && do {
	$main::message .= &audit_pkgsrc();
};

#
# Report findings.
#
# Note send_status() takes a hash of arguments; it's like varargs for perl. :)
&Xymon::send_status(
	"message"  => $main::message,
	"lifetime" => "2h",
);

exit;

sub audit_softwareupdate
#
# Check for available software updates under OS X.
#
{
	my($updates);
	my($DIAGINFO);

	#
	# Collect update data.
	#
	#while(<DATA>) { ## DEBUG ##
	my($cmd) = "/usr/sbin/softwareupdate -l";
	open(AUDIT, "$cmd 2>&1 |") || do {
		$DIAGINFO .= "Error running '$cmd' - $!";
	};
	while(<AUDIT>) {
		$updates .= $_;
	}
	close(AUDIT);

	#
	# Analyze update data.
	#
	if ($updates =~ /^No new software available/iom)
	{
		&Xymon::set_testcolor("green");
		&Xymon::set_status_summary("no updates available");
		$DIAGINFO .= "\n&green OS X Software Updates: no updates available.\n";
	}
	elsif ($updates =~ /^Software Update found/iom)
	{
		$DIAGINFO .= "\nOS X System Software Updates Available\n".
		             "--------------------------------------\n";

		&Xymon::set_status_summary("updates available");

		while($updates =~ /^\s*\*\s*(.+)\n\s*(.+)\n/iogm) {
			my($linecolor);
			my($update) = $1;
			my($update_info) = $2;
			my($line) = "$update - $update_info";

			# If line exists in audit file, set condition green.
			if (exists $main::ok_entries{$line}) {
				$linecolor = "green";
			}
			else {
				$linecolor = "yellow";
			}
			&Xymon::set_testcolor($linecolor);
			$DIAGINFO .= "&${linecolor} $line\n";
		}
	}
	else
	{
		$DIAGINFO .= "&red Unexpected output from 'softwareupdate':\n$updates";
		&Xymon::set_testcolor("red");
	}

	return($DIAGINFO);
}

sub audit_pkgsrc
#
# Check for vulnerable pkgsrc packages.
#
{
	my($updates);
	my($DIAGINFO);

	# Vulnerabe packages will be flagged yellow by default unless
	# one of the strings below is found in the description.
	my($redflags) = "bypass|arbitrary|code-|corruption|manipulation".
	                "buffer-over|cross-site|".
	                "password-exposure|remote-|sensitive-|system-".
	                "unauthorized-";

	#
	# Collect vulnerability data.
	#
	my($cmd) = "/usr/pkg/sbin/pkg_admin -v audit";
	open(AUDIT, "$cmd 2>&1 |") || do {
		$DIAGINFO .= "&red Error running '$cmd' - $!";
	};
	while(<AUDIT>) {
		$updates .= $_;
	}
	close(AUDIT);

	#
	# Analyze vulnerability data.
	#
	if ($updates =~ /^No vulnerabilities found/iom) {
		&Xymon::set_testcolor("green");
		&Xymon::set_status_summary("no vulnerable packages found");
		$DIAGINFO .= "\n&green pkgsrc: no vulnerable packages found.\n";
	}
	else {
		$DIAGINFO .= "\nVulnerable pkgsrc Packages\n".
		             "--------------------------\n";

		while($updates =~ /(.+?)\n/iogm) {
			my($line) = $1;
			my($linecolor);
			#print "=>$line\n";next;

			&Xymon::set_status_summary("vulnerable packages found");
			# Check for "red flag" vulnerabilities.
			if ($line =~ /(${redflags})/i) {
				$linecolor = "red";
			}
			else {
				$linecolor = "yellow";
			}

			# If line exists in audit file, set condition green.
			if (exists $main::ok_entries{$line}) {
				$linecolor = "green";
			}

			# Convert URL to hyperlink.
			$line =~ s,see (http[s]?://.+)\s*$,<a href="$1">details</a>,i;

			$DIAGINFO .= "&${linecolor} $line\n";
			&Xymon::set_testcolor($linecolor);
		}
	}

	return($DIAGINFO);
}

sub audit_yum_security
#
# Check for security related updates using yum(1) and the yum-security 
# plugin.
#
{
	my($updates);
	my($DIAGINFO);
	my($linecolor);

	# Check for yum-security plug-in.
	my($have_security_plugin);
	my($cmd) = "/usr/bin/yum -h";
	open(YUM, "$cmd 2>&1 |") || do {
		$DIAGINFO .= "&red Error running '$cmd' - $!\n";
	};
	while(<YUM>) {
		if (/Loaded plugins:.*\ssecurity\s*/io) {
			$have_security_plugin = 1;
		}
	}
	close(YUM);

	if ($have_security_plugin != 1) {
		print STDERR "This program requires the yum-security plugin.\n".
		             "Try installing with 'yum install yum-plugin-security'\n";
		exit;
	}
	
	# yum updateinfo security
	# yum updateinfo list sec
	# yum updateinfo list cve
	# RHSA-2013:1582 Moderate/Sec.  python-libs-2.6.6-51.el6.x86_64

	#
	# Collect advisory data.
	#
	my(@update_list);
	#open(YUM, "yum updateinfo list cve 2>&1 |") || die "$!";
	#open(YUM, "yum updateinfo list bzs 2>&1 |") || die "$!";
	my($cmd) = "${main::SUDO} /usr/bin/yum updateinfo security";
	open(YUM, "$cmd 2>&1 |") || do {
		$DIAGINFO .= "&red Error running '$cmd' - $!\n";
	};
	while(<YUM>) {
		if (/^(.+ needed for security),/io) {
			my($updates)= $1;

			if ($updates =~ /No updates needed for security/i) {
				&Xymon::set_status_summary("no security updates needed");
				&Xymon::set_testcolor("green");
			}
		}
		elsif (/\s(Low|Moderate|Important)\/Sec.\s/io) {
			chomp;
			push(@update_list, $_);
		}
	}
	close(YUM);

	#
	# Analyze advisory data.
	#
	if (scalar(@update_list) > 0) {
		$DIAGINFO .= "\nSecurity Updates Available\n".
		             "--------------------------\n";
	} else {
		$DIAGINFO .= "\n&green yum-security: no updates needed.\n";
		&Xymon::set_testcolor("green");
	}
	foreach my $line (@update_list) {
		my($advisory, $severity, $package) = split(/\s+/, $line, 3);

		my $linecolor = "";
		if ($severity =~ /(Low|Moderate)\//io) {
			$linecolor = "yellow";
		}
		elsif ($severity =~ /Important\//io) {
			$linecolor = "red";
		}

		# If line exists in audit file, set condition green.
		if (exists $main::ok_entries{$line}) {
			$linecolor = "green";
		}

		# Convert advisory to hyperlink.
		if ($line =~ /^(RHSA\-\S+)/io) {
			# Red Hat Security Announcement
			my($advisory) = $1;
			$advisory =~ s/:/-/go;
			my($url) = "http://rhn.redhat.com/errata/${advisory}.html";
			$line =~ s,(RHSA\-\S+),<a href="${url}">$1</a>,i;
		}
		elsif ($line =~ /^(ELSA\-\S+)/io) {
			# Oracle Linux Security Announcement
			my($advisory) = $1;
			$advisory =~ s/:/-/go;
			my($url) = "http://linux.oracle.com/errata/${advisory}.html";
			$line =~ s,(ELSA\-\S+),<a href="${url}">$1</a>,i;
		}
		elsif ($line =~ /^\s*(CVE\-\S+)/io) {
			# Common Vulnerability and Exposures
			my($advisory) = $1;
			my($url) = "http://cve.mitre.org/cgi-bin/cvename.cgi?name=${advisory}";
			$line =~ s,\s(CVE\-\S+),<a href="${url}">$1</a>,i;
		}
		elsif ($line =~ /^\s*(\d+\S+)/io) {
			# Presumed bugzilla.
			my($advisory) = $1;
			my($url) = "https://bugzilla.redhat.com/show_bug.cgi?id=${advisory}";
			$line =~ s,\s(\d+\S+),<a href="${url}">Bugzilla $1</a>,i;
		}

		if ($linecolor ne "") {
			$DIAGINFO .= "&${linecolor} "
		}
		$DIAGINFO .= "$line\n";

		&Xymon::set_testcolor($linecolor);
	}

	return($DIAGINFO);
}

package Xymon;

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
	                 : $main::TESTNAME;
	my($COLOR)     = exists $args{color}
	                 ? $args{color}
	                 : &Xymon::get_testcolor;
	my($MACHINE)   = exists $args{hostname}
	                 ? $args{hostname}
	                 : $ENV{MACHINE};
	if ($MACHINE =~ /^\s*$/) { $MACHINE = "dummy,example,com"; }
	my($DIAGINFO)  = exists $args{message}
	                 ? $args{message}
	                 : "";

	my($STATUS_SUMMARY) = $Xymon::get_status_summary;

	if ($STATUS_SUMMARY =~ /^\s*$/o) {
		$STATUS_SUMMARY = (&Xymon::get_testcolor() eq "green") ?
			"OK" : "check results";
	}

	my($MESSAGE)   = sprintf("status%s%s %s.%s %s %s - %s: %s\n%s",
		$LIFETIME, $GROUP, $MACHINE, $TESTNAME, $COLOR,
		scalar(localtime(time)), $TESTNAME, $STATUS_SUMMARY, $DIAGINFO);

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

	if (! defined($Xymon::STATUSCOLOR_PRIORITY{$new_testcolor})) {
		return &Xymon::get_testcolor;
	}	
	
	if ($Xymon::STATUSCOLOR_PRIORITY{$Xymon::STATUS_COLOR} <
	    $Xymon::STATUSCOLOR_PRIORITY{$new_testcolor}) {
		$Xymon::STATUS_COLOR = $new_testcolor;
	}

	return &Xymon::get_testcolor;
}

sub get_testcolor
#
# Returns the canonical test color.
#
{
	return $Xymon::STATUS_COLOR;
}	    

sub set_status_summary
#
# Set the status summary text.
#
{
	$Xymon::STATUS_SUMMARY = shift(@_);
}

sub get_status_summary
#
# Returns the canonical test color.
#
{
	return $Xymon::STATUS_SUMMARY;
}

package main;

__DATA__
Software Update Tool
Copyright 2002-2012 Apple Inc.

Finding available software
Software Update found the following new or updated software:
   * MacBookAirEFIUpdate2.4-2.4
        MacBook Air EFI Firmware Update (2.4), 3817K [recommended] [restart]
   * ProAppsQTCodecs-1.0
        ProApps QuickTime codecs (1.0), 968K [recommended]
   * JavaForOSX-1.0
        Java for OS X 2012-005 (1.0), 65288K [recommended]
