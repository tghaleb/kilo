module Kilo
  module Scorers
    #    alias ScoreIntType = Int16
    #    ZERO_SCORE = 0.to_i16
    #    MAX_SCORE  = Int16::MAX
    #    MIN_SCORE  = Int16::MIN
    #    SCALE      = 10_000.to_i16
    #    HALF_SCALE = (SCALE / 2.0).to_i16
    #    QWERTY     = "qwertyuiop[asdfghjkl;'zxcvbnm,./".split("")
    #
    #    class BaseScorer
    #      def score(stats) : ScoreIntType
    #        return ZERO_SCORE
    #      end
    #
    #      # To make sure we don't have an overflow
    #      @[AlwaysInline]
    #      def scale(_score) : ScoreIntType
    #        if _score > MAX_SCORE
    #          return MAX_SCORE
    #        elsif _score < MIN_SCORE
    #          return MIN_SCORE
    #        end
    #        return _score.to_i16
    #      end
    #
    #      @[AlwaysInline]
    #      def value_or_min(value, min)
    #        if value < min
    #          min
    #        else
    #          value
    #        end
    #      end
    #    end
    #
    class DefaultScorer < BaseScorer
      # We do the reading
      alias WeightsConfig = NamedTuple(
        hand: Float64,
        effort: Float64,
        direction: Float64,
        balance: Float64,
        fingers: Float64)

      alias HandWeightsConfig = NamedTuple(
        jumps: Float64,
        outward: Float64,
        same_finger_rp: Float64,
        same_finger_im: Float64)

      alias FingerWeightsConfig = NamedTuple(
        indices: Float64,
        middles: Float64,
        rings: Float64,
        pinkies: Float64)

      alias FingerLevelsConfig = NamedTuple(
        indices: Int16,
        middles: Int16,
        rings: Int16,
        pinkies: Int16)

      alias MinConfig = NamedTuple(
        jumps: Int16,
        outward: Int16,
        same_finger_rp: Int16,
        same_finger_im: Int16)

      alias PenaltiesConfig = NamedTuple(
        alternation: Int16,
        text_direction: Int16,
        effort: Int16,
        balance_delta: Int16)

      alias DefaultScorerConfType = NamedTuple(
        weights: WeightsConfig,
        hand_weights: HandWeightsConfig,
        finger_weights: FingerWeightsConfig,
        finger_levels: FingerLevelsConfig,
        min: MinConfig,
        penalties: PenaltiesConfig,
        qwerty_bonus_point: Int16)

      @config : DefaultScorerConfType

      def initialize
        @config =
          Comandante::Helper::YamlTo(DefaultScorerConfType).load(
            Embedded.read(:default_scorer), ":default_scorer")
      end

      def score(stats) : ScoreIntType
        _score = 0
        _score += score_hand(
          jumps: stats.jumps,
          outward: stats.outward,
          rp: stats.same_finger_rp,
          im: stats.same_finger_im)
        _score += score_alternation(stats.alternation)
        _score += score_text_direction(stats.text_direction)
        _score += score_positional_effort(stats.positional_effort)
        _score += score_balance(stats.balance)
        _score += score_qwerty(stats.layout)
        _score += score_fingers(
          indices: stats.indices,
          middles: stats.middles,
          rings: stats.rings,
          pinkies: stats.pinkies,
        )

        scale(_score)
      end

      # Similarity with qwerty gets some points
      def score_qwerty(layout)
        return 0 if layout.size != 32
        _score = 0
        layout.split("").each_index do |i|
          _score += @config[:qwerty_bonus_point] if layout[i] == QWERTY[i]
        end
        _score
      end

      # The main scoring criteria: jumps, outward, same_finger_rp
      # edit HAND_WEIGHTS to change bias here
      def score_hand(jumps, outward, rp, im)
        _sum = get_jumps(jumps) + get_outward(outward) +
               get_same_finger_rp(rp) + +get_same_finger_im(im)

        hand_score = scale((100.0 / _sum) * SCALE)
        (hand_score * @config[:weights][:hand])
      end

      def get_hand_value(value, key)
        value_or_min(value, @config[:min][key]) * @config[:hand_weights][key]
      end

      def get_jumps(value)
        get_hand_value(value, :jumps)
      end

      def get_outward(value)
        get_hand_value(value, :outward)
      end

      def get_same_finger_rp(value)
        get_hand_value(value, :same_finger_rp)
      end

      def get_same_finger_im(value)
        get_hand_value(value, :same_finger_im)
      end

      def get_balance_delta(value)
        value_or_min(value, @config[:penalties][:balance_delta])
      end

      # Less that ALTERNATION_LEVEL gets a penalty
      def score_alternation(value)
        value - @config[:penalties][:alternation]
      end

      # Penalties below EFFORT_LEVEL
      def score_positional_effort(value)
        _score = (@config[:penalties][:effort] / value) * SCALE
        _score * @config[:weights][:effort]
      end

      #  # Less that TEXT_DIRECTION_LEVEL gets a penalty
      def score_text_direction(value)
        return value - @config[:penalties][:text_direction]
        #
        #    # FIXME: remove this
        #    _score = 0
        #    if value > MAX_DIRECTION
        #      _score = SCALE
        #    elsif value > MIN_DIRECTION
        #      _score = (value - MIN_DIRECTION) * DIRECTION_FACTOR
        #    end
        #    return _score * DIRECTION_WEIGHT
      end

      def get_fingers(value, name)
        (@config[:finger_levels][name].to_f / value) * SCALE * @config[:finger_weights][name]
      end

      def score_fingers(indices, middles, rings, pinkies)
        _score = 0

        _score += get_fingers(middles, :indices)
        _score += get_fingers(middles, :middles)
        _score += get_fingers(rings, :rings)
        _score += get_fingers(pinkies, :pinkies)

        _score * @config[:weights][:fingers]
      end

      # No points if not within BALANCE_DELTA
      def score_balance(value)
        # unless within range no points
        _score = 0

        delta = get_balance_delta((HALF_SCALE - value).abs)
        balance_delta = @config[:penalties][:balance_delta]

        _score = (balance_delta.to_f / delta) * SCALE if delta == balance_delta
        _score * @config[:weights][:balance]
      end
    end

    # DIRECTION_FACTOR = SCALE / (MAX_DIRECTION - MIN_DIRECTION)
  end
end
