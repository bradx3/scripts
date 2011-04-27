#!/usr/bin/env python2.6
import sys
from mutagen.easyid3 import EasyID3

audio = EasyID3(sys.argv[1])
artist = audio["artist"]
if len(artist) > 0:
  print artist[0]

