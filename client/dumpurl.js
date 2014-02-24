//
// dumpurl.js - fetch, render, and dump HTML to stdout
//
// Jason White
// 11-Feb-2014
//
var page = new WebPage(), address;

if (phantom.args.length === 0) {
    console.log('Usage: dumpurl.js {URL}');
    phantom.exit();
}

// http://stackoverflow.com/questions/16854788/phantomjs-webpage-timeout
page.settings.resourceTimeout = 10000; // 10 seconds
page.onResourceTimeout = function(e) {
  console.log(e.errorCode);   // it'll probably be 408
  console.log(e.errorString); // it'll probably be 'Network timeout on resource'
  console.log(e.url);         // the url whose request timed out
  phantom.exit(1);
};

address = encodeURI(phantom.args[0]);
page.open(address, function (status) {
    //console.log("inside page.open()");
    if (status !== 'success') {
        console.log('Failed to load', address);
	phantom.exit();
    }
    window.setTimeout(function() {
	console.log(page.content);
	phantom.exit();
    }, 4000);
});
