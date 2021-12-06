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
end
