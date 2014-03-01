//
// dumpurl.js - fetch, render, and dump HTML to stdout
//
// Jason White <jdwhite@menelos.com>
// 11-Feb-2014
//
// Initial indentation of is done with tabs; successive alignment is done
// with spaces. To format this code per your indentation preference, say,
// 4 spaces per tab stop:
//	  less -x4
//	  nano -T4
//	  vim (set tabstop=4 (also in .vimrc))
//	  vi  (set ts=4 (also in .exrc))
//
var page = new WebPage(), address;

if (phantom.args.length === 0) {
	console.log('Usage: dumpurl.js {URL}');
	phantom.exit();
}

// http://stackoverflow.com/questions/16854788/phantomjs-webpage-timeout
page.settings.resourceTimeout = 10000; // 10 seconds
page.onResourceTimeout = function(e) {
	console.log(e.errorCode);   // Probably be 408
	console.log(e.errorString); // Probably be 'Network timeout on resource'
	console.log(e.url);         // URL whose request timed out
	phantom.exit(1);
};

address = encodeURI(phantom.args[0]);
page.open(address, function (status) {
	if (status !== 'success') {
		console.log('Failed to load', address);
		phantom.exit();
	}
	window.setTimeout(function() {
		console.log(page.content);
		phantom.exit();
	}, 4000); // 4 second timeout.
});
