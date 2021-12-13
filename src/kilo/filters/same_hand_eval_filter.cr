module Kilo
  class SameHandEvalFilter < AbstractEvalFilter
    # FIXME: add a min for effort and three passes
    @min_effort : Int16 = 5_000.to_i16
    @score_effort : Int16 = 0.to_i16
    @score_same_rp : Int16 = 0.to_i16

    property min_effort
    property score_effort
    property score_same_rp

    def initialize(@min_hand = DEFAULT_MIN, @min_same_both = DEFAULT_MIN)
    end

    def score : Int16
      return @score
    end

    def effort_pass?(score)
      return true
    end

    def same_hand_pass?(score)
      return true
    end

    def hand_pass?(score)
      return true
    end

    def pass?(score : Score) : Bool
      @score = 0.to_i16
      @score_same_both = 0.to_i16
      @score_effort = 0.to_i16

      @score = score.outward + score.jumps + score.same_finger_rp
      @score_same_both = score.same_finger_rp + score.same_finger_im
      @score_same_rp = score.same_finger_rp
      @score_effort = score.positional_effort

      return (@score_effort <= @min_effort) && ((@score <= @min_hand) && (@score_same_both <=
        @min_same_both))
    end
  end
end
