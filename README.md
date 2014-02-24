xymon-ext
=========

External Xymon tests.

client/socket_monitor
---------------------
Monitors network socket utilization that, in excess, causes the "Can't 
assign requested address" error that exists in OS X Mavericks 10.9.1. 
More information can be found at https://discussions.apple.com/thread/5551686

client/dropbox_monitor
----------------------
Monitors status of Dropbox service by scraping http://status.dropbox.com 
and examing the string after "Dropbox is ".

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
