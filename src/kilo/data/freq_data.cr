module Kilo
  class FreqData
    include MessagePack::Serializable
    include Constants

    getter data
    getter meta
    getter stats
    getter characters
    getter bigrams

    def self.instance(bigrams = "")
      @@instance ||= new(bigrams)
    end

    private def initialize(bigrams = "")
      @characters = FreqHash.new
      @bigrams = FreqHash.new(2)
      @meta = Hash(String, String).new
      @stats = Hash(String, Int64 | Float64 | String).new

      conf = ProjectConfig.instance.config
      path = conf[:corpus]

      @meta["name"] = conf[:corpus]
      @meta["path"] = path

      load_data(bigrams)
    end

    private def load_bigrams(bigrams) : Hash(String, Int64)
      #  Helper.assert_file(bigrams)
      # Helper::YamlTo(Hash(String, Int64)).load(File.read(bigrams), bigrams)
      Helper::YamlTo(Hash(String, Int64)).load(Utils.read_compressed_file(bigrams), bigrams)
    end

    # Loads cached data or reads corpus and generates data
    private def load_data(bigrams)
      data_file = self.class.data_file

      if File.file? data_file
        _tmp = self
        _tmp = Helper.read_msgpack(data_file, _tmp)

        clone_from(_tmp)
        @characters.gen_lookups
        @bigrams.gen_lookups
      else
        if bigrams != ""
          data = load_bigrams(bigrams)
          characters = Hash(String, Int64).new
          data.each_key do |key|
            key.each_char do |c|
              char = c.to_s
              unless characters.has_key? char
                characters[char] = 0
              end
              characters[char] += data[key]
            end
          end
          @characters.import_data(characters)
          @bigrams.import_data(data)
        else
          STDERR.puts("* reading corpus...")
          Utils.read_corpus_lines do |line|
            line.each_char { |c| add_char(c.to_s) }
            # add_char(MARKERS["ret"])
            add_char("\n")
          end

          # add after a successfull load
          @meta["md5"] = Helper.file_md5sum(meta["path"])
        end

        @characters.gen_lookups
        @bigrams.gen_lookups

        Helper.write_msgpack(self, data_file)
      end
    end

    # Returns path to where we serialize ourselves
    def self.data_file : String
      return File.join(Kilo.pwd, FREQ_DIR, CORPUS_DATA_FILE)
    end

    # Clones self from another similar object
    def clone_from(obj) : Nil
      @meta = obj.meta.clone
      @stats = obj.stats.clone
      @characters = obj.characters
      @bigrams = obj.bigrams
    end

    # Serializes self to data file
    private def save_data : Nil
      Helper.write_msgpack(self, self.class.data_file(@meta["path"]))
    end

    private def add_char(c) : Nil
      @characters.append(c)
      @bigrams.append(c, 2)
    end

    # Prints hash that can be used from yaml for something else
    def print_data
      x = {
        meta:       @meta,
        characters: @characters,
        bigrams:    @bigrams,
      }
      puts x.to_yaml
    end

    def export_bigrams
      puts @bigrams.data.to_yaml
    end

    def print_chars
      puts @characters.sorted.join
    end

    # Prints sorted results for visual inspection
    def print_info
      x = {meta: @meta}
      puts x.to_yaml
    end
  end
end
