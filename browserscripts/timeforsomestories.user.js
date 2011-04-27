// ==UserScript==
// @name	Lowercase Time For Some Stories text
// @description	Lowercase Time For Some Stories text
// @include	*timeforsomestories.blogspot.com*
// ==/UserScript==


var aNodes = document.getElementsByClassName('post');
for (var i = 0; i < aNodes.length; i++)
{
    var post = aNodes[i];
    var css = "text-transform: lowercase;";
    post.style.cssText = css;
}









