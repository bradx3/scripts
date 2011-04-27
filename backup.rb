#!/usr/bin/env ruby

NAME = %x{ hostname }.strip
SSH_USER = "brad"
REMOTE_DIR = "/home/brad/Backups/#{ NAME }"

HOSTS = [ "clamps" ]
#HOSTS = [ "clamps", "hubert.lucky-dip.net" ]
DIRS = [
        "~/Library", 
        "~/Documents",
        "~/Pictures"
       ]
EXCLUDES = [
            "*Cache*",
            "*NewsFire*",
            "*Cookies*",
            "*.log",
            "HistoryIndex.ox*",
            "*Virtual Machines*",
            "*.resume",
            "*.ipsw",
            "*.dmg",
            "*.corrupt",
            "*.sqlite-journal",
            "*.m2v",
            "*.tmp"
           ]

HOSTS.each do |host|
  DIRS.each do |dir|
    puts "--------------------------------------------"
    excludes = EXCLUDES.map { |e| "--exclude \"#{ e }\"" }.join(' ')
    cmd = "rsync -av --delete --delete-excluded "
    cmd += " --rsh=\"ssh -l #{ SSH_USER }\" "
    cmd += " #{ dir } #{ host }:#{ REMOTE_DIR } #{ excludes }"
    puts cmd
    system(cmd)
  end
end


system("rsync -av clamps:/home/brad/Media/Books ~/Documents/")
