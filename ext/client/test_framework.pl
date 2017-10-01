#!/usr/bin/env perl
#
# test_framework - a framework for creating Xymon tests
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
# 	INTERVAL 5m
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#

use strict;
#use warnings;
use Data::Dumper;
use English; # $PROGRAM_NAME

# Use XymonEXT module.
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib/perl5';
use lib dirname(abs_path $0) . '/../lib/perl5';
use XymonEXT;

#
# Initialize some defaults.
#
set_testname("##TESTNAME##");
$main::message = "";

#
# == Run Tests ==
#
# Here is where you'd perform the testing, adding to $main::message.
#
# * To set the overall, canonical, test color:
#      set_testcolor("##COLOR##");
#   where ##COLOR## is one of clear, green, yellow, red.
#   set_testcolor() can be called multiple times and will always contain the 
#   most severe color, suitable for returning overall test status.
#
# * To set the test summary string:
#      set_summary("host unreachable");
#
# * To set the name of the test (column):
#      set_testname("footest");
#
# * Override the name of the machine we report as:
#      set_machinename("machine1,example,com");
#   Default is the current hostname.
#
# Note that the preceeding "setter" subroutines also have corresponding 
# "getter" subroutines that return their current value. 
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

send_status(
	"message"  => $main::message,
);

exit;
