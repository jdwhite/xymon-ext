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

