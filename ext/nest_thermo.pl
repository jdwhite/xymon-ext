#!/usr/bin/env perl
#
# nest_thermo - report status of nest thermostat
#
# Jason White <jdwhite@menelos.com>
#
=begin License

The MIT License (MIT)

Copyright (c) 2016 Jason White <jdwhite@menelos.com>

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
# This program uses the Nest API to fetch information about devices in a 
# Nest account.
#
#
# Installation
# ============
# 1) Copy this file to $XYMONHOME/ext/
#
# 2) Create $XYMONHOME/etc/tasks.d/nest_thermo with the following block:
#    -or-
#    Modify $XYMONHOME/etc/tasks.cfg and add the following block:
#
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# # Nest Thermostat
# [nest_thermo]
#         ENABLED
#         ENVFILE $XYMONHOME/etc/xymonserver.cfg
#         CMD $XYMONHOME/ext/nest_thermo
#         LOGFILE $XYMONHOME/logs/nest_thermo.log
#         INTERVAL 5m
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
# 3) Fill in the three required values under the Local Configuration
#    block.
#
# 4) Set your preferred values for the set_machinename and set_testname calls.
#

#
# Local Configuration
#
#-----------------------------------------------------------------------
# Authorization Code
$main::AuthCode = "<YOUR AUTHCODE HERE>";
# StructureID (Home)
$main::StructureID = "<YOUR STRUCTUREID HERE>";
# DeviceID (Living Room)
$main::DeviceID = "<YOUR DEVICEID HERE>";
#------------------------------------------------------------------------

#
# Code Formatting
# ===============
# Initial indentation of is done with tabs; successive alignment is done
# with spaces. To format this code per your indentation preference, say,
# 4 spaces per tab stop:
#         less -x4
#         nano -T4
#         vim (set tabstop=4 (also in .vimrc))
#         vi  (set ts=4 (also in .exrc))

use strict;
use warnings;
#use Data::Dumper;
use English; # $PROGRAM_NAME
use LWP::UserAgent;
use JSON;
use DateTime::Format::ISO8601;
use Carp;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib/perl5';
use lib dirname(abs_path $0) . '/../lib/perl5';
use XymonEXT;

#
# Initialize some defaults.
#
set_machinename("nest,example,com");
set_testname("th-status");

$main::message = "";
$main::API_URL = "https://developer-api.nest.com/?auth=${main::AuthCode}";

#
# Fetch the JSON status structure.
#
my $ua = LWP::UserAgent->new;
$ua->timeout(30);
$ua->default_header('Accept' => "application/json");
my $req = HTTP::Request->new(GET => $main::API_URL);

my $res = $ua->request($req);

if (! $res->is_success) {
	confess "Error: ".$res->status_line;
}

my $scalar = from_json($res->content);

my $Structures = \%{$scalar->{structures}};
my $Devices = \%{$scalar->{devices}};
my $Metadata = \%{$scalar->{metadata}};

my $st = \%{$Structures->{$main::StructureID}};
my $Wheres = \%{$st->{wheres}};
my $th = \%{$Devices->{thermostats}->{$main::DeviceID}};

push(@main::CSV,
     "Name:".$th->{name_long},
     "Presence:".$st->{away},
     "Temp:".$th->{ambient_temperature_f}
);

#if ($th->{hvac_mode} =~ /^(heat|cool)$/o) {
	push(@main::CSV, "Target Temp:".$th->{target_temperature_f});
#}
#elsif ($th->{hvac_mode} eq "heat-cool")
#{
	push(@main::CSV,
	     #"Target Temp (H):".$th->{target_temperature_high_f}." (heat-cool only)",
	     #"Target Temp (L):".$th->{target_temperature_low_f}." (heat-cool only)"
	     "Target Temp (H):".$th->{target_temperature_high_f},
	     "Target Temp (L):".$th->{target_temperature_low_f}
	);
#}

my $dt = DateTime::Format::ISO8601->parse_datetime($th->{last_connection});
$dt->set_time_zone('America/Chicago');

push(@main::CSV,
     "Humidity:".$th->{humidity},
     "HVAC Mode:".$th->{hvac_mode},
     "State:".$th->{hvac_state},
     "Away Temp:".$th->{away_temperature_low_f}."/".$th->{away_temperature_high_f},
     "Last Update:".$dt->strftime("%a %b %d %T %Y"),
     "Software Version:".$th->{software_version},
);

foreach my $val (@main::CSV) {
	my($k,$v) = split(/:/,$val,2);
	$main::message .= sprintf("%16s: %s\n", $k, $v);
}

set_testcolor("green");

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
	"message"  => $main::message,
	"lifetime" => "30m"
);

exit;
