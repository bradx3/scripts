// ==UserScript==
// @name         Lucidica for Google Reader
// @description  The latest version of Lucidica, a Google Reader theme by Ismael Sobek. Based off of Helvetireader by Jon Hicks.
// @include      https://*.google.com/reader/view/*
// @include      http://*.google.com/reader/view/*
// @include      htt*://*.google.*/reader/view*
// @author       Jon Hicks (http://www.hicksdesign.co.uk). Modified by Ismael Sobek (http://ismaelsobek.com). Favicon override by MkFly.
// ==/UserScript==


var favvy = document.createElement('link');
favvy.setAttribute('type', 'image/x-icon');
favvy.setAttribute('rel', 'shortcut icon');
favvy.setAttribute('href', 'http://ismaelsobek.com/lucidica/favicon.png');
var head = document.getElementsByTagName('head')[0];
head.appendChild(favvy);

var cssNode = document.createElement('link');
cssNode.type = 'text/css';
cssNode.rel = 'stylesheet';
cssNode.href = 'http://ismaelsobek.com/lucidica/theme.css';
cssNode.media = 'screen';
cssNode.title = 'dynamicLoadedSheet';
document.getElementsByTagName("head")[0].appendChild(cssNode);
