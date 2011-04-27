#!/usr/bin/ruby

require '/home/brad/scripts/lib/my_tools.rb'

SOURCES = [ "TV" , "Movies" ]
MAX = 500
EXTENSIONS = [ "avi", "mkv", "mpg", "ogm" ]
DEST = "/home/brad/Media/New"

###
# Replaces any new tv shows with links to their base dir.
# (So we don't have a whole season of files clogging up the list)
###
def remove_whole_tv_series(files)
  to_delete = []
  
  files.each_with_index do |file, i|
    show, season = tv_show_info(file)
    series_dir = Pathname.new(file).parent.to_s
    
    if show and season and !files.include?(series_dir)
      same_series = files_from_series(files, show, season)
      if same_series.length > 1
        files.insert(i, series_dir)
        to_delete += same_series
      end
    end
  end
  
  return files - to_delete
end

###
# Returns all files from the given show and season
###
def files_from_series(files, target_show, target_season)
  results =  []
  
  files.each do |file|
    show, season = tv_show_info(file)
    results << file if show == target_show and season == target_season
  end
  
  return results
end

###
# Returns the show and season number for the given file.
# If it is not a tv show, returns nil
###
def tv_show_info(file)
  regex = /.*\/(.*)\/.*Season (.+)\/.*/
  match, show, season, rest = *file.match(regex)
  
  return show, season
end

###
# Returns an array of filenames which are new
###
def sorted_file_names
  filematch = EXTENSIONS.map { |e| "-iname \"*.#{ e }\"" }.join(" -o ")
  source = SOURCES.join(" ")
  period = 365 # 1 year
  cmd = "find #{ source } -mtime -#{ period } \\( #{ filematch } \\)"
  files = run_cmd(cmd)

  files = files.uniq
  files = remove_whole_tv_series(files)

  files = files.map { |f| Pathname.new(f) }
  files = files.sort { |f1, f2| f2.mtime <=> f1.mtime }

  return files[0, MAX]
end

def clear_old_links
  system("rm -Rf #{ DEST }/*")
end

def create_links(files)
  files.each_with_index do |file, i|
    file = Pathname.new(file)
    if file.directory?
      # then it's a tv show, so grab name and season
      name = "#{ file.parent.basename } - #{ file.basename }"
    else
      name = Pathname.new(file).basename
    end

    num = (i + 1).to_s
    num = "0#{ num }" until num.length > 2
    link = "#{ DEST }/#{ num }. #{ name }"

    cmd = cmd("ln -s", [ file.expand_path, link ])
    system(cmd)
  end
end

FileUtils.cd("/home/brad/Media/")
files = sorted_file_names
clear_old_links
create_links(files)
