#!/usr/bin/env ruby

require 'rubygems'
require 'sqlite3'
require 'rbosa'
require "../lib/my_tools.rb"

def clean_path(path)
  roots = []
  words = [ "Classical", "Ripped", "General" ]
  sources = [ "/home/brad/Media/Music/", "/Volumes/Media/Music/" ]
  
  words.each do |word|
    sources.each do |source|
      path = path.gsub("#{ source }#{ word }", "")
    end
  end

  path = path.gsub(".flac", ".mp3")

  return path
end

DB = SQLite3::Database.new(File.expand_path("~/tmp/songs3.db"))
file_tracks = itunes_library.user_playlists.detect { |p| p.name == "Music" }.file_tracks
tracks = {}
file_tracks.each do |ft|
  if ft.location
    path = clean_path(ft.location)
    tracks[path] = ft
  end
end
puts tracks.length
puts tracks.keys[0, 10]

sql = "select path, play_count from songs where path like '%Ripped%' and not path like '%RippedMP3%'"
columns, *rows = DB.execute2(sql)

rows.each do |row|
  path = clean_path(row[0])
  count = row[1].to_i
  track = tracks[path]

  if track and count > track.played_count.to_i
    track.played_count = count
    puts "updated #{ path } to #{ count }"
  end
end

DB.close
