#!/usr/bin/env ruby

require "rubygems"
require 'amazon/aws'
require 'amazon/aws/search'
require "rbosa"

include Amazon::AWS
include Amazon::AWS::Search

KEY_ID = "0HS719SPKYNZ3R7TPT82"

def unrated
  lib = OSA.app( "iTunes" ).sources.detect { |s| s.name == "Library" }
  return lib.user_playlists.detect { |p| p.name == "To Rate" }
end

def amazon_rating(artist, album)
  puts "\nRequesting #{ artist } - #{ album }"
  @request ||= Request.new(KEY_ID)
  is = Amazon::AWS::ItemSearch.new( "Music", { 
                                      "Artist" => artist,
                                      'Title' => album } )
  rg = ResponseGroup.new("Large")
  begin
    response = @request.search( is, rg, :ALL_PAGES )
  rescue
    puts $!
    return
  end

  begin
    item = response[0].item_search_response[0].items[0].item
  rescue
    item = response.item_search_response[0].items[0].item
  end

  album = item[0]

  if album.customer_reviews
    return album.customer_reviews[0].average_rating 
  else
    puts "no reviews found"
#    puts album
#    exit(1)
  end
end

#puts amazon_rating("R.E.M", "Reckoning")
#puts amazon_rating("R.E.M", "Monster")
#puts amazon_rating("Abe Vigoda", "Skeleton")

def rating(artist, album)
  @cache ||= {}
  key = "#{ artist } = #{ album }".downcase
  
  @cache[key] ||= 20.0 * amazon_rating(artist, album).to_f
  
  return @cache[key]
end

unrated.file_tracks.each do |track|
  result = rating(track.artist, track.album)
  track.rating = result
end
