module Kilo
  class FastFilter < AbstractFilter
    def initialize(filter : Array(Array(Int32)))
      @maps = Array(UInt32).new
      filter.each do |x|
        @maps << Bits.set_bits(0.to_u32, x)
      end
    end

    @[AlwaysInline]
    def pass?(layout : UInt32) : Bool
      @maps.each do |map|
        return true if (layout & map) == map
      end
      return false
    end
  end
end
