module Kilo
  # Holds character frequency data.
  # Main usage is to create two objects and feed them characters.
  #
  # ```
  # characters = FreqHash(1)
  # bigrams = FreqHash(2)
  #
  # while reading_characters
  #   characters.append(chr)
  #   bigrams.append(chr)
  # end
  #
  # characters.gen_lookups
  # bigrams.gen_lookups
  # ```
  # After you generate the data you query it.
  # you will probably want to filter characters
  #
  #
  # ```
  # new_characters = characters.filter_by(["a", "b", "c", ...])
  # new_bigrams = bigrams.filter_by(["a", "b", "c", ...])
  # ```
  # when you filter the date, it will also be scaled so that
  # the sum equals the Scaling factor.
  #
  # You can serialize to yaml or msgpack
  class FreqHash
    include Constants
    include Macros
    include MessagePack::Serializable

    getter key_length

    getter data
    getter data_i
    getter sorted
    getter sorted_rev
    getter data_sum

    @key_length : Int32 = 1

    @data : Hash(String, Int64) = {} of String => Int64
    @data_i : Array(Int64) = [] of Int64
    @sorted : Array(String) = [] of String
    @sorted_rev : Hash(String, Int32) = {} of String => Int32
    @data_sum : Int64 = 0

    @buffer : Array(String) = [] of String

    # Required to be able to serialize with yaml
    def new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
      unless node.is_a?(YAML::Nodes::Mapping)
        node.raise "Expected mapping, not #{node.kind}"
      end

      YAML::Schema::Core.each(node) do |key, value|
        yield K.new(ctx, key), V.new(ctx, value)
      end
    end

    # Initialize to the type of object we want.
    # - key_length 1 will result in a structure that
    # holds characters and their frequencies,
    # - 2 will hold bigrams.
    def initialize(key_length : Int32 = 1)
      @key_length = key_length
    end

    # Deletes all keys matching given array of Strings (characters)
    # For bigrams will delete any key that has these characters
    # also does scaling
    def delete(keys : Array(String)) : Nil
      @data.keys.each do |k|
        _delete = false
        keys.each do |x|
          if k.includes? x
            _delete = true
          end
        end
        @data.delete(k) if _delete
      end
      scale
      # gen_lookups
    end

    # Returns True if ALL keys are in @data
    def has_keys?(keys : Array(String)) : Bool
      keys.each do |k|
        return false unless @data.has_key? k
      end
      return true
    end

    # Like has_keys? but returns array of missing keys or empty array
    def missing_keys(keys : Array(String)) : Array(String)
      res = [] of String
      keys.each do |k|
        res << k unless @data.has_key? k
      end
      return res
    end

    # Returns an object with only given array of keys,
    # if key is not present return count 0 (Adds the extra shift)
    # if key is not present we don't return it
    def filter_by(filter : Array(String)) : FreqHash
      filter_set = Set.new(filter)
      _tmp = {} of String => Int64

      # we make sure we return all keys given
      # filter.each { |c| _tmp[c] = 0 }

      # no need a match and set?
      @data.each_key do |k|
        add = true
        k.split("").each do |c|
          unless filter_set.includes? c
            add = false
          end
        end
        _tmp[k] = @data[k] if add
      end

      if key_length == 1
        # We need to make sure that if not in dict we still return all
        # letters
        filter_set.each do |k|
          unless _tmp.has_key? k
            _tmp[k] = 0
          end
        end
      end

      _other = FreqHash.new(@key_length)
      _other.data = _tmp
      _other.scale
      return _other
    end

    # will scale to DATA_SCALE and regenerate all data
    def scale
      factor = DATA_SCALE/@data.values.sum
      @data.each_key do |k|
        val = (@data[k] * factor).to_i64
        # why doe this cause problems?
        # next if (@key_length) == 2 && (val == 0)
        @data[k] = val
      end
      gen_lookups

      # just to be sure in case some rounding happens and we
      # endup with less
      @data_sum = DATA_SCALE
    end

    # Appends one character and increments the count for frequency of characters
    def append(s, len = @key_length) : Nil
      if len != 1
        _add_to_buffer(s)
      else
        unless @data.has_key? s
          @data[s] = 0
        end

        @data[s] += 1
      end
    end

    def to_yaml(yaml : YAML::Nodes::Builder) : Nil
      yaml.mapping(reference: self) do
        add_yaml_mappings [
          "key_length",
          "data",
          "data_i",
          "sorted",
          "sorted_rev",
          "data_sum",
        ]
      end
    end

    # Generates all data that can be retrieved later.
    # must be called early before trying to retrieve data
    def gen_lookups : Nil
      @sorted.clear
      @sorted_rev.clear
      @data_i.clear
      @sorted_rev.clear
      #      _subst_space
      _gen_sorted
    end

    # A protected setter for @data
    protected def data=(val : Hash(String, Int64)) : Nil
      @data = val
    end

    # Deals with space, tab, and endl
    #    private def _subst_space : Nil
    #      @data.keys.each do |k|
    #        v = @data[k]
    #        # not if/else becasue we can have a combination of two of them
    #        delete = false
    #        k_new = k
    #        if k =~ / +/
    #          delete = true
    #          k_new = k_new.gsub(" ", MARKERS["space"])
    #        end
    #        if k =~ /\n/
    #          delete = true
    #          k_new = k_new.gsub("\n", MARKERS["ret"])
    #        end
    #        if k =~ /\t/
    #          delete = true
    #          k_new = k_new.gsub("\t", MARKERS["tab"])
    #        end
    #        if delete
    #          @data[k_new] = v
    #          @data.delete k
    #        end
    #      end
    #    end
    #
    #    # Not sure we need to add a shift character
    #    def add_shift : Nil
    #      if @key_length == 1
    #        @data[MARKERS["shift"]] = 0
    #        @data.each_key do |k|
    #          if k.downcase != k
    #            @data[MARKERS["shift"]] += @data[k]
    #          end
    #        end
    #      else
    #        @data.each_key do |k|
    #          if k.downcase != k
    #            k.split("").each do |c|
    #              if c.downcase != c
    #                unless @data.has_key? MARKERS["shift"] + c
    #                  @data[MARKERS["shift"] + c] = 0
    #                end
    #                @data[MARKERS["shift"] + c] += @data[k]
    #              end
    #            end
    #          end
    #        end
    #      end
    #      gen_lookups
    #    end
    #
    def clone
      _other = FreqHash.new(@key_length)
      _other.data = @data.clone
      _other.gen_lookups
      return _other
    end

    def import_data(data)
      @data = data.clone
      gen_lookups
    end

    # Returns indexed array of frequency values. Also returns
    # a sorted hash
    private def _create_data_i(sorted, data)
      _tmp = data.class.new
      data_i = [] of Int64
      sorted.each_index do |i|
        data_i << data[sorted[i]]
        _tmp[sorted[i]] = data[sorted[i]]
      end
      return data_i, _tmp
    end

    # Returns sorted keys of a hash (by value)
    private def _sort_keys(data) : Array(String)
      return data.keys.sort { |a, b| data[b] <=> data[a] }
    end

    # Generates the sorted reverse lookup
    private def _sorted_rev_lookup(data) : Hash(String, Int32)
      res = {} of String => Int32
      data.each_index do |i|
        res[data[i]] = i
      end
      return res
    end

    # Generates sorted keys and sorted int lookup for values.
    # Also sorts hashes (just for visual inspectiono of data)
    private def _gen_sorted : Nil
      @sorted = _sort_keys(@data)
      @sorted_rev = _sorted_rev_lookup(@sorted)

      # we get data back sorted, just for visuals when inspecting data
      @data_i, @data = _create_data_i(@sorted, @data)

      @data_sum = @data.values.sum
    end

    # Adds characters to a buffer in case of key_length > 1 before adding the full key.
    private def _add_to_buffer(s) : Nil
      @buffer << s
      if @buffer.size == @key_length
        append(@buffer.join(""), len: 1)
        @buffer.clear
        # keep last read character
        @buffer << s
      end
    end

    # downcases doesn't add anything to shift since we deal with shift earlier.
    #    private def self.downcase(data)
    #      tmp = data.clone
    #      tmp.each_key do |k|
    #        x = k.downcase
    #        if k != x
    #          if tmp.has_key? x
    #            tmp[x] += tmp[k]
    #          else
    #            tmp[x] = tmp[k]
    #          end
    #          tmp.delete(k)
    #        end
    #      end
    #      return tmp
    #    end
  end
end
