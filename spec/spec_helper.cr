require "spec"
require "sqlite3"
require "celestine"
require "rucksack"
require "comandante"
require "comandante-msgpack"
require "comandante-zstd"

require "../src/kilo/main"

TEST_TEXT = "This is some TexT
 And more!
 Than you."

UNIQ_CHARS = TEST_TEXT.split("").uniq.size
UNIQ_CAPS  = 1

SHIFT_COUNT = 5

def init_freq_hash(obj)
  TEST_TEXT.split("").each do |c|
    obj.append(c)
  end
end

def freq_hash_data(filter)
  characters : FreqHash = FreqHash.new(1)
  bigrams : FreqHash = FreqHash.new(2)

  characters = FreqData.instance.characters.filter_by(filter)
  bigrams = FreqData.instance.bigrams.filter_by(filter)

  return {characters, bigrams}
end
