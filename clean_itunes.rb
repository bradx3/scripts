#!/usr/bin/env ruby -rubygems

require "ruby-debug"
require "iconv"

SRC_FILE = File.expand_path("~/tmp/Music.txt")
FILE = File.expand_path("~/tmp/Music.tab")

def line_to_hash(line)
  line = line.split("\t")
  hash = {}
  $columns.each_with_index do |c, i|
    hash[c] = line[i]
  end
  hash
end

def load_tracks
  system("iconv -f UTF-16 -t UTF-8 #{ SRC_FILE } >> #{ FILE }")
  lines = File.open(FILE).read.split("\r")

  $columns = lines.first
  $columns = $columns.split("\t")

  tracks = {}
  lines[1..lines.length].each do |line|
    hash = line_to_hash(line)
    artist = hash["Artist"].downcase.strip
    (tracks[artist] ||= []) << hash
  end
  tracks
end

tracks = load_tracks
puts "loaded..."

tracks.each do |artist, tracks|
  genres = tracks.map do |t| 
    location = t["Location"]
    t["Genre"] if location and !location.index("Various Artists")
  end
  genres = genres.compact.uniq

  if genres.length > 1
    puts artist
    puts genres
    puts "--"
  end
end

