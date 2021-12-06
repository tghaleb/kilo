#!/bin/env ruby
# a simple filter to cleanup an English corps
# mostly removes lines with characters not part of US-ASCII

unless ARGV.size == 1
  puts "wrong arg count"
  exit 1
end

SRC = ARGV[0]

unless File.file? SRC
  puts "not a file #{SRC}"
  exit 1
end

open(SRC).each do |line|
  next unless line.valid_encoding?

  line = line.gsub(/[“”]/, '"').gsub(/[‘’]/, "'")

  if line.force_encoding("US-ASCII").valid_encoding?
    puts line
  end
end

