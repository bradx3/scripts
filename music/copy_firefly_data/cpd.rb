#!/opt/local/bin/ruby.bak

require 'sqlite'
require 'sqlite3'

SRC_DB = "/Users/brad/tmp/mt-daapd/songs.db"
DEST_DB = "/Users/brad/tmp/mt-daapd-new/songs3.db"

def load_songs(db)
  columns, *rows = db.execute2( "select * from songs" )
  
  songs = []
  
  rows.each do |row|
    song =  {}
    columns.each_with_index do |column, i|
      song[column.to_sym] = row[i]
    end
    songs << song
  end
  
  return songs
end

def update_playcounts(old_songs, new_songs, db)
  new_songs.each do |song|
    count = old_playcount(song, old_songs)
    if count and count > playcount(song)
      sql = "update songs set play_count = #{ count } where id = #{ song[:id] }"
      print(song, count)
      db.execute(sql)
    end
  end
end

def playcount(song)
  count = song[:play_count]
end

def old_playcount(song, old_songs)
  old_songs.each do |os|
    if same_song?(song, os)
      return playcount(os)
    end
  end
  return nil
end

def same_song?(song, other)
  (song[:title] == other[:title]) and (song[:album] == other[:album]) and (song[:title] == other[:title])
end

def print(song, old_count)
  values = []
  values << playcount(song)
  values << old_count
  values << "\t"
  values << song[:track]
  values << song[:artist]
  values << song[:album]
  values << song[:title]
  
  puts values.join("\t")
end

old_songs = load_songs(SQLite::Database.new(SRC_DB))
dest_db = SQLite3::Database.new(DEST_DB)
new_songs = load_songs(dest_db)

update_playcounts(old_songs, new_songs, dest_db)