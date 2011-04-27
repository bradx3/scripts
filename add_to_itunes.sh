#!/usr/bin/env sh

/usr/bin/osascript <<EOT
set foo to posix file "$1" as alias 
tell application "iTunes" to add foo
EOT