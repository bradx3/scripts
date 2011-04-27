require 'rubygems'
require 'pathname'
require 'readline'
require 'net/ssh'
require 'net/sftp'
#require "rbosa"
require 'active_support'

REMOTE_MUSIC_PATH = "/home/brad/Media/Music/"
REMOTE_VIDEO_PATH = "/home/brad/Media/"
PERMANENT_ITUNES_FILES = File.expand_path("~/Music/Local/")

module ProcessTools
  ###
  # Returns a string containing the given cmd and params
  # as a runnable command (with escaping, etc)
  ###
  def cmd(cmd, params = [])
    params = [ params ].flatten
    params = params.map do |p| 
      p.to_s.index("\"") ? param_clean(p) : p
    end
    params = params.map { |p| "\"#{ p }\"" }
    return "#{ cmd } #{ params.join(' ') }"
  end
  
  ###
  # Runs the given str in a shell.
  # Splits the result into lines and returns
  # them in an array.
  ###
  def run_cmd(str)
    if @ssh
#      puts "REMOTE Running: #{ str }"
      lines = @ssh.exec!(str) || ''
      return lines.split("\n").map { |l| l.strip }
    else
      p = IO.popen(str)
      res = p.readlines.map { |l| l.strip }
      p.close
      return res
    end
  end
  
  ###
  # Cleans a str so it is suitable for use as a param in 
  # a normal shell
  ###
  def param_clean(str)
    str = str.to_s.gsub(/(")/) { |s| '\"' }
    return "\"#{ str }\""
  end
  
  ###
  # Cleans a str so it is suitable for use as a scp path
  ###
  def scp_clean(str)
    str = str.to_s.gsub(/([\W\/])/) { |s| "\\#{ s }"}
    return str
  end
  
  ###
  # Returns an array of files in the remote dir
  ###
  def remote_ls(host, path)
    cmd = "ssh #{ host } ls -F \"#{ scp_clean(path) }\"/"
    IO.popen(cmd).readlines.map { |l| l.strip }
  end
  
  ###
  # Executes the given block in a remote
  # ssh session
  ###
  def remote_do(host = "home", &block)
    Net::SSH.start(host, 'brad') do |ssh|
      # run_cmd will use exec remotely if @ssh is set
      @ssh = ssh 
      yield(ssh)
      # set it back because we're leaving the block
      @ssh = nil
    end
  end
  
end

module MusicTools
  MUSIC_FILE_TYPES = [ 'mp3', 'flac' ]
  
  ###
  # Returns the dir and any tag settings from the command line
  # params.
  ###
  def load_tago_mago_args
    dir = ARGV.shift
    tags = {}
    while ARGV.any?
      name = ARGV.shift
      value = ARGV.shift
      tags[name] = value
    end
    
    return dir, tags
  end
  
  ###
  # Returns a command that will set the given tags values
  # on file when run.
  ###
  def tag_cmd_for(file, tags)
    if extension(file) == 'mp3'
      params = []
      tags.each do |tag_name, value|
        tag_name = tag_name.to_s
        tag_name = 'song' if tag_name.downcase == 'title'
        value = genre_id(value) if tag_name.downcase == "genre"
        params << "--#{ tag_name } \"#{ value }\""
      end
      return "id3v2 #{ params.join(' ') } #{ param_clean(file) }"
      
    elsif extension(file) == 'flac'
      params = []
      tags.each do |tag_name, value|  
        tag_name = tag_name.to_s
        tag_name = tag_name.upcase
        tag_name = 'date' if tag_name == 'YEAR'
        params << "--remove-tag=#{ tag_name }"
        params << "--set-tag=#{ tag_name }=\"#{ value }\""
      end
      return "metaflac #{ params.join(' ') } #{ param_clean(file) }"
    end
  end
  
  ###
  # Sets the tags for the given audio file.
  # Tags should be hash like:
  # :artist => 'FFF', :year => '1986', :title => 'song title', :genre => 'Rock'
  ###
  def set_tags(file, tags)
    cmd = tag_cmd_for(file, tags)
    run_cmd(cmd) if cmd
  end
  
  ###
  # Sets the tags for all audio files under path.
  ###
  def set_tags_for_path(path, tags, verbose = false)
    files = []
    MUSIC_FILE_TYPES.each { |t| files += all_of_type(path, t) }
    files.each do |f| 
      puts f if verbose
      set_tags(f, tags)
    end
  end
  
  ###
  # Returns an array containing all id3v2 genres.
  # Each element is a hash containing:
  #   :id
  #   :name
  ###
  def all_genres
    if !@all_genres
      lines = run_cmd("id3v2 -L")
      genres = lines.map do |line|
        line = line.split(":")
        { :id => line.first.to_i, :name => line.last.strip }
      end
    
      @all_genres = genres.sort { |g1, g2| g1[:name] <=> g2[:name] }
    end
    return @all_genres
  end
  
  ###
  # Returns an array of id3v2 genre names
  ###
  def genre_names
    @genre_names ||= all_genres.map { |h| h[:name] }
  end
  
  ###
  # Returns the genre id for the given name
  ###
  def genre_id(genre_name)
    genre = all_genres.detect { |g| g[:name].downcase == genre_name.downcase }
    genre[:id] if genre
  end
  
  ###
  # Prompts and updates the genre of file in the given dir.
  # If start if given, directory < start will be skipped
  ###
  def update_genre(dir, start = nil)
    puts dir
    for artist in Pathname.new(dir).children.sort
      next unless artist.directory?
      next unless start.nil? or start < artist.to_s

      if artist.basename.to_s.downcase == "various artists"
        update_genre(artist)
      else
        old_genre = genre(artist)

        puts artist.basename
        new_genre = prompt("Genre", genre_names, :default => old_genre)
        new_genre = all_genres.detect { |g| g[:name].downcase == new_genre.downcase }

        set_genre(artist, new_genre[:id])
        puts "#{ artist.basename } set to #{ new_genre[:name] }"
        puts "\n\n"
      end

      save_config(CONFIG_FILE, artist)
    end
  end
  
  ###
  # Returns the genre of the first audio file
  # found in the given dir (or subdirs)
  ###
  def genre(path)
    mp3 = first_of_type(path, "mp3")
    results = run_cmd(cmd('id3v2 -l', mp3)) if mp3
    return tag_value("Genre", results)
  end
  
  ###
  # Returns the artist of the first audio file
  # found in the given dir (or subdirs)
  ###
  def artist(path)
    mp3 = first_of_type(path, "mp3")
    if mp3
      results =  run_cmd(cmd("~/bin/artist.py", mp3))
      return results.first if results.any?
    end
    
    flac = first_of_type(path, "flac")
    if flac
      results = run_cmd("metaflac --show-tag=ARTIST #{ param_clean(flac) }")
      return results.first.gsub(/artist=/, '') if results.any?
    end
  end
  
  ###
  # Looks for the tag value in the given results.
  # Returns nil if nothing found
  ###
  def tag_value(tag, results)
    if results
      results = results.join("\n")
      match = results.match(/#{ tag }: ([\w\-\. &]+)/i)
      return match[1].strip if match

      line = results.detect { |l| l.index(tag) }
      puts results
      puts line
      puts tag
      if line
        fields = line.split(":")
        return fields[1, fields.length].join(":").strip
      end
    end
  end

end

module FileTools
  ###
  # Returns true if root contains any
  # file of type (or types)
  ###
  def contains_any?(root, *type_or_array_of_types)
    types = [ type_or_array_of_types ].flatten
    
    types.each do |type|
      first = first_of_type(root, type)
      return first if first
    end
    return nil
  end
  
  ###
  # Finds and returns the filename of the first
  # file found under the given root of type.
  ###
  def first_of_type(root, type)
    all = all_of_type(root, type)
    return all.first if all
  end
  
  ###
  # Finds and returns all files of the given type
  # under root.
  ###
  def all_of_type(root, type)
    cmd = "find #{ param_clean(root) } -iname \"*.#{ type }\""
    return run_cmd(cmd)
  end
  
  ###
  # Returns an array of all subdirectories under the given dir
  ###
  def subdirectories(dir)
    Pathname.new(dir).children.select { |c| c.directory? }
  end
  
  ###
  # Returns an array of all normal files (non dirs) under the given dir
  ###
  def files(dir)
    (Pathname.new(dir).children - subdirectories(dir)).sort
  end
  
  ###
  # Returns the extension for file
  ###
  def extension(file)
    file = file.to_s
    pos = file.rindex(".")
    return file[pos + 1, file.length] if pos
  end
end

module PromptTools
  ###
  # Prompts the user for a value.
  # Uses values to list possible values.
  # Pass in options[:default] to have a default value.
  #
  # Returns the value the user selects.
  ###
  def prompt(label, values, options = {})
    str = label.to_s
    str += " [#{ options[:default] }]" if options[:default]
    str += ": "
    
    selection = nil
    print_in_columns(values)
    
    while !selection 
      response = Readline::readline(str)
      if options[:default] and response.strip.empty?
        selection = options[:default]
      elsif response.to_i > 0
        selection = values[response.to_i - 1]
      end
    end
    
    return selection
  end
  
  ###
  # Prompts the user for a path. If only_dirs, only directories
  # will be accepted.
  ###
  def prompt_for_path(start_dir, only_dirs = false)
    old_break_chars = Readline.basic_word_break_characters
    Readline.basic_word_break_characters = ""
    start_dir = File.expand_path(start_dir)
    
    Readline.completion_proc = lambda do |path|
      if start_dir
        path = "#{ start_dir }/#{ path }"
        start_dir = nil
      end
      path = Pathname.new("#{ path }")
      search = "#{ path }*"
      matches = Pathname.glob(search)
      matches
     # matches = matches.map { |p| p.directory? ? "#{ p }/" : p }
    end
    
    result = Readline.readline("$ ")
    Readline.basic_word_break_characters = old_break_chars
    return result
  end
  
  ###
  # Prints the given values in columns on screen
  ###
  def print_in_columns(values)
    longest = values.max { |v1, v2| v1.length <=> v2.length }
    column_width = longest.length + 6
    columns = (terminal_size[1] / column_width) - 1
    index = 1
    values = values.clone # copy so don't clobber passed in values
    
    while values.any?
      (0..columns).each do
        if values.any?
          val = "#{ index }. #{ values.shift }"
          print val.ljust(column_width)
          index += 1
        end
      end
      puts ''
    end
  end

  
  TIOCGWINSZ1 = 0x5413                  # For an Intel processor
  TIOCGWINSZ2 = 0x40087468            # For a PowerPC processor
  ###
  # Returns the height, width of the terminal
  ###
  def terminal_size

    rows, cols = 25, 80
    buf = [ 0, 0, 0, 0 ].pack("SSSS")
    
    begin
      if STDOUT.ioctl(TIOCGWINSZ1, buf) >= 0 then
        rows, cols, row_pixels, col_pixels = buf.unpack("SSSS")[0..1]
      end
    rescue
    end

    begin
      if STDOUT.ioctl(TIOCGWINSZ2, buf) >= 0 then
        rows, cols, row_pixels, col_pixels = buf.unpack("SSSS")[0..1]
      end
    rescue
    end

    return rows, cols
  end
  
  ###
  # Prints a line across the terminal to act as 
  # a ruler / break.
  ###
  def terminal_hr
    width = terminal_size[1]
    width.times { print '-' }
    print "\n"
  end
end

module ConfigTools
  ###
  # Saves the config string to the given file,
  # overwriting what is there.
  ###
  def save_config(file, config)
    file = File.expand_path(file)
    open(file, "w") { |f| f.write(config) }
  end

  ###
  # Loads and returns the config from the given file
  # or nil if file not found
  ### 
  def load_config(file)
    file = File.expand_path(file)
    open(file, "r") { |f| f.read } if File.exists?(file)
  end
  
end

module StringTools
  ###
  # Ensures a string only contains digits.
  ###
  def str_to_i(str)
    str.to_s.gsub(/\D/, '') if str
  end
end

module ItunesTools
  ###
  # Returns the itunes scripting object
  ###
  def itunes
    OSA.app( "iTunes" )
  end

  ###
  # Returns the itunes library source
  ###
  def itunes_library
    itunes.sources.detect { |s| s.name == "Library" }
  end

  ###
  # Returns a hash of tracks in the playlist called name.
  # File locations maps to the FileTrack.
  ###
  def tracks_in_playlist(name)
    playlist = itunes_library.user_playlists.detect { |p| p.name == name }
    res = {}
    playlist.file_tracks.each { |t| res[t.location] =  t }
    return res
  end

  ###
  # Returns an array of all tracks that should be deleted/updated.
  ###
  def tracks
    tracks_in_playlist("Music").values
  end

  def add_permanent_files_to_itunes
    log
    # sometimes these get deleted accidentally. Grrr.
    playlist = itunes_library.user_playlists.detect { |p| p.name == "Permanent" }
    itunes.add(PERMANENT_ITUNES_FILES.to_s, playlist)
  end
end

module LogTools
  ###
  # Outputs the given string with some debugging info.
  # If str.nil?, just outputs the name of the method that
  # called log.
  ###
  def log(str = nil)
    if !str
      str = caller.first.match(/.*`(.*)'$/)[1]
      str = str.humanize
    end
    puts "#{ Time.now }\t#{ str }"
  end
end

include FileTools
include MusicTools
include ProcessTools
include PromptTools
include ConfigTools
include StringTools
include ItunesTools
include LogTools
