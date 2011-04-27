#!/usr/bin/ruby

require 'my_tools'

if ARGV.length == 0 or ARGV.length % 2 != 1
  puts "Usage: #{ Pathname.new(__FILE__).basename } remote_directory tag_name value [tag_name value]"
  Kernel.exit(1)
end

dir, tags = load_tago_mago_args

remote_do do
  path = "#{ REMOTE_MUSIC_PATH }/#{ dir }"
  set_tags_for_path(path, tags)
end