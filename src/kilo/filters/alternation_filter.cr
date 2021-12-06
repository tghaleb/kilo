# Calculates Alternation between left and right hand.
module Kilo
  class AlternationFilter < AbstractFilter
    @bi_lookup = Array(Array(Tuple(UInt32, Int64))).new
    @min : Int16 = 0.to_i16
    @max : Int16 = 0.to_i16

    def initialize
    end

    # min is the minimum alternation ratio to accept.
    def initialize(characters, bigrams, min, max = 0.99)
      @min = (DATA_SCALE * min).to_i16
      @max = (DATA_SCALE * max).to_i16
      @bi_lookup = Utils.build_char_bigram_i(characters, bigrams)
    end

    def score : Int16
      return @score
    end

    def pass?(layout : UInt32) : Bool
      @score = 0.to_i16

      @bi_lookup.each_index do |i|
        @bi_lookup[i].each do |tup|
          # alternation means one is set and one isn't
          if Bits.bit_set?(i, layout) != Bits.bit_set?(tup[0], layout)
            @score += tup[1].to_i16
          end
        end
      end

      return (@score > @min) && (@score < @max)
    end
  end
end
