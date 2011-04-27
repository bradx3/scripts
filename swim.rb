#!/usr/bin/env ruby

require "rubygems"
require "sqlite3"
require 'optparse'
require 'active_record'
require "active_support"
require "fastercsv"
require "erb"

module Swimming
  def parse_args
    options = { :date => Date.today }
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: swim.rb distance_in_m time [options]"

      opts.on("-c", "--create", "Create the swim db") do |c|
        options[:create] = c
      end

      opts.on("-e", "--export", "Exports the swims as csv") do |o|
        options[:export] = o
      end

      opts.on("-g", "--graph", "Generates a graph of times") do |o|
        options[:graph] = o
      end

      opts.on("-a", "--add", "Add a swim to the db") do |a|
        options[:add] = a
      end

      opts.on("--date D", String, "The date the swim occured on (if not today) dd/mm/yyyy") do |d|
        options[:date] = Date.strptime(d, "%d/%m/%Y")
      end

      opts.on("-r", "--race", "The swim to add is a race") do |o|
        options[:race] = o
      end

      opts.on("--notes N", String, "Any notes about the swim") do |o|
        options[:notes] = o
      end
    end
    
    parser.parse!
    return options
  end

  def create_table
    sql = "create table swims (id integer primary key, date date, distance integer, minutes integer, seconds integer, race boolean, notes text)"
    db.execute(sql)
  end

  def db
    if @db.nil?
      @db = File.expand_path("~/Documents/Swims.db")
      @db = SQLite3::Database.new(@db)
    end

    return @db
  end

  def add_swim
    distance = ARGV.shift
    if distance.to_i < 100
      puts "Distance in metres numbskull"
      exit
    end

    swim = Swim.new
    time = ARGV.shift
    minutes, seconds = time.split(/[,.:]/) if time
    swim.minutes = minutes
    swim.seconds = seconds
    swim.distance = distance
    swim.date = OPTIONS[:date]
    swim.race = OPTIONS[:race]
    swim.notes = OPTIONS[:notes]
    swim.save!

    puts swim.to_csv
    graph
  end

  def export
    res = []
    res << Swim.column_names.to_csv
    Swim.all.each do |swim|
      res << swim.to_csv
    end

    puts res
  end

  def graph
    template = File.open("/Users/brad/projects/scripts/swimming/graph.html.erb").read
    template = ERB.new(template).result(binding)

    file = "/Users/brad/projects/scripts/swimming/graph.html"
    File.open(file, "w") { |f| f.write(template) }
    system("open #{ file }")
  end

end

class Float < Numeric
  def to_time
    return "" if self.nan?

    minutes = self.floor
    seconds = self - minutes
    seconds = (seconds * 60).to_i
    seconds = sprintf("%02d", seconds)

    return "#{ minutes }:#{ seconds }"
  end
end

class Swim < ActiveRecord::Base
  named_scope(:measured, :conditions => 
              [ "minutes > 0 and seconds  > 0 and distance > 0" ])
  named_scope(:training, :conditions => { :race => nil })
  named_scope(:races, :conditions => { :race => true })
  
  def self.all(options = {})
    default_options = { :order => "date asc" }
    options = default_options.merge(options)
    Swim.find(:all, options)
  end

  def self.average_time(swims)
    distance = 0.0
    seconds = 0.0

    swims.each do |s|
      distance += s.distance
      seconds += (s.minutes * 60.0) + s.seconds
    end
    
    res = seconds.to_f / distance.to_f
    return res * 1000.0 / 60.0
  end

  def self.average_distance_per_month
    months = swims_grouped_by_month
    total = 0.0

    months.each do |month, swims|
      total += swims.inject(0) { |sum, s| sum += s.distance }
    end

    return total.to_f / months.length
  end

  def self.total_distance_per_month
    months = swims_grouped_by_month
    months = months.map do |month, swims|
      total = swims.inject(0) { |sum, s| sum += s.distance }
      [ month, total ]
    end

    return months
  end

  def self.best_distance_month
    months = total_distance_per_month.sort_by { |month, total| total }
    return months.last
  end

  def self.average_times_by_month
    counted_swims = Swim.measured.training.all
    months = swims_grouped_by_month

    months = months.map do |month, swims|
      to_count = swims.select { |s| counted_swims.include?(s) }
      [ month, average_time(to_count) ]
    end
    return months
  end

  def self.swims_grouped_by_month
    months = Swim.all.group_by { |s| s.date.strftime("%B %Y") }
    months = months.sort_by { |month, swims| Date.strptime(month, "%B %Y") }
    return months
  end
  
  def self.best_training_swim(distance = nil)
    conds = "race is null and minutes > 0" 
    if distance
      conds += " and distance = #{ distance }"
    end

    return  Swim.first(:conditions => [ conds ],
                       :order => "(minutes * 60) + seconds / distance")
  end

  def self.minutes_per_km(conditions = {})
    Swim.measured.all(:conditions => conditions).map do |s|
      [ s.date.to_time.to_i * 1000, s.minutes_per_km ]
    end
  end

  def self.distances(conditions = {})
    Swim.all(:conditions => conditions).map do |s|
      [ s.date.to_time.to_i * 1000, s.distance / 1000.0 ]
    end
  end

  def self.notes
    res = {}
    Swim.all.each do |s|
      res[s.date.to_time.to_i * 1000] = {
        :date => s.date.strftime("%d/%m/%y"),
        :distance => (s.distance / 1000.0).round(2),
        :time => "#{ s.minutes }:#{ s.seconds }",
        :notes => s.notes || ""
      }
    end
    return res
  end

  def total_seconds
    (minutes * 60) + seconds if minutes and seconds
  end

  def seconds_per_m
    total_seconds.to_f / distance.to_f
  end

  def minutes_per_km
    res = seconds_per_m * 1000.0 / 60.0
    return res if res.to_i != 0
  end

  def to_csv
    res = []
    Swim.column_names.each do |col|
      res << self.send(col)
    end
    return res.to_csv
  end

end

ActiveRecord::Base.establish_connection("adapter" => "sqlite3",
                                        "database" => File.expand_path("~/Documents/Swims.db"))


include Swimming

OPTIONS = parse_args

if OPTIONS[:add]
  add_swim
elsif OPTIONS[:create]
  create_table
elsif OPTIONS[:export]
  export
elsif OPTIONS[:graph]
  graph
end

db.close
