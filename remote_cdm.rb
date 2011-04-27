#!/usr/bin/env ruby

require "my_tools.rb"
require "ruby-debug"

REMOTE_HOME = "/home/brad"
REMOTE_DOWNLOADS = "#{ REMOTE_HOME }/Media/Torrents/Downloads"
REMOTE_MOVIES = "#{ REMOTE_HOME }/Media/"
REMOTE_MUSIC = "#{ REMOTE_HOME }/Media/Music"
LOCAL_HOME = "/Volumes"
LOCAL_MOVIES = REMOTE_MOVIES.gsub(REMOTE_HOME, LOCAL_HOME)
COPIED = "green"

class String
  def local
    self.gsub(REMOTE_HOME, LOCAL_HOME)
  end

  def remote
    self.gsub(LOCAL_HOME, REMOTE_HOME)
  end
end

# Returns true if the given files has already been copied
def copied?(file)
  file = "#{ REMOTE_DOWNLOADS }/#{ file }".local
  label = run_cmd(cmd("getlabel", file)).join("\n").strip
  label == COPIED
end

def find_files(dir, *extensions)
  match = extensions.map { |ext| "-iname \"*.#{ ext }\"" }
  match = match.join(" -o ")
  cmd = "find \"#{ dir }\" #{ match }"
  run_cmd(cmd)
end

def music?(dir)
  find_files(dir, :flac, :mp3, :m4a).present?
end

def video?(dir)
  find_files(dir, :avi, :mpg, :mkv, :rm, :mp4).present?
end

def queue(dir)
  terminal_hr
  puts dir
  dir = "#{ REMOTE_DOWNLOADS }/#{ dir }"

  if video?(dir)
#    path = LOCAL_MOVIES.gsub("Movies/", "")
    dest = prompt_for_path(LOCAL_MOVIES).remote

  elsif music?(dir)
    destination = "Automatically Add to iTunes"
    dest = "#{ REMOTE_MUSIC }/#{ destination }/"
  end

  @queue ||= []
  @queue << [ dir, dest ] if dest.present?
end

def get_music_destination
  dest = Readline::readline("Destination [G/c]: ")
  return dest.downcase == 'c' ? 'Classical' : 'General'
end

def get_artist(artist)
  new_artist = Readline::readline("Artist [#{ artist }]: ")
  return new_artist.strip == '' ? artist : new_artist
end

def mark_as_copied(file)
  cmd = cmd("setlabel", [ file, COPIED ])
  system(cmd)
end

def run
  files = remote_ls("home", REMOTE_DOWNLOADS)
  files = files.select { |f| !copied?(f) }

  remote_do("clamps") do |ssh|
    files.each { |dir| queue(dir) }

    terminal_hr

    @queue.each do |src, dest|
      puts "Copying #{ src }"
      run_cmd(cmd("cp -R", [ src, dest ]))
      mark_as_copied(src.local)

      # if dest.index(REMOTE_MUSIC)
      #   # add to itunes
      #   dir = "#{ dest.local }#{ File.basename(src) }"
      #   cmd = cmd("add_to_itunes", [ dir ])
      #   cmd = "#{ cmd } > /dev/null 2>&1"
      #   system(cmd)
      # end      
    end
  end
end

run
