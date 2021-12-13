module Kilo
  class LayoutScore
    include Constants
    @score = Score.new
    @characters = FreqHash.new(1)
    @bi_lookup = Array(Array(Tuple(UInt32, Int64))).new

    # to lookup char positions
    @char_lookup = Array(Key).new(size: 32, value: Key::NONE)

    @score_adjacent_outward : Int64 = 0
    @score_adjacent_inward : Int64 = 0
    @score_same_finger_rp : Int64 = 0
    @score_same_finger_im : Int64 = 0
    @score_rows = Array(Int64).new(size: 3, value: 0)
    @score_fingers = Array(Int64).new(size: 10, value: 0)
    @score_jumps : Int64 = 0
    @score_balance : Int64 = 0
    @score_alternation : Int64 = 0
    @score_positional_effort : Int64 = 0
    @score_text_direction : Int64 = 0
    @ltr = false

    def initialize
    end

    def initialize(characters, bigrams)
      @characters = characters

      @bi_lookup = Utils.build_char_bigram_i(characters, bigrams)

      @ltr = ProjectConfig.instance.config[:ltr].as(Bool)
    end

    def score : Score
      return @score
    end

    def scan(left : Array(UInt8), right : Array(UInt8), layout, name : String = "") : Nil
      left_to_32 = ProjectConfig.instance.config[:left_to_32]
      right_to_32 = ProjectConfig.instance.config[:right_to_32]

      left.each_index { |i| @char_lookup[left[i]] = KEYS_32[left_to_32[i]] }
      right.each_index { |i| @char_lookup[right[i]] = KEYS_32[right_to_32[i]] }

      reinit_scores

      scan_hand(left, Hand::LEFT) if left.size != 0
      scan_hand(right, Hand::RIGHT) if right.size != 0

      set_scores
      @score.name = name
      @score.layout = layout
    end

    # Calculations that are for both hands
    private def two_hand(
      hand : Hand,
      pos : Int32,
      count : Int64
    ) : Nil
      kb_weights = ProjectConfig.instance.config[:kb_weights]

      if hand == Hand::LEFT
        @score_balance += count
        @score_positional_effort += (kb_weights[Utils.key_32_left(pos)] * count).to_i16
      else
        @score_positional_effort +=
          (kb_weights[Utils.key_32_right(pos)] * count).to_i16
      end
    end

    # Scans one side and sets scores
    private def scan_hand(side : Array(UInt8), hand : Hand) : Nil
      kb_columns = ProjectConfig.instance.config[:kb_columns]

      index_pos = Utils.index_pos(hand)
      ring_pos = Utils.ring_pos(hand)

      side.each_index do |i|
        char_i = side[i]
        char_count = @characters.data_i[char_i]
        two_hand(hand: hand, pos: i, count: char_count)

        key1 = @char_lookup[char_i]
        col1 = kb_columns[key1]

        finger1 = Utils.which_finger(key1)

        # @bi_lookup[char_i].each_key do |idx|
        @bi_lookup[char_i].each do |tup|
          idx = tup[0]
          count = tup[1]
          key2 = @char_lookup[idx]
          col2 = kb_columns[key2]
          finger2 = Utils.which_finger(key2)
          # count = @bi_lookup[char_i][idx]

          if Utils.same_hand?(finger1, finger2)
            set_jumps(
              key1: key1,
              key2: key2,
              count: count,
            )
            case_finger(
              finger1: finger1,
              finger2: finger2,
              count: count,
              index_pos: index_pos,
              ring_pos: ring_pos,
            )
          else # Not same hand alternation
            @score_alternation += count
          end

          set_text_direction(
            col1: col1,
            col2: col2,
            count: count,
          )
        end

        set_per_hand(
          finger: finger1,
          key: key1,
          count: char_count
        )
      end
    end

    private def set_per_hand(
      finger : Finger,
      key : Key,
      count : Int64
    ) : Nil
      kb_rows = ProjectConfig.instance.config[:kb_rows]
      @score_rows[kb_rows[key].value - 1] += count
      @score_fingers[(finger.value)] += count
    end

    private def set_jumps(
      key1 : Key,
      key2 : Key,
      count : Int64
    ) : Nil
      if Utils.row_jump?(key1, key2)
        @score_jumps += count
      end
    end

    private def set_text_direction(
      col1 : Column,
      col2 : Column,
      count : Int64
    ) : Nil
      if @ltr
        if col1 <= col2
          @score_text_direction += count
        end
      else
        if col1 >= col2
          @score_text_direction += count
        end
      end
    end

    private def case_finger(
      finger1 : Finger,
      finger2 : Finger,
      count : Int64,
      index_pos : Int32,
      ring_pos : Int32
    ) : Nil
      if Utils.finger_pos(finger1) == Utils.finger_pos(finger2)
        if Utils.finger_pos(finger1) >= ring_pos
          @score_same_finger_rp += count
        else
          @score_same_finger_im += count
        end
      elsif Utils.finger_pos(finger1) == (Utils.finger_pos(finger2) + 1)
        return if Utils.finger_pos(finger2) == index_pos
        @score_adjacent_inward += count
      elsif (Utils.finger_pos(finger1) + 1) == Utils.finger_pos(finger2)
        return if Utils.finger_pos(finger1) == index_pos
        @score_adjacent_outward += count
      end
    end

    # Zeros scores at start
    private def reinit_scores
      @score_balance = 0
      @score_positional_effort = 0
      @score_alternation = 0
      # fixme can we clean without removing items
      @score_rows = Array(Int64).new(size: 3, value: 0)
      # @score_rows[0..-1] = 0
      @score_fingers = Array(Int64).new(size: 10, value: 0)
      # @score_fingers[0..-1] = 0
      @score_jumps = 0
      @score_same_finger_rp = 0
      @score_same_finger_im = 0
      @score_adjacent_outward = 0
      @score_adjacent_inward = 0
      @score_text_direction = 0
    end

    # Sets score on score object
    private def set_scores
      @score.rows = @score_rows
      @score.fingers = @score_fingers
      @score.balance = @score_balance.to_i16

      if @score_positional_effort > Int16::MAX
        @score.positional_effort = Int16::MAX
      else
        @score.positional_effort = (@score_positional_effort/EFFORT_SCALE).to_i16
      end

      @score.alternation = @score_alternation.to_i16
      @score.jumps = @score_jumps.to_i16
      @score.same_finger_rp = @score_same_finger_rp.to_i16
      @score.same_finger_im = @score_same_finger_im.to_i16
      @score.inward = @score_adjacent_inward.to_i16
      @score.outward = @score_adjacent_outward.to_i16
      @score.text_direction = @score_text_direction.to_i16
      @score.calculate_score
    end
  end
end
