#!/usr/bin/env perl
#
# smart_monitor - monitor SMART status of disks.
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

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Install in $XYMONCLIENTHOME/client/ext/.
# Modify $XYMONCLIENTHOME/etc/clientlaunch.cfg and add this block:
#
# # SMART Monitor#
# [smartmon]
# 	ENABLED
# 	ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
# 	CMD $XYMONCLIENTHOME/ext/smart_monitor.pl
# 	LOGFILE $XYMONCLIENTHOME/logs/smart_monitor.log
# 	INTERVAL 10m
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# Modify /etc/sudoers as follows:
#
#   1) Add "Defaults:xymon    !requiretty" since user xymon has no tty when
#      running this script.
#
#   2) Add the following line to the bottom of the config file to allow
#      user xymon to execute the raidctl command without a password:
#
#        xymon   ALL= NOPASSWD: /opt/pkg/sbin/smartctl
#

use strict;
use warnings;

#use Data::Dumper;
use English;    # $PROGRAM_NAME

use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname( abs_path $0) . '/lib/perl5';
use lib dirname( abs_path $0) . '/../lib/perl5';
use XymonEXT;

#
# Globals
#
$main::SUDO     = '/usr/bin/sudo';
$main::SMARTCTL = '/opt/pkg/sbin/smartctl';

#
# Initialize some defaults.
#
set_testname("smart");
$main::message = "";

#
# Check SMART status of each device.
#
foreach my $device ( sort &get_devices() ) {
    open( SMARTCTL, "${main::SUDO} ${main::SMARTCTL} -s on -i -H $device |" )
        || die "$!";
    $main::message
        .= "======================= $device =======================\n";
    while (<SMARTCTL>) {
        my ($current_condition) = "";
        next if /^(smartctl|Copyright) /o;
        next if /^===/o;
        next if /^\s*$/o;

        if (/^SMART overall\-health.+:\s+(\S+)/io) {
            my $status = $1;

            if ( $status eq "PASSED" ) {
                $current_condition = "green";
            }
            else {
                $current_condition = "red";
            }
        }

        chomp;
        $main::message .= $_;
        if ( $current_condition ne "" ) {
            $main::message .= " &${current_condition}";
            set_testcolor($current_condition);
        }
        $main::message .= "\n";
    }
    close(SMARTCTL);
    $main::message .= "\n";
}

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

send_status( "message" => $main::message, );

exit;

#
# Get devices names.
#
sub get_devices {
    my @devices = ();
    my $OS      = `uname`;

    chomp($OS);
    if ( $OS =~ /.*BSD$/io ) {
        open( IOSTAT, "iostat -x |" ) || die "iostat: $!";
        while (<IOSTAT>) {
            next unless /^([ws]d\d+)/o;
            push( @devices, "/dev/r${1}d" );
        }
        close(IOSTAT);
    }
    elsif ( $OS =~ /Darwin/ ) {
        open( DISKUTIL, "diskutil list physical|" ) || die "$!";
        while (<DISKUTIL>) {
            next unless /^(\/dev\/disk\S+)/io;
            push( @devices, $1 );
        }
    }
    else {
        warn "OS '$OS' not recognized. Update script.\n";
    }

    return @devices;
}
