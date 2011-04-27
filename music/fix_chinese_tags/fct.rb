#!/usr/bin/ruby

require "my_tools.rb"
# require "../../lib/my_tools.rb"

unless ARGV[0]
  puts "Usage #{ __FILE__ } directory"
  exit(1)
end

dir = File.expand_path(ARGV[0])
files = all_of_type(dir, :mp3)
files.each do |f|
  puts "Done #{ f.to_s[dir.length + 1, f.length] }" if fix_id3_tag(f)
end
