#!/usr/bin/env ruby

require "rubygems"
require "appscript"
require "ruby-debug"

def clear_playlist(playlist)
  playlist.tracks.get.each do |t|
    app_exec { playlist.delete(t) }
  end
  puts "Cleared #{ playlist.name.get }"
end

def copy_tracks(src, dest)
  src.tracks.get.each do |t|
    app_exec { t.duplicate(:to => dest) }
  end
  puts "Copied #{ src.name.get } to #{ dest.name.get }"
end

def app_exec(&block)
  begin
    yield
  rescue
    if $!.to_s.index("-1708")
      # ignore
    else
      puts $!
      exit 1
    end
  end
end

# load some playlists
APP = Appscript.app("iTunes")
new_random_tracks = APP.playlists["Random New"]
random_tracks = APP.playlists["Random"]
random_unplayed_tracks = APP.playlists["Random Unplayed"]
target = APP.playlists["Work"]
phone = APP.sources.get.detect { |s| s.name.get == "Brad's iPhone" }
phone = phone.playlists.get.detect { |pl| pl.name.get == "Brad's iPhone" }

if !ARGV.include?("keep")
  clear_playlist(phone)
end

if !ARGV.include?("copy")
  # load some new random tracks
  clear_playlist(target)
  # clear_playlist(new_random_tracks)
  # clear_playlist(random_tracks)
  # clear_playlist(random_unplayed_tracks)
end

# sleep for a bit to let new tracks load
sleep 1

# copy them to work playlist
copy_tracks(new_random_tracks, target)
copy_tracks(random_tracks, target)
copy_tracks(random_unplayed_tracks, target)

# # clear random playlists so I don't listen to the same ones at home
# clear_playlist(new_random_tracks)
# clear_playlist(random_tracks)
# clear_playlist(random_unplayed_tracks)

# and copy work over to my phone
copy_tracks(target, phone)
