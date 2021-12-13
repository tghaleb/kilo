module Kilo
  module Scorers
    alias ScoreIntType = Int16
    ZERO_SCORE = 0.to_i16
    MAX_SCORE  = Int16::MAX
    MIN_SCORE  = Int16::MIN
    SCALE      = 10_000.to_i16
    HALF_SCALE = (SCALE / 2.0).to_i16
    QWERTY     = "qwertyuiop[asdfghjkl;'zxcvbnm,./".split("")

    class BaseScorer
      def score(stats) : ScoreIntType
        return ZERO_SCORE
      end

      # To make sure we don't have an overflow
      @[AlwaysInline]
      def scale(_score) : ScoreIntType
        if _score > MAX_SCORE
          return MAX_SCORE
        elsif _score < MIN_SCORE
          return MIN_SCORE
        end
        return _score.to_i16
      end

      @[AlwaysInline]
      def value_or_min(value, min)
        if value < min
          min
        else
          value
        end
      end
    end
  end
end
