require "ecr"

module Kilo
  # Generates typing lessons
  class Type
    include Constants
    property map

    REP            =  8
    WORDS_PER_LINE = 11
    WORD_FREQ_MIN  = 50

    HOME1 = [
      Key::AC01,
      Key::AC02,
      Key::AC03,
      Key::AC04,
    ]
    HOME2 = [
      Key::AC07,
      Key::AC08,
      Key::AC09,
      Key::AC10,
    ]

    HOME1_5 = [
      Key::AC05,
    ]
    HOME2_5 = [
      Key::AC06,
    ]

    HOME1_PLUS = [
      Key::AD03,
      Key::AD04,
    ]
    HOME2_PLUS = [
      Key::AD07,
      Key::AD08,
    ]

    R3_LEFT = [
      Key::AD01,
      Key::AD02,
      Key::AD05,
    ]
    R3_RIGHT = [
      Key::AD06,
      Key::AD09,
      Key::AD10,
      Key::AD11,
      Key::AC11,
    ]

    R1_LEFT = [
      Key::AB01,
      Key::AB02,
      Key::AB03,
      Key::AB04,
      Key::AB05,
    ]
    R1_RIGHT = [
      Key::AB06,
      Key::AB07,
      Key::AB08,
      Key::AB09,
      Key::AB10,
    ]

    alias LetterLookupType = Hash(Set(String), Array(Int32))
    @dict = Array(String).new
    @lookup = LetterLookupType.new
    @word_limit = 100

    property word_limit

    def initialize(@map : MapConfig)
      load_data(@map[:name])
    end

    # Loads dict and lookup
    private def load_data(name)
      dict_file = dict_path(name)

      unless File.file? dict_file
        create_dict(name)
      else
        data = Helper.read_yaml(dict_file)
        @dict = Helper::YamlTo(Array(String)).load(data.as_h["dict"].to_yaml, "@dict")
        @lookup = Helper::YamlTo(LetterLookupType).load(
          data.as_h["lookup"].to_yaml, "@lookup")
      end
    end

    # Creates a by char word lookup only once
    private def index_dict
      @dict.each_index do |i|
        w = @dict[i]
        s = Set(String).new(w.split(""))

        unless @lookup.has_key? s
          @lookup[s] = Array(Int32).new
        end
        @lookup[s] << i
      end
    end

    # Creates a dict of words, only once
    private def create_dict(name)
      lookup = Hash(String, Int32).new
      Utils.read_corpus_lines do |line|
        words = line.split(/\s+/)
        words.each do |w|
          unless lookup.has_key? w
            lookup[w] = 0
          end
          lookup[w] += 1
        end
      end

      lookup.each_key do |x|
        if lookup[x] > WORD_FREQ_MIN
          @dict << x
        end
      end
      @dict.sort! { |a, b| lookup[b] <=> lookup[a] }
      index_dict

      data = {dict: @dict, lookup: @lookup}
      Helper.string_to_file(data.to_yaml, dict_path(name))
    end

    # returns path to dict
    private def dict_path(name)
      return ".kilo/" + name + ".dict"
    end

    def build_keys(names) : Array(String)
      letters = Array(String).new
      names.each do |k|
        letters << @map[:map][k][0]
      end
      return letters
    end

    private def join_letters(*words) : Array(String)
      result = Array(String).new
      words.each do |x|
        result << x.join("")
      end
      return result
    end

    private def build_line(*words) : String
      words_s = join_letters(*words)
      return words_s.join(" ") + "\n"
    end

    @words_used = Set(Int32).new

    # Returns words of n letters that use letters
    private def get_words_n(letters, count) : Array(String)
      result = Array(String).new
      indices = Array(Int32).new

      letters.combinations(count).each do |x|
        count = 0
        x_set = Set(String).new(x)
        if @lookup.has_key? x_set
          indices.concat(@lookup[x_set])
        end
      end

      indices.sort.uniq.each do |i|
        next if @words_used.includes? i
        result << @dict[i]
        @words_used.add(i)
        break if result.size > @word_limit
      end

      return result
    end

    # Repeats a word n time
    private def repeat(words, times) : Array(String)
      result = Array(String).new

      words.each do |w|
        result << ((w + " ") * times).strip + "\n"
      end

      result << "\n"

      return result
    end

    # Joins words wrapping at WORDS_PER_LINE
    private def join_words(words)
      result = Array(String).new

      last = WORDS_PER_LINE - 1
      start = 0
      while words.size > last
        result << words[start..last].join(" ") + "\n"
        start += WORDS_PER_LINE
        last += WORDS_PER_LINE
      end

      if start < words.size
        result << words[start..-1].join(" ") + "\n"
      end
      result << "\n"

      return result
    end

    private def home_lessons
      result = Array(String).new
      home1 = build_keys(HOME1)
      home2 = build_keys(HOME2)

      home1_rev = home1.reverse
      home2_rev = home2.reverse

      result << build_line(home1, home2, home1, home2)
      result << build_line(home1, home2, home1, home2)
      result << build_line(home1_rev, home2_rev, home1_rev, home2_rev)
      result << build_line(home1_rev, home2_rev, home1_rev, home2_rev)

      result << "\n"

      return result
    end

    private def home_plus_lessons
      result = Array(String).new

      home1_5 = build_keys(HOME1 + HOME1_5)
      home2_5 = build_keys(HOME2_5 + HOME2)

      home1_5_rev = home1_5.reverse
      home2_5_rev = home2_5.reverse

      home1_plus = build_keys(HOME1 + HOME1_5 + HOME1_PLUS)
      home2_plus = build_keys(HOME2_5 + HOME2 + HOME2_PLUS)

      home_plus_words_2 = get_words_n(home1_plus + home2_plus, 2)
      home_plus_words_3 = get_words_n(home1_plus + home2_plus, 3)
      home_plus_words_4 = get_words_n(home1_plus + home2_plus, 4)

      result << build_line(home1_5, home2_5, home1_5, home2_5)
      result << build_line(home1_5, home2_5, home1_5, home2_5)
      result << build_line(home1_5_rev, home2_5_rev, home1_5_rev, home2_5_rev)
      result << build_line(home1_5_rev, home2_5_rev, home1_5_rev, home2_5_rev)

      result << "\n"

      home_product = home1_5.cartesian_product(home2_5).map { |x|
        x.join("")
      }

      home_plus_product = home1_plus.cartesian_product(home2_plus).map { |x|
        x.join("")
      }

      result.concat(join_words(home_product))
      result.concat(join_words(home_plus_product))

      result.concat(repeat(home_plus_words_2, REP))
      result.concat(repeat(home_plus_words_3, REP))
      result.concat(repeat(home_plus_words_4, REP))

      result.concat(repeat(home_plus_product.map { |x|
        x.capitalize
      }, REP))
      result.concat(repeat(home_plus_words_2.map { |x|
        x.capitalize
      }, REP))
      result.concat(join_words(home_plus_words_3.map { |x| x.capitalize }))
      result.concat(join_words(home_plus_words_4.map { |x| x.capitalize }))
      return result
    end

    private def r1_lessons
      result = Array(String).new

      home1_r1 = build_keys(HOME1 + HOME1_5 + R1_LEFT)
      home2_r1 = build_keys(HOME2_5 + HOME2 + R1_RIGHT)

      home_r1 = home1_r1.cartesian_product(home2_r1).map { |x|
        x.join("")
      }

      result.concat(join_words(home_r1))

      home_r1_words_2 = get_words_n(home1_r1 + home2_r1, 2)
      home_r1_words_3 = get_words_n(home1_r1 + home2_r1, 3)
      home_r1_words_4 = get_words_n(home1_r1 + home2_r1, 4)

      result.concat(repeat(home_r1_words_2, REP))
      result.concat(repeat(home_r1_words_3, REP))
      result.concat(repeat(home_r1_words_4, REP))

      result.concat(join_words(home_r1_words_2.map { |x| x.capitalize }))
      result.concat(join_words(home_r1_words_3.map { |x| x.capitalize }))
      result.concat(join_words(home_r1_words_4.map { |x| x.capitalize }))

      return result
    end

    private def r3_lessons
      result = Array(String).new

      home1_r3 = build_keys(HOME1 + HOME1_5 + R3_LEFT)
      home2_r3 = build_keys(HOME2_5 + HOME2 + R3_RIGHT)

      home_r3 = home1_r3.cartesian_product(home2_r3).map { |x|
        x.join("")
      }

      result.concat(join_words(home_r3))

      home_r3_words_2 = get_words_n(home1_r3 + home2_r3, 2)
      home_r3_words_3 = get_words_n(home1_r3 + home2_r3, 3)
      home_r3_words_4 = get_words_n(home1_r3 + home2_r3, 4)

      result.concat(repeat(home_r3_words_2, REP))
      result.concat(repeat(home_r3_words_3, REP))
      result.concat(repeat(home_r3_words_4, REP))

      result.concat(join_words(home_r3_words_2.map { |x| x.capitalize }))
      result.concat(join_words(home_r3_words_3.map { |x| x.capitalize }))
      result.concat(join_words(home_r3_words_4.map { |x| x.capitalize }))

      return result
    end

    def to_s
      result = Array(String).new
      result.concat(home_lessons)
      result.concat(home_plus_lessons)
      result.concat(r3_lessons)
      result.concat(r1_lessons)

      return result.join("")
    end
  end
end
