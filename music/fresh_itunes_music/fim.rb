#!/usr/bin/env ruby

require 'rubygems'
require 'sqlite3'
require 'fileutils'
require 'pathname'
require 'rbosa'
require 'optparse'
require 'my_tools.rb'

REMOTE_HOST = "clamps"
REMOTE_DB = "/var/cache/mt-daapd/songs3.db"
REMOTE_PATH = "/home/brad/Media/Music/"
LOCAL_PATH_TO_REMOTE = "/Volumes/Samba/clamps/Music/"
LOCAL_DB = File.expand_path("~/tmp/songs3.db")
WORKING = File.expand_path("~/tmp/mp3_working/")

module FreshTunes
  ###
  # Copies the current songs3.db from the server's firefly
  ###
  def copy_db_from_server
    log
    remote_do do |ssh|
      ssh.sftp.download!(REMOTE_DB, LOCAL_DB)
    end
  end

  ###
  # Copies the local firefly db to the server, overwriting that file
  ###
  def send_db_to_server
    log
    remote_do do |ssh|
      ssh.sftp.upload!(LOCAL_DB, REMOTE_DB)
    end
  end

  ###
  # Loads the local db
  ###
  def load_db
    SQLite3::Database.new(LOCAL_DB)
  end

  ###
  # Copies some new music from ther server to localhost.
  # ratio adjusts the number of albums to get (ratio = 1 is the default)
  # search_params are strings strings to search for. 1 album (max) per search
  # will be included.
  #
  # If block is given, each copied directory will be yielded immediately after
  # it is downloaded.
  ###
  def copy_new_music_from_server(ratio, keep_existing, search_params = [], &block)
    log
    clear_working_dir if !keep_existing
    
    FileUtils.mkdir_p(WORKING)
    log("Downloading music from server")
  
    paths = paths_from_firefly(ratio, search_params)
    paths.each do |path|
      remote_do do |ssh|
        begin
          name = Pathname.new(path)
          dest = "#{ WORKING }/#{ name.parent.basename }/#{ name.basename }"
          FileUtils.mkdir_p(dest)

          ssh.sftp.download!(path.to_s, dest, :recursive => true)
        rescue
          log($!)
        end
      end
      yield if block_given?
      puts '.'
    end

    print "\n"
  end

  ###
  # Clears the working dir, readying it for new music
  ###
  def clear_working_dir
    log
    FileUtils.rmtree(WORKING) if File.exist?(WORKING)
  end

  ###
  # Loads a number of random songs from the firefly db.
  ###
  def paths_from_firefly(ratio, search_params = [])
    paths = []
    paths += paths_with_conditions(ratio * 10)
    paths += paths_with_conditions(ratio * 6, :conditions => [ "time_added > '#{ 2.weeks.ago.to_time.to_i }'" ])
    paths += paths_with_conditions(ratio * 2, :include_played => true, :conditions => [ "time_added > '#{ 2.weeks.ago.to_time.to_i }'" ])
    paths += paths_with_conditions(ratio * 2, :include_played => true, :conditions => [ "time_added <= '#{ 2.weeks.ago.to_time.to_i }'", "time_added > '#{ 2.months.ago.to_time.to_i }'" ])
    paths += paths_with_conditions(ratio * 1, :include_played => true, :conditions => [ "lower(path) like '%classical%'" ])

    search_params.each do |search|
      cols = [ :path, :artist, :genre ]
      conditions = []
      cols.each { |col| conditions << "lower(#{ col }) like '%#{ search.downcase }%'" }
      paths += paths_with_conditions(1, :include_played => true, :conditions => [ conditions.join(' or ') ])
    end
    
    return paths.uniq
  end
  
  ###
  # Returns a list of paths with the given conditions
  ###
  def paths_with_conditions(count, conditions = {})
    sql = sql(conditions)
    columns, *rows = DB.execute2(sql)
    return random_rows(rows, count)
  end
  
  def random_rows(rows, limit)  
    res = []
    while res.length < limit and rows.length > 0
      row = rows[rand(rows.length)]
      path = File.dirname(row.first)
      res << path
    end
    
    return res
  end

  ###
  # Sql to find tracks to copy
  ###
  def sql(options = {})
    sql = "select min(path), album, artist, sum(play_count) as plays, count(*) as count"
    sql += " from songs"
    
    conditions = options[:conditions] || []
    
    sql += " where #{ conditions.join(' and ')}" if conditions.length > 0
    sql += " group by album, artist"
    sql += " having #{ codecs_sql }"
    sql += " and count(*) > sum(play_count)" unless options[:include_played]
    sql += " order by random()"
    
    return sql
  end
  
  def codecs_sql
    codecs = [ "mpeg", "mp4a" ]
    codecs << "flac" unless OPTIONS[:quick]
    codecs = codecs.map { |c| "min(codectype) = '#{ c }'"}
    
    return "(#{ codecs.join(' or ') })"
  end

  def transcode_files
    system("cd #{ WORKING } && nice yaflac2mp3.sh")
    all_of_type(WORKING, "flac").each { |f| File.delete(f) }
  end
  
  ###
  # Adds all music in the working dir to itunes
  ###
  def add_music_to_itunes
    itunes.add(File.expand_path(WORKING).to_s)
  end

  ###
  # Checks itunes is running, exits if not
  ###
  def check_itunes_running
    log
    begin
      itunes.activate
