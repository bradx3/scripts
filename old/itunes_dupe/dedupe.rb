#!/usr/bin/ruby

require 'rubygems'
require 'rbosa'
require 'pathname'
# LIBRARY = '/Volumes/Clamps_Store/audio/'
LIBRARY = '/Users/brad/Music/iTunes Local/iTunes Music/'

def trimmed_name(file)
  file.to_s.downcase[0..-5]
end

def dupe_match(track_name)
  track_name.match('(.*) \\d+$')
end

def audio_files
  Pathname.new(LIBRARY)
end

# itunes = OSA.app( "iTunes" )
# tracks = itunes.sources.find{ |s| s.name == "Library" }.library_playlists.first.file_tracks

all_files = {}
to_check = []

audio_files.find do |f| 
  name = trimmed_name(f)
  all_files[name] = f
  to_check << f if dupe_match(name)
end

puts "Possible dupes: #{ to_check.length }"
dupes = []
to_check.each do |file|
  name = trimmed_name(file)
  base_name = dupe_match(name)[1]

  if all_files[base_name]
    dupes << file
  end
end


dupes = dupes.sort
puts ''
dupes.each { |f| puts f.to_s[LIBRARY.length, f.to_s.length] }
puts "Delete #{ dupes.length } dupes? [Y/n]:"
char = STDIN.readline.to_s.strip

if char.downcase != 'n'
  puts 'Deleting...'
  dupes.each do |f| 
    begin
      File.delete(f)
    rescue
      system("sudo rm -f \"#{f}\"")
    end
    # itunes.delete(t)
  end
end

# 
# puts "Checking #{ tracks.length } tracks"
# tracks.each_with_index do |track, i|
#   track_name = trimmed_name(track)
#   if track_name
#     all_files[track_name] = track
#     
#     if dupe_match(track_name)
#       to_check << track
#     end
#   end
# end
# 
# puts "Possible dupes: #{ to_check.length }"
# dupes = []
# to_check.each do |track|
#   name = trimmed_name(track)
#   trimmed_name = dupe_match(name)[1]
# 
#   if all_files[trimmed_name]
#     dupes << track
#   end
# end
# 
# dupes = dupes.sort{ |t1, t2| t1.location <=> t2.location }
# puts ''
# dupes.each { |t| puts t.location }
# puts "Delete #{ dupes.length } dupes? [Y/n]:"
# char = STDIN.readline.to_s.strip
# 
# if char.downcase != 'n'
#   puts 'Deleting...'
#   dupes.each do |t| 
#     File.delete(t.location)
#     itunes.delete(t)
#   end
# end 

# 
# 
# # FROM http://tagloko.rubyforge.org/svn/trunk/tagloko
# # 
# # # Interfaces
# # class CocoaDialog
# #   COCOA_DIALOG = "~/Applications/CocoaDialog.app/Contents/MacOS/CocoaDialog"
# #   TEXTBOX_WRAP = true # textbox should not wrap strings (CocoaDialog 2.1.1)
# # 
# #   def initialize
# #     @cocoa_dialog = File.expand_path(COCOA_DIALOG)
# #     if ! File.executable?(@cocoa_dialog)
# #       raise "CocoaDialog not executable. (check your path)"
# #     end
# #     @global_opts  = " --title #{NAME} --no-newline"
# #     @progress_bar = nil
# #   end
# # 
# #   # generic function to display messages
# #   def msgbox(buttons, txt, info = '', icon = nil)
# # 
# #     cmd  = "#{@cocoa_dialog} msgbox #{@global_opts} --float"
# #     cmd += " --icon \"#{icon}\"" if icon
# #     buttons.length.times {|i| cmd += " --button#{i+1} #{buttons[i]}"}
# #     cmd += " --text \"#{txt}\" --informative-text \"#{info}\""
# # 
# #     # caller controls buttons, handles return codes
# #     (`#{cmd}`).split("\n")
# #   end
# # 
# #   # display an editable textbox
# #   def display_textbox(txt, info)
# # 
# #     cmd  = "#{@cocoa_dialog} textbox #{@global_opts} --float"
# #     cmd += " --button1 \"Ok\" --button2 \"Cancel\""
# #     cmd += " --text \"#{txt}\" --informative-text \"#{info}\" --editable"
# #     ret  = (`#{cmd}`).split("\n")
# # 
# #     # return modified text or exit
# #     if ret[0].to_i == 2
# #       exit(0)
# #     else
# #       ret[1]
# #     end
# #   end
# # 
# #   # display dropdown menu
# #   def display_dropdown(txt, items)
# # 
# #     # double quote each item, convert to string
# #     str_items = items.collect {|s| '"' + s + '"'}.join(' ')
# # 
# #     cmd  = "#{@cocoa_dialog} dropdown #{@global_opts} --float"
# #     cmd += " --button1 \"Ok\" --button2 \"Cancel\" --button3 \"Help\""
# #     cmd += " --text \"#{txt}\" --items #{str_items}"
# #     ret  = (`#{cmd}`).split("\n")
# # 
# #     # buttons
# #     case ret[0].to_i
# #       when 3
# #         display_help
# #         display_dropdown(txt, items)
# #       when 2
# #         exit(0)
# #       else
# #         items[ret[1].to_i]
# #     end
# #   end
# # 
# #   def display_error(txt, info = 'Run it from a terminal for details.')
# #     msgbox(['Ok'], txt, info, 'x')
# #   end
# # 
# #   def display_message(txt, info = '')
# #     msgbox(['Ok'], txt, info, 'info')
# #   end
# # 
# #   def display_confirmation(txt, info)
# #     ret = msgbox(['Yes', 'No'], txt, info)
# #     # return decision
# #     ret[0].to_i == 1 ? 'Yes' : 'No'
# #   end
# # 
# #   def display_help
# #     display_textbox(HELP, '')
# #   end
# # 
# #   def display_report(txt)
# #     # write report to text file if CocoaDialog's textbox wraps strings
# #     if TEXTBOX_WRAP
# #       file = File.expand_path(FILE_REPORT)
# #       File.open(file, 'w') {|f| f.write(txt)}
# #       display_message('Report', "File path: \"#{FILE_REPORT}\"")
# #     else
# #       cmd  = "#{@cocoa_dialog} textbox #{@global_opts} --float"
# #       cmd += " --button1 \"Ok\" --text \"#{txt}\""
# #       cmd += " --informative-text \"Report\""
# #       `#{cmd}`
# #     end
# #   end
# # 
# #   def display_progress_bar(title, txt, percent = 0, indeterminate = false)
# #     cmd  = "#{@cocoa_dialog} progressbar --title \"#{title}\""
# #     cmd += " --text \"#{txt}\""
# #     cmd += " --indeterminate"          if indeterminate
# #     cmd += " --percent \"#{percent}\"" if ! indeterminate
# # 
# #     # build progress bar(reads on stdin until EOF)
# #     @progress_bar = IO.popen(cmd, 'w')
# #   end
# #   def update_progress_bar(percent, txt = nil)
# #     # update percent(ignored if indeterminate) and set (optional) message
# #     msg = txt.nil? ? percent.to_s : percent.to_s + ' ' + txt
# # 
# #     @progress_bar.write(msg)
# #     @progress_bar.flush
# #   end
# #   def close_progress_bar
# #     @progress_bar.close unless @progress_bar.nil? || @progress_bar.closed?
# #   end
# #   private :msgbox
# # end