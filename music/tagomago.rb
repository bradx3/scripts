#!/usr/bin/ruby
require 'my_tools'

if ARGV.length == 0 or ARGV.length % 2 != 1
  puts "Usage: #{ Pathname.new(__FILE__).basename } directory tag_name value [tag_name value]"
  Kernel.exit(1)
end

dir, tags = load_tago_mago_args
set_tags_for_path(dir, tags, true)
