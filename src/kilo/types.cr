module Kilo
  alias FreqDataType = Hash(String, Hash(String, Int64))
  alias FreqLookupType = Hash(String, Hash(String, Float64))

  alias MapData = Hash(Constants::Key, Array(String))
  alias HeatMap = Hash(Constants::Key, Int64)
  alias MapConfig = NamedTuple(
    name: String, group: String, map: MapData, heat: HeatMap)

  alias UserLayout = NamedTuple(
    k32: String,
    name: String)

  alias SimpleScoresType = Hash(Symbol, Int16 | Array(UInt8) | String)

  NULL_SIMPLE_SCORES = SimpleScoresType{
    :hand    => 0.to_i16,
    :same    => 0.to_i16,
    :same_rp => 0.to_i16,
    :effort  => 0.to_i16,
  }
end
