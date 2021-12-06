module Kilo
  class OneSidedFilter < AbstractOneSideFilter
    include Constants
    @characters = FreqHash.new(1)
    @bi_lookup = Array(Array(Tuple(UInt32, Int64))).new
    @char_lookup = Array(Key).new(size: 32, value: Key::NONE)

    @score_adjacent_outward : Int64 = 0
    @score_same_finger_rp : Int64 = 0
    @score_jumps : Int64 = 0
    @score_positional_effort : Int64 = 0

    @min = 10_000.to_i16

    def initialize
    end

    def initialize(characters, bigrams, min)
      @characters = characters
      @bi_lookup = Utils.build_char_bigram_i(characters, bigrams)
      @min = min
    end

    def pass?(side : Array(UInt8), hand : Hand) : Bool
      reinit_scores
      # @score = 0.to_i16

      if hand == Hand::LEFT
        to_32 = ProjectConfig.instance.config[:left_to_32]
      else
        to_32 = ProjectConfig.instance.config[:right_to_32]
      end

      side.each_index { |i| @char_lookup[side[i]] = KEYS_32[to_32[i]] }

      scan_hand(side, hand)
      @score = (@score_same_finger_rp + @score_adjacent_outward +
                @score_jumps).to_i16
      return @score <= @min
    end

    private def reinit_scores
      @score = 0
      @score_jumps = 0
      @score_same_finger_rp = 0
      @score_adjacent_outward = 0
    end

    private def scan_hand(side : Array(UInt8), hand : Hand) : Nil
      kb_columns = ProjectConfig.instance.config[:kb_columns]

      index_pos = Utils.index_pos(hand)
      ring_pos = Utils.ring_pos(hand)

      side.each_index do |i|
        char_i = side[i]
        char_count = @characters.data_i[char_i]
        key1 = @char_lookup[char_i]
        col1 = kb_columns[key1]

        finger1 = Utils.which_finger(key1)

        @bi_lookup[char_i].each do |tup|
          idx = tup[0]

          # not same hand
          next if @char_lookup[idx] == Key::NONE

          count = tup[1]
          key2 = @char_lookup[idx]
          col2 = kb_columns[key2]
          finger2 = Utils.which_finger(key2)

          if Utils.same_hand?(finger1, finger2)
            if Utils.row_jump?(key1, key2)
              @score_jumps += count
            end

            case_finger(
              finger1: finger1,
              finger2: finger2,
              count: count,
              index_pos: index_pos,
              ring_pos: ring_pos,
            )
          end
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
        end
      elsif (Utils.finger_pos(finger1) + 1) == Utils.finger_pos(finger2)
        return if Utils.finger_pos(finger1) == index_pos
        @score_adjacent_outward += count
      end
    end
  end
end
