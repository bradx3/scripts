#!/usr/bin/env ruby

require "rubygems"
require "appscript"

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

APP = Appscript.app("iTunes")
target = APP.playlists["Work"]
phone = APP.sources.get.detect { |s| s.name.get == "Brad's iPhone" }
phone = phone.playlists.get.detect { |pl| pl.name.get == "Brad's iPhone" }
copy_tracks(target, phone)
