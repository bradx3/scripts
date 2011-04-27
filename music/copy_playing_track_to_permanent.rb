#!/usr/bin/env ruby

require "my_tools.rb"

id = itunes.current_track.persistent_id
file_track = tracks.detect { |t| t.persistent_id == id }

if file_track and file_track.location
  FileUtils.cp(file_track.location, PERMANENT_ITUNES_FILES) 
  add_permanent_files_to_itunes
end
