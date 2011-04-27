#!/usr/bin/env ruby

require 'pathname'
require 'rubygems'
require 'id3lib'
require 'readline'
require "my_tools.rb"
require 'optparse'

DOWNLOADS = [ 
              [  :music, "/Users/brad/Downloads/Torrents/Complete/" ],
              [  :music, "/Volumes/Media/Torrents/Downloads" ],
              [ :video, "/Users/brad/Downloads/Torrents/Complete/" ],
              [ :video, "/Users/brad/Movies/" ]
            ]
COPIED = "green"

QUEUE = []
GENRES = {} 
###
# Prompts the user for any information and
# queues the given file for a copy
###
def queue(file, type)
  label = run_cmd(cmd("getlabel", file)).join("\n").strip
  
  if label != COPIED
    if type == :music
      queue_music(file)
    elsif type == :video
      queue_video(file)
    end
  end
end

###
# Queues up copying across music in the given dir
###
def queue_music(dir)
  return unless dir.directory? and contains_any?(dir, :flac, :mp3)
  
  puts dir
  artist = get_artist(artist(dir))
  destination = get_music_destination
  dest = "#{ destination }/#{ artist }"
#  full_dest = "/Volumes/Samba/clamps/Music/#{ dest }"
#  genre = GENRES[artist] || genre(full_dest) || prompt("Genre", genre_names)
#  GENRES[artist] = genre
 
  tags = {}
#  tags = { :genre => genre, :artist => artist }
  remote_dest = "#{ REMOTE_MUSIC_PATH }#{ dest }/#{ Pathname.new(dir).basename }"
  
  QUEUE << [ dir, remote_dest, tags ]
  puts ''
end

###
# Copy general video downloaded content
###
def queue_video(file)
  if video?(file) or contains_any?(file, :avi, :mpg, :mkv, :rm, :mp4)
    puts ''
    puts file
    local = "/Volumes/Samba/clamps/"
    dir = prompt_for_path(local)
    
    remote_path = "#{ REMOTE_VIDEO_PATH }#{ dir[local.length, dir.length] }#{ Pathname.new(file).basename }"
    QUEUE << [ file, remote_path ]
  end
end

###
# Returns true if the given file is video
###
def video?(file)
  ext = File.extname(file)
  ext = ext[1, ext.length] if ext
  return ext == "avi" || ext == "mpg" || ext == 'mkv' || ext == 'rm' || ext == 'mp4'
end

###
# Returns the command to mark the given file as copied
###
def mark_as_copied(file)
  cmd = cmd("setlabel", [ file, COPIED ])
  system(cmd)
end

###
# Figures out the destination to copy the last 
# video too
###
def get_video_destination(dir, prompt = 'directory > ')
  dir_prefix = "#{ dir }".length
  Readline.completion_case_fold = true
  Readline.completion_proc = lambda do |prefix|
    path = "#{ dir }#{ prefix }*"
    list = Dir.glob(path)
    list = list.map { |f| File.directory?(f) ? "#{ f }/" : f }
    list = list.map { |f| f[dir_prefix, f.length] }
    list = list.sort { |f1, f2| f1.downcase <=> f2.downcase }
    list
  end 
  dest = dir + Readline.readline(prompt)
  puts dest
  return dest
end

###
# Prompts for the music destination to copy to
###
def get_music_destination
  dest = Readline::readline("Destination [G/c]: ")
  return dest.downcase == 'c' ? 'Classical' : 'General'
end

def get_artist(artist)
  new_artist = Readline::readline("Artist [#{ artist }]: ")
  return new_artist.strip == '' ? artist : new_artist
end

def parse_args
  options = {}
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: cdm.rb [options]"

    opts.on("--count C", Integer, "The number of downloads to copy this go. Defaults to all.") do |n|
      options[:count] = n
    end
  end
  
  parser.parse!
  return options
end

options = parse_args

max = (options[:count] || 0).to_i

DOWNLOADS.each do |type, dir|
  children = Pathname.new(dir).children
  children.each do |d|
    break if max > 0 and QUEUE.length >= max
    queue(d, type) 
  end
end

QUEUE.each do |src, dest, tags|
  terminal_hr

  remote_do do |ssh|
    src_pathname = Pathname.new(src)
    puts "Copying #{ src_pathname.basename } to #{ dest }"
    
    puts src
    puts dest
    run_cmd(cmd("mkdir -p", Pathname.new(dest).parent))
    # ssh.sftp.mkdir!(.parent.to_s) rescue nil
    ssh.sftp.upload!(src.to_s, "#{ dest }", :via => :scp)
    
    set_tags_for_path(dest, tags) if tags and tags.length > 0
  end
  
  mark_as_copied(src)
end
