#!/usr/bin/ruby

require 'pathname'


def recurse(dir)
  for child in dir.children
    name = child.basename.to_s.downcase
    
    if child.directory?
      recurse(child)
    elsif name[-4, 4] == '.log' and bad_log?(child)
      puts name
    end
  end
end

def bad_log?(path)
  log = path.read
  return log.index("There were errors") || !log.index("No errors occurred")
end

recurse(Pathname.new(ARGV[0]))