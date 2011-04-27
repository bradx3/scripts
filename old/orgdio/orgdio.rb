#!/usr/bin/ruby

require 'rubygems'
require 'id3lib'
require 'fileutils'
require 'yaml'
require 'optparse'

class AudioFile
  GAIN_CMDS = {
    :mp3 => { :apply => "'mp3gain -c -p -o -q \"' + @filename + '\"'", 
      :check => "'mp3gain -s c \"' + @filename + '\" | grep -i gain'" },
    :flac => { :apply => "'metaflac --add-replay-gain --preserve-modtime \"' + @filename + '\"'",
      :check => "'metaflac \"' + @filename + '\" --list |grep -i replaygain_track_gain'" }
  }
  
  SUPPORTED_EXTENSIONS = [ 'mp3', 'flac' ]
  SHARED_TAGS = [ 'artist', 'album', 'year' ]
  
  @@last_values = {}
  
  attr_accessor :force_tag_prompt, :force_various_artists, :delete_files_after_move, :filename
  
  ###
  # Clears any stored values used for prompts.
  # This should probably be called after each dir.
  ###
  def self.clear_values
    @@last_values = {}
  end
  
  ###
  # Sets up this audiofile.
  # 
  # format should be a string containing the full format 
  # and path of where the file should end up.
  # Tag values should be in % chars (%artist%, %year%, etc)
  ###
  def initialize(filename, format)
    @filename = filename
    @extension = File.extname(@filename)[1,4].downcase
    @tag = ID3Lib::Tag.new(@filename, ID3Lib::V_ALL) if @extension == 'mp3'
    @format = format
  end
  
  ###
  # Organise this file
  ###
  def organise
    update_tags
    update_replaygain
    update_filename
  end
  
  ###
  # Handles calls to tag(tag_name)
  ###
  def method_missing(method)
    if method.to_s.match(/(.+)_tag$/)
      tag_name = $~[1]
      return tag(tag_name)
    else
      super(method)
    end
  end
  
  ###
  # Returns the value of the tag with the
  # given name, or nil if no tag exists
  ###
  def tag(tag_name)
    val = send "#{ @extension }_tag", tag_name
    
    if tag_name == 'track'
      # to_i will strip off anything after a slash (like in 1/12)
      val = val.to_i
      if val.to_s.length == 1
        val = "0#{ val }" 
      end
    end
    
    if !val.nil?
      val = val.to_s
      # I'm not sure why these characters show up, but they're bad, so get rid of them.
      val.gsub!("#{ 255.chr }", '')
      val.gsub!("#{ 254.chr }", '')
      return val
    end
  end
  
  ###
  # Sets the given tag data and saves this
  # file to disk
  ###
  def set_tag(tag_name, tag_value)
    send("set_#{ @extension }_tag", tag_name, tag_value)
  end
  
  ###
  # Returns the tags required as per the
  # formatting string
  ###
  def required_tags
    res = []
    
    format = @format
    matches = format.match(/.*(%(.+)%).*/)
    
    while !matches.nil?
      tag_name = matches[2]
      res << tag_name
      format = format.sub(matches[1], tag_name) 
      
      matches = format.match(/.*(%(.+)%).*/)
    end
    
    # clean up the results
    res.delete('extension')
    res = res.insert(0, res.delete('track')) # track should be first in the list
    res = SHARED_TAGS + res
    res = res.uniq.compact
    return res
  end
  
  private
  
  ###
  # Checks to see if the file is stored
  # in the correct place in the file system.
  # i.e. is the name correct? is the dir correct?
  ###
  def update_filename
    new_file = File.expand_path(correct_filename)
    old_file = File.expand_path(@filename)
    if old_file != new_file
      FileUtils.mkdir_p File.dirname(new_file)
      FileUtils.copy old_file, new_file
      @filename = new_file
      
      if @delete_files_after_move
        File.delete(old_file)
      end
    end
  end
  
  ###
  # Returns what the name of the file should be
  # (according to tags and @filename) 
  ###
  def correct_filename
    res = @format
    matches = res.match(/.*(%(.+)%).*/)
    
    while !matches.nil?
      tag_name = matches[2]
      val = (tag_name == 'extension') ? @extension : tag(tag_name)
      val = val.to_s
      val.gsub!('/', '-')
      res = res.sub(matches[1], val) 
      
      matches = res.match(/.*(%(.+)%).*/)
    end
    
    return res
  end
  
  ###
  # Checks for required tags and re-tags.
  ###
  def update_tags
    updated = false
    
    required_tags.each do |tag_name|
      tag_val = send("#{ tag_name }_tag")
      
      if !@force_various_artists and SHARED_TAGS.include?(tag_name) and @@last_values[tag_name]
        tag_val = @@last_values[tag_name]
        
      elsif @force_tag_prompt || !valid_tag?(tag_name, tag_val)
        print "#{ File.basename(@filename) } #{ tag_name }? #{ tag_prompt(tag_name) }: "
        new_val = readline.strip
        new_val = tag_default(tag_name) if new_val == ''
        
        tag_val = new_val
        
      end
      
      set_tag(tag_name, tag_val)      
    end
    
    @tag.update!(ID3Lib::V_ALL) if @tag
    
    required_tags.each { |tag_name| @@last_values[tag_name] = send("#{ tag_name }_tag") }
  end
  
  ###
  # Returns a string to let the user know what
  # the tag_default is
  ###
  def tag_prompt(tag_name)
    default = tag_default(tag_name)
    if !default.nil?
      return "[#{ default }]"
    end
  end
  
  ###
  # Returns a suggested value for the given tag_name.
  ###
  def tag_default(tag_name)
    if tag_name == 'track'
      val = @@last_values['track']
      res = (val.to_i + 1) if !if val.nil?
    end
  elsif tag_name == 'title'
    res = filename_to_title
  else
    res = @@last_values[tag_name] || tag(tag_name)
  end
  
  return res
