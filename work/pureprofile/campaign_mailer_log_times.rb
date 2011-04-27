#!/usr/bin/ruby
require 'date'
require 'rubygems'
require 'activesupport'

JOB_START = /Claiming job - JOB \[\d+\] .* C \[(\d+)\]/
JOB_END = /Sent (\d+)/

def jobs(log)
  jobs = []
  
  job_start_lines(log).each do |job_start|
    job_end = job_end(log, job_start)
    
    if job_end
      jobs << [ job_start, job_end ]
    end
  end
  
  return jobs
end

def job_start_lines(log)
  log.split("\n").select do |line|
    line.match(JOB_START)
  end
end

def job_end(log, start)
  campaign = start.match(JOB_START)[1]
  start_index = log.index(start)
  
  log[start_index, log.length].split("\n").find do |line|
    line.index("Sent") and line.index("campaign mails for C [#{ campaign }]")
  end
end


log = open("/tmp/CampaignMailer.log").read

jobs(log).each do |job_start, job_end|
  time = (DateTime.parse(job_end).to_time - DateTime.parse(job_start).to_time).seconds
  sent = job_end.match(JOB_END)[1].to_i
  if sent > 0
    puts sent * 60.0 / time
  end
end