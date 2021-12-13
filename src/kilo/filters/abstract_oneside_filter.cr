module Kilo
  abstract class AbstractOneSideFilter
    include Constants

    DEFAULT_MIN = 10_000.to_i16

    @score : Int16 = 0.to_i16
    @score_same_both : Int16 = 0.to_i16
    @effort : Int16 = 0.to_i16
    @min_hand : Int16 = 10_000.to_i16
    @min_same_both : Int16 = DEFAULT_MIN
    @max_effort : Int16 = DEFAULT_MIN

    getter score
    getter score_same_both
    getter effort
    property min_same_both
    property min_hand
    property max_effort

    abstract def pass?(side : Array(UInt8), hand : Hand) : Bool
  end
end
