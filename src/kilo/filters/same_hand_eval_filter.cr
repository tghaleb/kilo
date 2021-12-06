module Kilo
  class SameHandEvalFilter < AbstractEvalFilter
    def initialize(@min = 10_000.to_i16)
    end

    def score : Int16
      return @score
    end

    def pass?(score : Score) : Bool
      @score = 0.to_i16

      @score = score.outward + score.jumps + score.same_finger_rp

      return @score < @min
    end
  end
end
