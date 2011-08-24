#!/usr/bin/env ruby

require "open-uri"
require "rubygems"
require "hpricot"
require "ruby-debug"
require "readline"

class FlickrWallpapers
  DEST = File.expand_path("~/Pictures/Wallpapers/")
  URLS = [
          "http://api.flickr.com/services/feeds/photos_public.gne?id=10888427@N06&lang=en-us&format=atom",
          "http://api.flickr.com/services/feeds/groups_pool.gne?id=644548@N21&lang=en-us&format=atom",
          "http://api.flickr.com/services/feeds/groups_pool.gne?id=40961104@N00&lang=en-us&format=atom"
         ]

  def run
    URLS.each do |url|
      @images = parse_feed(url)
      while @images.any?
        preview_current_file
        prompt
      end
    end
  end

  def prompt
    response = Readline.readline("Keep picture? [y/N/r/i/q] ").strip.downcase
    if response == "q"
      exit(0)
    elsif response == "r"
      preview_current_file
      prompt
    elsif response == "n" or response == ""
#      delete_current_file
      @images.shift
    elsif response == "i"
      system("open #{ @images.first[:url] }")
      prompt
    elsif response == "y"
      get_current_file
      @images.shift
    end

    # for some reason preview doesn't open files all the time, 
    # but if I kill it it works fine
    system("killall Preview &> /dev/null")
  end

  def get_current_file
    image = @images.first
    image_url = image[:image]

    open(image_url, "User-Agent" => "Ruby/#{RUBY_VERSION}") do |remote_image|
      filename = image[:local_image]

      open(filename, 'w') do |file|
        file.write(remote_image.read)
      end

      open("#{ filename }.txt", 'w') do |file|
        file.write(@images.first[:url])
      end
    end
  end

#  def delete_current_file
#    image = @images.shift[:local_image]
#    File.delete(image)
#    File.delete("#{ image }.txt")
#  end

  def preview_current_file
    system("open -a Opera -g #{ @images.first[:url] }")
  end

  def parse_feed(url)
    doc = Hpricot(open(url))
    images = []
    doc.search("entry").each do |item|
      links = item.search("link")
      url = links.detect { |l| l["rel"] == "alternate" }["href"]
      image = links.detect { |l| l["rel"] == "enclosure" }["href"]
      images << { 
        :url => url, :image => image,
        :local_image => "#{ DEST }/#{ File.basename(image) }"
      }
    end

    images.select { |img| !File.exists?(img[:local_image]) }
  end
end

if ENV["_"] == __FILE__
  FlickrWallpapers.new.run
end
