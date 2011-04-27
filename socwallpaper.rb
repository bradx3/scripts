#!/usr/bin/env ruby

require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'Pathname'
require "readline"

URL = 'http://socwall.com/browse/index.php?wpSortby=8'
DEST = File.expand_path("~/Pictures/Wallpapers/")

def filename_for(count)
  "#{ DEST }/#{ count }.png"
end

def clear_old_images(count)
  while count > 0
    path = Pathname.new(filename_for(count))
    if path.exist?
      cmd = "open -a Preview -g #{ path }"
      puts cmd
      system(cmd)
      keep = Readline.readline("Keep picture? [y/N/r] ")
      if keep.downcase == "y"
        File.rename(path, "#{ DEST }/#{ Time.now.to_i }.png")
      elsif keep.downcase == "r"
        # retry
        clear_old_images(count)
      else
        path.delete 
      end
    end

    # for some reason preview doesn't open files all the time, 
    # but if I kill it it works fine
    system("killall Preview &> /dev/null")
    sleep 1
    count -= 1
  end
end

def download_images(count)
  while count > 0
    doc = Hpricot(open(URL))
    
    doc.search("div.wpThumbnail").each do |thumb|
      next if count == 0
      
      thumbnail = thumb.at("img")['src']
      image = thumbnail.gsub(/\/tb_/, '/')
      image = image.gsub(" ", "%20")
      
      remote_image = open(image, "User-Agent" => "Ruby/#{RUBY_VERSION}")
      local_image = open(filename_for(count), 'w')
      local_image.write(remote_image.read)
      
      remote_image.close
      local_image.close
      
      count -= 1
    end
  end
end

count = (ARGV[0] || 10).to_i

clear_old_images(count)
download_images(count)
