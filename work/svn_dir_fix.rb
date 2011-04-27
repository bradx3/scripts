#!/usr/bin/ruby

require 'pathname'

def recurse(dir)
  for child in dir.children
    next unless child.directory?              # ignore files
    next if child.basename.to_s == '.svn'     # ignore .svn directory
    next unless (child + '.svn').exist?       # ignore unadded directories

    [ 'tmp', 'text-base', 'entries' ].each do |svn_dir|
      tmp_dir = child + '.svn/' + svn_dir
      if !tmp_dir.exist?
        puts tmp_dir
        tmp_dir.mkdir
      end
    end
    
    recurse child
  end
end

recurse Pathname.new(ARGV[0])