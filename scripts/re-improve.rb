#!/bin/env ruby

require "yaml"
require "set"

unless ARGV.size == 1
  STDERR.puts "wrong argument count"
  exit 1
end
DB=ARGV[0]

LIMIT=150
results = []
Dir.glob("sql/by-*sql") do |f|
    results.concat(`kilo query --sql #{f} --limit #{LIMIT} --dump #{DB}`.strip.split("\n"))
end

keys = results.map do |x|
  parts = x.split(/\s+/)
  [parts[1].gsub(/\-.+/,''), parts[0]]
end

keys.to_h.each_pair do |k,v|
  puts v + " " + k
end

