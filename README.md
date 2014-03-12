xymon-ext
=========

External Xymon tests.

These tests use a lot of the same code, and I plan to place that code into a perl module down the road.

client/socket_monitor
---------------------
Monitors network socket utilization that, in excess, causes the "Can't 
assign requested address" error that exists in OS X Mavericks 10.9.1. 
More information can be found at https://discussions.apple.com/thread/5551686

    Sun Feb 23 21:43:31 2014 - socket: OK

    Results of "netstat -an -f inet"

         CLOSED:    0 green
     CLOSE_WAIT:    0 green
        CLOSING:    0 green
    ESTABLISHED:   34 green
     FIN_WAIT_1:    2 green
     FIN_WAIT_2:    2 green
       LAST_ACK:    5 green
         LISTEN:   37 green
       SYN_RCVD:    0 green
       SYN_SENT:   15 green
      TIME_WAIT:    0 green

client/dropbox_monitor
----------------------
Monitors status of Dropbox service by scraping http://status.dropbox.com 
and examing the string after "Dropbox is ".

    Sun Feb 23 21:41:23 2014 - status: running normally.
    
    Dropbox is running normally. green

client/google_monitor
---------------------
Monitors Google Apps services using JSON data retrieved from 
http://www.google.com/appsstatus/json/en. Each service is reported as a 
separate test.  Example output from the Gmail test:

    Sun Feb 23 20:35:11 2014 - Gmail: OK
 
    Gmail: OK green
 
    green Thu Feb  6 18:00:00 2014 [resolved]
             The problem with Gmail should be resolved. We apologize for the 
             inconvenience and thank you for your patience and continued support.

             Additional Info:
             * New messages should no longer be delayed. Messages stuck in the backlog will continue be delivered over the next few hours.

    yellow Thu Feb  6 14:29:00 2014 [resolved]
              Gmail service has already been restored for some users, and we 
              expect a resolution for all users in the near future. Please note 
              this time frame is an estimate and may change.
 
    yellow Thu Feb  6 14:07:00 2014 [resolved]
              Our team is continuing to investigate this issue. We will provide 
              an update by Thu Feb  6 16:00:00 2014 with more information about 
              this problem. Thank you for your patience.

              Additional Info:
              * Some users may be experiencing delays in sending and receiving emails.

    yellow Thu Feb  6 13:15:00 2014 [resolved]
               We're investigating reports of an issue with Gmail. We will 
               provide more information shortly. 

    Source: http://www.google.com/appsstatus

Google_monitor has not been tested against a full service outage, so the 
event type is unknown to the author at this time. Unknown event types 
are flagged as yellow and diagnostic data will be presented on the test 
page. The author would be grateful for any reports of unknown type codes. 

client/box_monitor
------------------

Monitors Box.com cloud services using data retrieved from 
http://status.box.com. Each service is reported as a separate test.  
Example output from the sync service test:

    Sun Feb 23 21:31:22 2014 - sync: Up
    
    sync: Up green
    
    green Thu Feb 20, 2014 10:36PM CST
       The Sync downloads delay and notifications issue is resolved as of 
       8:36 p.m. PST. We apologize for any inconvenience.

    red Thu Feb 20, 2014  6:53PM CST
       Sync downloads and realtime notifications within the web 
       interface are delayed for some users.

    green Wed Feb 19, 2014  5:59PM CST
       The issue with Sync and notifications is resolved as of 3:59 p.m. 
       PST. We apologize for any inconvenience.

    red Wed Feb 19, 2014  3:00PM CST
       Today starting at 1:00pm PST, Box Sync and realtime notifications 
       within the web interface are delayed.

    Source: http://status.box.com

The extended log is only available for tests that have experienced 
issues in the past five days. Please note that while the timestamp at 
the beginning of each event log entry is converted to the time zone of 
your choice, any time references in the body of the event are not since 
the formats of those are more free-form.  I do plan to try and address 
this in a later release as well as automatically determine the local 
time zone so it doesn't have to be hard coded at the end of 
box2localtime().

client/apple_monitor
--------------------

