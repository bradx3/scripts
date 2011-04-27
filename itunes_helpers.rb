#!/Users/brad/.rvm/ree-1.8.7-2009.10/bin/ruby

# track methods:
# ["__data__", "__type__", "after", "album", "album=", "album_artist", "album_artist=", "album_rating", "album_rating=", "album_rating_kind", "artist", "artist=", "artworks", "before", "bit_rate", "bookmark", "bookmark=", "bookmarkable=", "bookmarkable?", "bpm", "bpm=", "category", "category=", "comment", "comment=", "compilation=", "compilation?", "composer", "composer=", "container", "database_id", "date_added", "description", "description=", "disc_count", "disc_count=", "disc_number", "disc_number=", "duration", "enabled=", "enabled?", "episode_id", "episode_id=", "episode_number", "episode_number=", "eq", "eq=", "finish", "finish=", "gapless=", "gapless?", "genre", "genre=", "grouping", "grouping=", "id2", "index", "kind", "location", "location=", "long_description", "long_description=", "lyrics", "lyrics=", "modification_date", "name=", "persistent_id", "played_count", "played_count=", "played_date", "played_date=", "podcast?", "rating", "rating=", "rating_kind", "refresh", "release_date", "reveal", "sample_rate", "season_number", "season_number=", "show", "show=", "shufflable=", "shufflable?", "size", "skipped_count", "skipped_count=", "skipped_date", "skipped_date=", "sort_album", "sort_album=", "sort_album_artist", "sort_album_artist=", "sort_artist", "sort_artist=", "sort_composer", "sort_composer=", "sort_name", "sort_name=", "sort_show", "sort_show=", "start", "start=", "time", "to_rbobj", "track_count", "track_count=", "track_number", "track_number=", "unplayed=", "unplayed?", "video_kind", "video_kind=", "volume_adjustment", "volume_adjustment=", "year", "year="] 

require "rubygems"
require "rbosa"
require "active_support"

def itunes
  @@itunes ||= OSA.app("iTunes")
end


def split_name_into_num_artist_and_name
  itunes.selection.each do |track|
    num, artist, name = track.name.split("-")
    next if name.nil?

    track.name = name.strip
    track.artist = artist.strip
  end
end

def split_name_into_name_and_artist
  itunes.selection.each do |track|
    name, artist = track.name.split("-")
    next if name.nil?

    track.name = name.strip
    track.artist = artist.strip
  end
end

def split_name_into_num_and_name
  itunes.selection.each do |track|
    num, *name = track.name.split(" ")
    name = name.join(" ")

    track.track_number = num.to_i
    track.name = name.strip
  end
end

def titleize_name
  itunes.selection.each do |track|
    track.name = track.name.titleize
  end
end

method = ARGV[0]
if method.present?
  puts method
  send method
end
