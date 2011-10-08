#!/usr/bin/env ruby
require 'csv'
require 'pp'
require 'plist'
require 'mongoid'

Mongoid.database = Mongo::Connection.new('localhost').db('itunes')

class Track
  include Mongoid::Document
end

class ItunesOrganiser < Struct.new(:file, :quick)

  def tracks_from_xml
    log("load from xml")
    Plist::parse_xml(file)["Tracks"].values
  end

  def load_into_mongo(tracks)
    log("deleting #{ Track.count } tracks")
    Track.destroy_all

    log("loading #{ tracks.length } tracks into mongo")
    tracks.each do |t|
      attrs = {}
      t.each { |key, value| attrs[key.parameterize("_")] = value }
      attrs.delete_if { |k, v| v.class == DateTime }
      Track.create!(attrs)
    end
  end

  def check_compilations
    log("checking compilations")
    count = 0

    Track.only(:album).aggregate.each do |info|
      album = info["album"] || ''
      tracks = Track.where(:album => album)
      counts = track_count_by_artist(tracks)
      if bad_compilation?(album, tracks, counts)
        puts "--------------------------------------------------"
        puts "BAD COMPILATION"
        puts "Album: #{ album }"
        puts "Artists: #{ counts.keys.join(", ") }"
        count +=1
      end
    end
    count
  end

  def bad_compilation?(album, tracks, counts)
    counts.keys.length > 1 && # too many artists
      counts.values.min < 4 && # if each artist has at least 4 tracks, probably different albums
      album.downcase.index("[split]").nil? && # skip split cds, etc
      tracks.detect { |t| t["compilation"].nil? } # compilation flag not set
  end

  def artist(track)
    if track["album_artist"].present?
      track["album_artist"]
    else
      track["artist"]
    end
  end

  def track_count_by_artist(tracks)
    counts = {}
    tracks.each do |t|
      counts[artist(t)] ||= 0
      counts[artist(t)] += 1
    end
    counts
  end

  def check_genres
    log("checking genres")
    count = 0
    Track.only(:artist).aggregate.each do |info|
      genres = Track.where(:artist => info["artist"], :compilation => nil).only("genre").aggregate
      if genres.length > 1
        popular = genres.sort_by { |g| g["count"] }.last["genre"]
        puts "--------------------------------------------------"
        puts "BAD GENRE"
        puts "Artist: #{ info["artist"] }"
        puts "Suggestion: #{ popular }"
        count += 1
      end
    end
    count
  end

  def check_years
    log("checking years")
    tracks = Track.where(:year => nil) + Track.where(:year.lt => 1920)
    done = {}
    tracks.each do |track|
      key = "#{ artist(track) }\t#{ track["album"] }"
      next if done[key]
      puts "--------------------------------------------------"
      puts "BAD YEAR"
      puts "Artist: #{ artist(track) }"
      puts "Album: #{ track["album"] }"
      puts "Year: #{ track["year"] }"
      done[key] = true
    end
    done.length
  end

  def run
    load_into_mongo(tracks_from_xml) unless quick == "quick"
    bad_comp_count = check_compilations
    bad_genre_count = check_genres
    bad_year_count = check_years

    puts "\n\n"
    log "Bad compilations: #{ bad_comp_count }"
    log "Bad genres: #{ bad_genre_count }"
    log "Bad years: #{ bad_year_count }"
  end

  def log(str)
    puts "#{ Time.now }\t#{ str }"
  end
end

ItunesOrganiser.new(ARGV[0], ARGV[1]).run
