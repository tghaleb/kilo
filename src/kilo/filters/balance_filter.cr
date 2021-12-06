# We score based on frequency distribution for left/right hand.
# given a set of 16 we add their frequency count and compare that to
# sum. We have
#
# ```
# score = @obj.simple_score
# ```
#
# which is lighter in weight and faster. Also, fast and most useful is,
#
# ```
# do-something unless @obj.pass?
# ```
#
# Will decide if score is good based on the delta given when
# initializing the object.
#
module Kilo
  class BalanceFilter < AbstractFilter
    @lookup : Array(Int64) = Array(Int64).new
    @delta : Int16 = 0.to_i16
    @score : Int16 = 0.to_i16

    def initialize
    end

    def initialize(characters, delta = 0.0)
      @delta = (delta * DATA_SCALE).to_i16
      @lookup = characters.data_i
    end

    private def delta : Int16
      return (@score - (DATA_SCALE/2).to_i16).abs
    end

    def score : Int16
      return @score
    end

    # Loops over bitmap and adds scores for present keys
    def pass?(layout : UInt32) : Bool
      @score = 0
      Bits.loop_over_set_bits(layout) do |x|
        @score += @lookup[x].to_i16
      end

      return delta < @delta
    end
  end
end
