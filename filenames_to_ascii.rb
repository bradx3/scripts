#!/usr/bin/ruby

require 'iconv'
require 'find'
require 'fileutils'
require 'pathname'

dir = File.expand_path(ARGV[0])
puts "Fixing #{ dir }"

def convert(str)
  Iconv.conv('ascii//IGNORE', 'utf-8', str)
end

Find.find(dir) do |path|
  next if File.directory?(path)
  next if !File.exists?(path)

  converted = convert(path)
  if converted != path
    from = Pathname.new(path) 
    puts "Renaming #{ from.basename }"
    from.rename(converted)
  end
end
