#!/usr/bin/ruby
require 'pathname'

def recurse(dir)
  for child in dir.children
    next unless child.directory?
    
    if mp3s(child).length > 0
      cmd = "mp3gain -w -c #{ files_to_full_paths(child, mp3s(child)) }"
    elsif flacs(child).length > 0
      cmd = "metaflac --list \"#{ child }/#{ flacs(child).first }\" | grep -i -q replaygain"
      if system(cmd)
        # puts "tags found in #{ child }"
        cmd = nil
      else
        cmd = "metaflac --add-replay-gain #{ files_to_full_paths(child, flacs(child)) }"
      end
    end
    
    puts "Gaining #{ child }"
    system("nice #{ cmd }") if cmd
    
    recurse(child)
  end
end

def files_to_full_paths(child, files)
  return files.map { |f| "\"#{ child }/#{ f }\"" }.join(' ')
end

def mp3s(path)
  return files_ending_with(path, "mp3") || []
end

def flacs(path)
  return files_ending_with(path, "flac") || []
end

def files_ending_with(path, ending)
  return path.entries.select do |f|
    file = f.to_s.downcase
    f if file[-ending.length, file.length] == ending
  end
end

recurse(Pathname.new(ARGV[0]))