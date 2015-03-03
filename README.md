xymon-ext
=========
External Xymon tests and support programs.

These tests use a lot of the same code, and I plan to place that code into a perl module down the road.

License
-------
The items in this repisotiry are licensed under the [MIT license](http://opensource.org/licenses/MIT), except for client/dumpurl.js which has no license.

client/test_framework
---------------------
This is a sample test framework for creating other tests.  It's designed as a prelude to writing a Xymon module and contains a couple 
subroutines designed to take some of the drudgery out of writing Xymon tests.

 * **Xymon::set_testcolor** - tracks the canonical test color. When called the color is only set as the canonical color if it's severity is 
higher than the current value (obtainable using Xymon::get_tesetcolor).

 * **Xymon::send_status** - sends a status update. Parameters such as lifetime, group, hostname, testname, color, message, and summary can be 
passed to this subroutine and these criterion will be used to automatically format and send the status message.

There are also other getter/setter subroutines that can be used in leiu of passing certain parameters to **Xymon::send_status**.

client/socket_monitor
---------------------
Monitors network socket utilization that, in excess, causes the "Can't assign requested address" error that exists in OS X Mavericks 10.9.1-10.9.2. 
More information can be found [here](https://discussions.apple.com/thread/5551686).

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

client/osx-cacheserver_monitor
----------------------------
Monitors the running state and cache utilization by data type of the OS X Server caching server.

Example output:

                     Active: yes
                 Cache Free: 67.91G
                Cache Limit: 78.5G
               Cache Status: OK
                 Cache Used: 10.59G (13.5%)
          Cached Item Count: 77
                      Peers: none
                       Port: 51330 (dynamic)
        Registration Status: 1 (Registered)
             Startup Status: OK
    Total Bytes From Origin: 8.78G
     Total Bytes From Peers: 0
      Total Bytes Requested: 8.78G
       Total Bytes Returned: 15.19G (42.2% efficiency)
                      state: RUNNING
    
               Mac Software:  9199M
               iOS Software:   622M
                      Books:     2M
                     Movies:     0M
                      Music:     0M
                      Other:   769M

client/afs_servmon
------------------
Monitors an AFS file server through the use of rxdebug and 'bos status' commands.

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

client/dwm_report
-----------------
A Daily/Weekly/Monthly report test for NetBSD designed to scan for interesting keywords in these reports and report a status accordingly. This is just a beginning framework. I'm not perfrectly happy with it, but i'm throwing it out for other to see and possibly stimulate discussion on how to make this test better. I'd also like to support Linux periodic reports in the future.

server/dropbox_monitor
----------------------
Monitors status of Dropbox service by scraping http://status.dropbox.com and parsing the values inside the 'status-line' and 'status-message' div tags.

    Sun Feb 23 21:41:23 2014 - status: running normally.
    
    Dropbox is running normally.

server/google_monitor
---------------------
Monitors Google Apps services using JSON data retrieved from http://www.google.com/appsstatus/json/en. Each service is reported as a separate test.
Example output from the Gmail test:

    Sun Feb 23 20:35:11 2014 - Gmail: OK
 
    Gmail: OK green
 
    green Thu Feb  6 18:00:00 2014 [resolved]
          The problem with Gmail should be resolved. We apologize for the 
          inconvenience and thank you for your patience and continued support.

          Additional Info
          ---------------
          New messages should no longer be delayed. Messages stuck in the
          backlog will continue be delivered over the next few hours.

   yellow Thu Feb  6 14:29:00 2014 [resolved]
          Gmail service has already been restored for some users, and we 
          expect a resolution for all users in the near future. Please note 
          this time frame is an estimate and may change.
 
   yellow Thu Feb  6 14:07:00 2014 [resolved]
          Our team is continuing to investigate this issue. We will provide 
          an update by Thu Feb  6 16:00:00 2014 with more information about 
          this problem. Thank you for your patience.

          Additional Info
          ---------------
          Some users may be experiencing delays in sending and receiving emails.

   Source: http://www.google.com/appsstatus

Google_monitor has not been tested against a full service outage, so the event type is unknown to the author at this time. Unknown event types are flagged as yellow and diagnostic data will be presented on the test page. The author would be grateful for any reports of unknown type codes. 

server/box_monitor
------------------
Monitors Box.com cloud services using data retrieved from http://status.box.com. Each service is reported as a separate test.
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

The extended log is only available for tests that have experienced issues in the past five days. Please note that while the timestamp at the beginning of each event log entry is converted to the time zone of your choice, any time references in the body of the event are not since the formats of those are more free-form.  I do plan to try and address this in a later release as well as automatically determine the local time zone so it doesn't have to be hard coded at the end of box2localtime().

server/apple_monitor
--------------------
Monitors Apple's numerous services using data retrieved from http://www.apple.com/support/systemstatus/.

Apple's status page currently includes 45 tests. Since they are no longer categorized, I recommend configuring a separate 'vpage' to 
display the tests as hosts (one per line) instead of columns.

The hosts.cfg file should contain the following:

    vpage apple Apple Services
    0.0.0.0         www.apple.com                   # conn NAME:"Apple Services"

I recommend using real, resolvable host names for each category so the conn test works.  This will keep Xymon from generating a ton of alerts in the event of transient network outages.

Example output from the iCloud host, Calendar service test:

    Sun Feb 23 22:01:42 2014 - Calendar: OK

    Calendar: OK green

    Source: http://www.apple.com/support/systemstatus/

In addition to the service tests, an additional 'Timeline' test is reported containing the detailed timeline data at the bottom of the 
status page. Detailed status data is also included on a per-test basis when appropriate.

server/wins
-----------
This test queries WINS servers and checks for a supplied expected result.

Example output:

    Lookup: windc1 => MISMATCH! expected=1.2.3.1, received=1.2.3.5 windc1<00> &red
    Lookup: windc3 => 1.2.3.3 windc3<00> &green
    Lookup: bogon => name_query failed to find name bogon &red
