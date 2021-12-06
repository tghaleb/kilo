module Kilo
  abstract class AbstractOneSideFilter
    include Constants
    @score : Int16 = 0.to_i16
    @effort : Int16 = 0.to_i16
    @min : Int16 = 10_000.to_i16
    @max_effort : Int16 = 10_000.to_i16

    getter score
    getter effort
    property min
    property max_effort

    abstract def pass?(side : Array(UInt8), hand : Hand) : Bool
  end
end
