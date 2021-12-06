module Kilo
  abstract class AbstractEvalFilter
    include Constants
    @score : Int16 = 0.to_i16
    @min : Int16 = 10_000.to_i16
    property min

    abstract def pass?(score : Score) : Bool
  end

  class NullEvalFilter < AbstractEvalFilter
    include Constants
    @score : Int16 = 0.to_i16

    def pass?(score : Score) : Bool
      return true
    end
  end

  NULL_EVAL_FILTER = NullEvalFilter.new
end
