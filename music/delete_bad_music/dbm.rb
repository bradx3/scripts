#!/usr/bin/ruby
require 'pathname'


ROOT = "/Volumes/dib/brad/Music/audio"
BAD = [ "lsd connection", 'andy smith', 'think different', 'urbanrenewalprogam', 'dangermouse ep', 'marie antoinette', 'love, peace & poetry', 'crime and punishment', 'ghostface meets mf doom - oper' ]

DELETE =  []

def recurse(dir)
  for child in dir.children
    next unless child.directory?
    
    # if it is a bad filename and if there is only only one subdir
    if bad?(child.basename) and child.parent.children.length == 1
      DELETE << child
      
    elsif child.children.length == 0
      # empty dirs
      DELETE << child
    end
    
    recurse(child)
  end
end

def bad?(name)
  name = name.to_s.downcase
  BAD.each do |bad|
    return true if name.index(bad)
  end
  return false
end

recurse(Pathname.new(ROOT))
DELETE.sort.each do |dir|
  puts dir
  dir.rmtree
end