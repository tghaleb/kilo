module Kilo
  abstract class AbstractEvalFilter
    include Constants

    DEFAULT_MIN = 10_000.to_i16

    @score : Int16 = 0.to_i16
    @score_same_both : Int16 = 0.to_i16
    @min_hand : Int16 = DEFAULT_MIN
    @min_same_both : Int16 = DEFAULT_MIN
    property min_hand
    property min_same_both
    property score_same_both

    abstract def pass?(score : Score) : Bool
  end

  class NullEvalFilter < AbstractEvalFilter
    include Constants

    def pass?(score : Score) : Bool
      return true
    end
  end

  NULL_EVAL_FILTER = NullEvalFilter.new
end
