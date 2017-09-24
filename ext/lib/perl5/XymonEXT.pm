#!/usr/bin/env perl
#
# XymonEXT.pm - Xymon external test common functions.
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

package XymonEXT;

use strict;
use warnings;
use Carp;

BEGIN {
    require Exporter;

    # set the version for version checking
    our $VERSION = 0.1;

    # Inherit from Exporter to export functions and variables
    our @ISA = qw(Exporter);

    # Functions and variables which are exported by default
    our @EXPORT = qw(
        send_status
        set_testcolor   get_testcolor
        set_summary     get_summary
        set_testname    get_testname
        set_machinename get_machinename
    );

    # Functions and variables which can be optionally exported
    our @EXPORT_OK = qw(@EXPORT);
}

#
# Initialize variables in the XymonEXT namespace.
#

# Weight each color carries for reporting purposes.
our %COLOR_PRIORITY = (
    'red'    => 4,
    'yellow' => 3,
    'green'  => 2,
    'clear'  => 1,
);

our $TESTNAME = "default-test";
our $MACHINE
    = ( defined $ENV{MACHINE} ) ? $ENV{MACHINE} : "dummy,example,com";
our $SUMMARY = "";
our $COLOR   = "clear";

#
# Send a status update to the Xymon display server.
#
# usage: send_status(%validargs);
#
sub send_status {
    #
    # Valid arguments (named same as xymon(1) manpage).
    #
    my %validargs = (
        "lifetime" => 1,
        "group"    => 1,
        "hostname" => 1,
        "testname" => 1,
        "color"    => 1,
        "message"  => 1,
        "summary"  => 1,
    );

    my %args = @_;

    #
    # Validate passed arguments; warn if invalid.
    #
    foreach my $key ( keys %args ) {
        if ( !defined( $validargs{$key} ) ) {
            carp "${main::PROGRAM_NAME}: in send_staus(): "
                . "invalid argument $key\n";
        }
    }

    my ($LIFETIME)
        = exists $args{lifetime}
        ? "+$args{lifetime}"
        : "";
    my ($GROUP)
        = exists $args{group}
        ? "/group:$args{group}"
        : "";
    my ($TESTNAME)
        = exists $args{testname}
        ? $args{testname}
        : get_testname();
    my ($COLOR)
        = exists $args{color}
        ? $args{color}
        : get_testcolor();
    my ($MACHINE)
        = exists $args{hostname}
        ? $args{hostname}
        : get_machinename();
    my ($DIAGINFO)
        = exists $args{message}
        ? $args{message}
        : "";
    my ($SUMMARY)
        = exists $args{summary}
        ? $args{summary}
        : get_summary();

    my ($MESSAGE) = sprintf(
        "status%s%s %s.%s %s %s - %s: %s\n%s",
        $LIFETIME, $GROUP,   $MACHINE,
        $TESTNAME, $COLOR,   scalar( localtime(time) ),
        $TESTNAME, $SUMMARY, $DIAGINFO
    );

    #
    # Send to Xymon or to stdout if not called by Xymon.
    #
    if ( defined( $ENV{XYMON} ) ) {

        # "at" sign (@) as argument means "read message data from
        # stdin". DON'T USE A DASH AS THE xymon USAGE MESSAGE
        # SHOWS ELSE ONLY THE SUMMARY INFORMATION IS DISPLAYED
        # AND NONE OF ${DATA}. THE MANPAGE USAGE OF "@" IS
        # CORRECT.

        my ($cmd) = "$ENV{XYMON} $ENV{XYMSRV} @";
        open( XYMON, "| ${cmd}" ) || do {
            print "Error invoking ${cmd} - $!";
        };
        select(XYMON);
    }
    else {
        print STDERR "*** Test not invoked by Xymon; "
            . "report follows ***\n\n";
    }

    print $MESSAGE;
    close(XYMON);
}

#
# Set the canonical test color.
# Returns the canonical test color.
#
sub set_testcolor {
    my ($new_testcolor) = shift(@_);

    if ( !defined( $COLOR_PRIORITY{$new_testcolor} ) ) {
        return get_testcolor();
    }

    if ( $COLOR_PRIORITY{$COLOR} < $COLOR_PRIORITY{$new_testcolor} ) {
        $COLOR = $new_testcolor;
    }

    return get_testcolor();
}

#
# Returns the canonical test color.
#
sub get_testcolor {
    return $COLOR;
}

#
# Set the status summary text.
#
sub set_summary {
    $SUMMARY = shift(@_);
}

#
# Returns the status summary color.
#
sub get_summary {
    my ($SUMMARY) = $SUMMARY;

    if ( $SUMMARY =~ /^\s*$/o ) {
        if ( $COLOR_PRIORITY{$COLOR} > $COLOR_PRIORITY{"green"} ) {
            $SUMMARY = "NOT OK";
        }
        else {
            $SUMMARY = "OK";
        }
    }

    return $SUMMARY;
}

#
# Set the test name.
#
sub set_testname {
    $TESTNAME = shift(@_);
}

#
# Returns the test name.
#
sub get_testname {
    return $TESTNAME;
}

#
# Set the machine name (use commas, i.e. foo,menelos,com).
#
sub set_machinename {
    $MACHINE = shift(@_);
}

#
# Returns the machine name.
#
sub get_machinename {
    return $MACHINE;
}

1;
