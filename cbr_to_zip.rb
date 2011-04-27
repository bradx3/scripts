#!/usr/bin/ruby


require 'fileutils'

WORKING_DIR = "/tmp/comics/"

ARGV.each do |file|
  ext = File.extname(file).downcase
  next unless ext == '.cbr' or ext == '.rar'

  # setup working dir
  FileUtils.rm_r(WORKING_DIR) if File.exists?(WORKING_DIR)
  dest = "#{ WORKING_DIR }#{ file }"
  FileUtils.mkdir(WORKING_DIR)

  # copy and unrar
  FileUtils.cp(file, dest, :verbose => true)
  system("cd #{ WORKING_DIR } && unrar e \"#{ dest }\"")
  FileUtils.rm(dest)

  # zip up and copy back
  name = File.basename(file)
  name = name[0, name.length - File.extname(file).length]
  dest = "#{ name }.cbz"

  system("cd #{ WORKING_DIR } && zip -m \"#{ dest }\" *")
  FileUtils.cp("#{ WORKING_DIR }#{ dest }", FileUtils.pwd, :verbose => true)

  # clean up
  FileUtils.rm(file)
  FileUtils.rm_r(WORKING_DIR)
end