Monitors Apple's numerous services using data retrieved from 
http://www.apple.com/support/systemstatus/. Because Apple's status page 
requires javascript, this test requires phantiomjs 
(http://phantomjs.org) and the included 'dumpurl.js' file to renter the 
javascript and produce HTML this test can consume.  Be sure to modify 
the following variables in apple_monitor accordingly.

    $::PHANTOMJS    = "/usr/local/bin/phantomjs";
    $::DUMPURLJS    = "/usr/local/libexec/dumpurl.js";

Apple's status page currently includes three main service categories: 
Services, Store, and iCloud.  This test treats each category as a 
separate host, each with their own set of tests, for a total of 35 
tests.  The hosts.cfg file should contain the following:

    group
    0.0.0.0         store.apple.com                 # conn NAME:"Apple Stores"

    group
    0.0.0.0         www.apple.com                   # conn NAME:"Apple Services"

    group
    0.0.0.0         www.icloud.com                  # conn NAME:"Apple iCloud"

I recommend using real, resolvable host names for each category so the 
conn test works.  This will keep Xymon from generating a ton of alerts 
in the event of transient network outages.

Example output from the iCloud host, Calendar service test:

    Sun Feb 23 22:01:42 2014 - Calendar: OK

    Calendar: OK green

    Source: http://www.apple.com/support/systemstatus/

client/dumpurl.js
-----------------

Takes one URL as an argument, loads the page, renders any Javascript 
present, and dumps the result to STDOUT.  Required by 
client/apple_monitor.

client/osx-srvrcache_monitor
----------------------------

Monitors the running state and cache utilization by data type of the OS 
X Server caching server.

Example output:

       Cache Size: 74866M
       Cache Used: 1728M (2.3%)

     Mac Software: 1509M
     iOS Software: 153M
            Books: 1M
           Movies: 0M
            Music: 0M
            Other: 63M

client/afs_servmon
------------------

Monitors an AFS file server through the use of rxdebug and 'bos status' 
commands.

Example output:

    status .afs green Wed Mar 12 14:30:41 2014 - afs: OK
  
    free packets: 289
    calls waiting: 0 &green
    threads idle: 11
    server connections: 4
    client connections: 14
    peer structs: 8
    call structs: 17
    free calls: 17
    packet allocation failures: 0
    calls: 7464
    allocs: 1223062
    read data: 1160144
    read ack: 35370
    read dup: 277
    read spurious: 0
    read busy: 0
    read abort: 2
    read ackall: 0
    read challenge: 143
    read response: 102
    sent data: 57356
    sent resent: 208
    sent ack: 583442
    sent busy: 1
    sent abort: 39
    sent ackall: 0
    sent challenge: 102
    sent response: 143
    
    Instance buserver, disabled, currently shutdown. &green
    Instance ptserver, currently running normally. &green
    Instance vlserver, currently running normally. &green
    Instance fs, currently running normally. &green
        Auxiliary status is: file server running. &green

client/raidframe
----------------

Monitors status of a raidframe RAID array. Tested under NetBSD.

Example ouptut:

    status .raidframe green raidframe OK Wed Mar 12 15:08:53 2014
    
    Components:
               /dev/wd0a: optimal &green
               /dev/wd1a: optimal &green
    No spares.
    Component label for /dev/wd0a:
       Row: 0, Column: 0, Num Rows: 1, Num Columns: 2
       Version: 2, Serial Number: 2013122701, Mod Counter: 151
       Clean: No, Status: 0
       sectPerSU: 128, SUsPerPU: 1, SUsPerRU: 1
       Queue size: 100, blocksize: 512, numBlocks: 1465148928
       RAID Level: 1
       Autoconfig: Yes
       Root partition: Yes
       Last configured as: raid1
    Component label for /dev/wd1a:
       Row: 0, Column: 1, Num Rows: 1, Num Columns: 2
       Version: 2, Serial Number: 2013122701, Mod Counter: 151
       Clean: No, Status: 0
       sectPerSU: 128, SUsPerPU: 1, SUsPerRU: 1
       Queue size: 100, blocksize: 512, numBlocks: 1465148928
       RAID Level: 1
       Autoconfig: Yes
       Root partition: Yes
       Last configured as: raid1
    Parity status: clean &green
    Reconstruction is 100% complete. &green
    Parity Re-write is 100% complete. &green
    Copyback is 100% complete. &green
