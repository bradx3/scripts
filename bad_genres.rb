#!/usr/bin/env ruby

require "appscript"
require "ruby-debug"

APP = Appscript.app("iTunes")
tracks = APP.sources["Library"].tracks.get

artists = {}

tracks.each do |t|
  begin
    artist = t.artist.get.downcase.strip
    genre = t.genre.get.downcase.strip

    (artists[artist] ||= []) << genre
  rescue CommandError
    if $!.to_s.index("-1712").nil?
      raise $!
    end
  end
end

multi = []
artists.each do |artist, genres|
  multi << artist if genres.uniq.compact.length > 1
end
puts multi.sort
