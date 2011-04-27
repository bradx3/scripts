#!/usr/bin/env ruby

def chat
  system("ssh -f brad@clamps.lucky-dip.net -p 443 -g -L 5223:jabber.jamshidi.net:5223 -N")
end

def smb
  system("sudo ssh -f brad@clamps.lucky-dip.net -p 443 -g -L 139:clamps:139 -N")
  system("mount -t smbfs //guest@localhost:139/Media ~/tmp/home")
end

send(ARGV[0])
