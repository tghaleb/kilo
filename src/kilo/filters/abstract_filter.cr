module Kilo
  abstract class AbstractFilter
    include Constants
    @score : Int16 = 0.to_i16

    abstract def pass?(layout : UInt32) : Bool
  end
end