end

###
# Attempts to turn this files name
# into a usable title
###
def filename_to_title
  filename = File.basename(@filename)
  res = filename[0, filename.length - @extension.length - 1]
  
  if res.match(/\d+\s?-?\s*(.*)/)
    # if the file starts with some numbers, strip them off
    res = $~[1]
  end 
  
  return res
end

###
# Returns true if the tag_val provided
# is a valid value for the tag_name.
###
def valid_tag?(tag_name, tag_val)
  !tag_val.nil? && tag_val.to_s.strip != ''
end

###
# Gets the mp3 tag with given name
###
def mp3_tag(name)
  @tag.send name
end

###
# Sets the mp3 tag with given name
###
def set_mp3_tag(name, value)
  @tag.send "#{ name }=", value
end  

###
# Gets the flac tag with the given name
###
def flac_tag(name)
  name = 'tracknumber' if name == 'track'
  name = 'date' if name == 'year'
  
  cmd = "metaflac \"#{ @filename }\" --list |grep -i #{ name }="
  result = %x[#{ cmd }]
  if !result.nil? and result.strip != ''
    result = result[result.index('=') + 1, result.length].strip
    return result
  end
end

###
# Sets the flac tag with given name
###
def set_flac_tag(name, value)
  cmd = "metaflac \"#{ @filename }\" --remove-tag=#{ name }"
    %x[#{ cmd }]
  
  cmd = "metaflac \"#{ @filename }\" --set-tag=#{ name }=\"#{ value }\""
    %x[#{ cmd }]
end    

###
# check file has replaygain info
###
def replaygained?
  check_cmd = eval(GAIN_CMDS[@extension.to_sym][:check])
  
  result = %x[#{ check_cmd.to_s }]
  
  return result.strip != ''
end

###
# Update replaygain tags in the given file.
###
def update_replaygain
  if !replaygained?
    check_cmd = eval(GAIN_CMDS[@extension.to_sym][:apply])
    result = %x[#{ check_cmd.to_s }]
  end 
end

end

class Orgdio

def initialize(src_dir, format, options = {})
  @src_dir = src_dir
  
  @format = format
  @delete_files_after_move = !options[:keep_after_move]
end


###
# Starts orgdio
###
def run
  puts "Loading..."
  
  directories_to_process.each do |dir|
    puts "\r\n\r\nOrganising #{ neat_dir_name(dir) }\r\n"
    filenames = audio_files_in_dir(dir).sort { |f1, f2| File.basename(f1) <=> File.basename(f2) }
    initial_dir = File.dirname(filenames.first)
    files = filenames.map { |filename| AudioFile.new(filename, @format) }
    
    force_prompt = force_tag_prompt(files)
    force_va = force_various_artists if force_prompt      
    
    puts ''
    
    files.each_with_index do |af, i|
      af.force_tag_prompt = force_prompt
      af.force_various_artists = force_va
      af.delete_files_after_move = @delete_files_after_move
      
      af.organise
      
      print '.'
      $stdout.flush
      
      if i == 0 and force_prompt and !force_va
        # just double check tags. maybe it was just the artist, etc which was busted
        auto_update_shared_tags(files)
        
        force_prompt = force_tag_prompt(files[1, files.length], 'Do these tags look ok now?')
      end
    end
    
    ending_dir = File.dirname(files.last.filename)
    
    clean_up_dirs(initial_dir, ending_dir)
    AudioFile.clear_values
  end
  
  puts "\r\n\r\nDone"
end

private

###
# Run through the files and set the shared tag values
# to the same thing. The values in the first file
# are used.
###
def auto_update_shared_tags(files)
  AudioFile::SHARED_TAGS.each do |tag_name|
    value = files.first.tag(tag_name)
    files[1, files.length].each do |af|
      af.set_tag(tag_name, value)
    end
  end
end

###
# Shows the tags for the given files and asks whether 
# they look ok
###
def force_tag_prompt(files, msg = nil)
  print_tag_values(files)
  
  puts ''
  msg = msg || 'Do these tags look ok?'
  print "#{ msg } [Y/n]: "
  force_prompt = readline.strip.downcase == 'n'
  
  return force_prompt
end

###
# Asks whether this album is a various artists album.
# Returns true if it is, false otherwise.
###
def force_various_artists
  print "Is this a various artists album? [y/N]: "
  return readline.strip.downcase == 'y'
end

###
# Prints the current tag values for the given
# files
###
def print_tag_values(files)
  required_tags = files.first.required_tags
  to_delete = []
  
  required_tags.each do |tag_name|
    if all_same_value?(files, tag_name)
      to_delete << tag_name
      val = files.first.send("#{ tag_name }_tag")
      puts "#{ tag_name } = #{ val }"
    end
  end
  required_tags = required_tags - to_delete
  
  files.each do |file|
    vals = [] 
    required_tags.each do |tag_name|
      val = file.send("#{ tag_name }_tag")
      vals << "#{ tag_name } = #{ val }"
    end
    
    puts vals.join(', ')
  end
end

###
# Checks to see if the given files all
# have the same value for the given tag name.
# 
# Returns true if so
###
def all_same_value?(files, tag_name)
  last_val = nil
  files.each do |file|
    val = file.send("#{ tag_name }_tag")
    if last_val and val != last_val
      return false
    else
      last_val = val
    end
  end
end


###
# Clean up the dir name so it's printable.
###
def neat_dir_name(dir)
  dir[@src_dir.length + 1, dir.length]
end

###
# Returns a list of directories which have
# audiofiles in them (and hence should be
# processed).
###
def directories_to_process
  dirs = {}
  audio_files_in_dir(@src_dir).each do |f|
    dir = File.dirname(f)
    dirs[dir] = true unless dirs.key?(dir)
  end
  
  return dirs.keys.sort
end

###
# Copies any non-audio files to the new dir.
# If no files are left in the initial_dir after
# doing that, it will be deleted
###
def clean_up_dirs(initial_dir, ending_dir)
  if initial_dir != ending_dir 
    leftover_files = File.join(initial_dir, '*')
    
    Dir.glob(leftover_files).each do |src|
      filename = src[initial_dir.length, src.length]
      dest = File.join(ending_dir, filename)
      FileUtils.cp_r(src, dest)
    end
  end  
  
  if @delete_files_after_move
    FileUtils.rm_r(initial_dir)
  end
end

###
# Returns a list of the audio files in the
# given directory.
###
def audio_files_in_dir(dir)
  extensions = []
  AudioFile::SUPPORTED_EXTENSIONS.each { |e| extensions << "*.#{ e }" }
  search = File.join(dir, "**/{" + extensions.join(',') + "}")
  files = Dir.glob(search, File::FNM_CASEFOLD | File::FNM_PATHNAME)
  
end
end

# parse options
options = {}
banner = "Usage: orgdio.rb -f format_string [options]"
OptionParser.new do |opts|
opts.banner = banner

opts.on("-f", "--format FILE_FORMAT", 'The FILE_FORMAT to organise files into.') do |format|
  options[:format] = format
end

opts.on("-k", "--keep-files", "Keep files after organise") do |keep|
  options[:keep_after_move] = keep
end
end.parse!

if !options[:format]
  puts banner
  exit
end

# starts the organising
orgdio = Orgdio.new(Dir.pwd, options[:format], options)
orgdio.run