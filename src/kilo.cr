# only add shard requirements here
require "comandante"
require "comandante-msgpack"
require "comandante-zstd"
require "celestine"
require "ishi"
require "rucksack"
require "sqlite3"

require "./kilo/main"

VERSION = "0.2.6"

Kilo::App.new.run