#      itunes.stop
    rescue
      log "Check iTunes is running. Exiting..."  
      Kernel.exit(1)
    end
  end

  ###
  # Copies play counts from itunes and updates the local copy
  # of the firefly db
  ###
  def copy_stats_from_itunes
    log
    copied = false
    
    tracks.each do |t|
      if t.location and t.played_count > 0
        path = album_path(t.location)
        if path.strip != ''
          log "Updating #{ path }"
          sql = "update songs set play_count = (play_count + #{ t.played_count.to_i }) where lower(path) like ?"
          DB.execute2(sql, "%#{ path.downcase }%")
          copied = true
        end
      end
    end
    
    return copied
  end
  
  ###
  # Removes all tracks from itunes
  ###
  def clear_itunes
    log
    while (tracks = tracks_in_playlist("Music")).any?
      tracks.each do |location, track| 
        itunes.delete(track)
      end
    end
  end

  ###
  # Returns the album path of this song 
  # (removing the working dir from the given string)
  ###
  def album_path(path)
    start_pos = "#{ WORKING }".length
    end_pos = (path.rindex(".") - start_pos) + 1
    path[start_pos, end_pos]
  end
  
  def stop_remote_firefly
    log
    system("ssh #{ REMOTE_HOST } sudo /etc/init.d/mt-daapd stop")
  end
  
  def start_remote_firefly
    log
    system("ssh #{ REMOTE_HOST } sudo /etc/init.d/mt-daapd start")
  end
  
  def parse_args
    options = { :ratio => 1.5, :search => [] }
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: fim.rb [options]"

      opts.on("-q", "--quick", "'Quick mode - only downloads smaller files (no flacs)'") do |q|
        options[:quick] = q
      end

      opts.on("--ratio R", Float, "Multiplied against the default number of albums to download. e.g. 2 will download twice as many albums.") do |n|
        options[:ratio] = n
      end

      opts.on("--search x,y,z", Array, "Strings to search for in filenames") do |list|
        options[:search] = list
      end

      opts.on("-k", "--keep", "Keep existing files and only add to the local files") do |k|
        options[:keep] = k
      end
    end
   
    parser.parse!
    return options
  end
end

include FreshTunes
OPTIONS = parse_args

keep = OPTIONS[:keep]

stop_remote_firefly if !keep

check_itunes_running
copy_db_from_server
DB = load_db

if !keep
  send_db_to_server if copy_stats_from_itunes
  start_remote_firefly
  clear_itunes
end

 copy_new_music_from_server(OPTIONS[:ratio], keep, OPTIONS[:search]) do
   transcode_files
   add_music_to_itunes
 end

 add_permanent_files_to_itunes

DB.close


