#!/usr/bin/env ruby

require "rubygems"
require "ruby-debug"

SRC_FILE = File.expand_path("~/tmp/Music.txt")
FILE = File.expand_path("~/tmp/Music.tab")

@itunes_files = {}
@fs_files = []

def convert_file
  tmp = "/tmp/music.tmp"
  system("iconv -f UTF-16 -t UTF-8 #{ SRC_FILE } >> #{ tmp }")
  system("tr '\r' '\n' < #{ tmp } > #{ FILE }")
end

def load_itunes_files
  File.open(FILE) do |f|
    begin
      while line = f.readline
        location = line.split("\t")[26]
        next if location.nil?
        location = location.strip
        location = location.gsub(":", "/")
        location = location.gsub("Media/Music", "")
        @itunes_files[location] = true
      end
    rescue EOFError
    end
  end
end

def load_fs_files
  files = `find /Volumes/Media/Music -type f`.split("\n")
  exts = [ ".mp3", ".wma", ".m4a" ]
  files.each do |f|
    next if !exts.index(File.extname(f.downcase))
    file = f.gsub("/Volumes/Media/Music", "")
    @fs_files << file
  end
end

convert_file
load_itunes_files
load_fs_files

@fs_files.each do |f|
  if !@itunes_files.has_key?(f)
    puts "Missing file #{ f }"
  end
end
