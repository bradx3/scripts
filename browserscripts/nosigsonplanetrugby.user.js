// ==UserScript==
// @name	Remove all sig images on planet rugby forums
// @description	Remove all sig images on planet rugby forums
// @include	*forum.planet-rugby.com*
// ==/UserScript==


var aNodes = document.getElementsByClassName("sig");
// class="ar" is end
for (var i = 0; i < aNodes.length; i++)
{
    var sig = aNodes[i];
    while (true) {
	sig = sig.nextSibling;
	if (sig.className == "ar") {
	    break;
	}
	else if (sig.tagName == "IMG" || sig.tagName == "BR") {
	    var css = "display: none;";
	    sig.style.cssText = css;
	}
    }
}

var nodes = document.getElementsByClassName("avatarPad");
for (var i = 0; i < nodes.length; i++) {
    var css = "display: none;";
    nodes[i].style.cssText = css;
}









