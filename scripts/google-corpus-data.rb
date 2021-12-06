#!/bin/env ruby

# script to import google corpus data
# see from https://gist.github.com/lydell/c439049abac2c9226e53

require "yaml"
require "json"
require "tempfile"

data = ""
URL = "https://gist.github.com/lydell/c439049abac2c9226e53/raw/4cfe39fd90d6ad25c4e683b6371009f574e1177f/bigrams.json"

Tempfile.open do |tmp|
system  %Q(wget -q -c "#{URL}" -O #{tmp.path})

data = JSON.parse(File.read(tmp))
end

new_data = {}
data.each do |x|
  new_data[x[0]] = x[1]
end

puts new_data.to_yaml
