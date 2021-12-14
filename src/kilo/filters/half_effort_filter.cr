module Kilo
  class HalfEffortFilter
    include Constants
    @characters = FreqHash.new(1)
    @side_to_32 = Array(Int32).new
    @score : Int16 = 0.to_i16
    @min : Int16 = 10_000.to_i16
    @kb_weights : Hash(Key, Int32)
    @index_by_weight = Array(Int32).new

    property min
    property characters
    property side_to_32
    property index_by_weight

    def initialize
      @kb_weights = ProjectConfig.instance.config[:kb_weights]
    end

    def initialize(@characters, @side_to_32, @index_by_weight)
      @kb_weights = ProjectConfig.instance.config[:kb_weights]
    end

    def score
      if @score > Int16::MAX
        return Int16::MAX
      else
        return (@score/EFFORT_SCALE).to_i16
      end
    end

    def pass_w_ordered?(side) : Bool
      return scan_w_ordered(side) <= @min
    end

    def pass?(side) : Bool
      return scan(side) <= @min
    end

    # In general during improvements we will not be using position ordered
    def scan_w_ordered(side)
      @score = 0.to_i16
      side.each_index do |i|
        index = @side_to_32[@index_by_weight[i]]
        w = @characters.data_i[side[i]]
        key = KEYS_32[index]
        @score += (@kb_weights[key] * w)
      end

      return score
    end

    # User for position ordered, only for actual left/right or before exports.
    def scan(side)
      @score = 0.to_i16
      side.each_index do |i|
        index = @side_to_32[i]
        w = @characters.data_i[side[i]]
        key = KEYS_32[index]
        @score += (@kb_weights[key] * w)
      end

      return score
    end
  end
end
