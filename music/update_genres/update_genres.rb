#!/usr/bin/ruby

require "../../lib/my_tools.rb"

CONFIG_FILE = "~/tmp/update_genres.config"

dir = ARGV[0]
if dir.nil?
  puts "usage: #{ __FILE__ } directory"
  Kernel.exit(1)
end

start = load_config(CONFIG_FILE)
if start and Pathname.new(start).parent.to_s != File.expand_path(dir)
  start = nil
  puts "Ignoring old status..."
end

update_genre(dir, start)
