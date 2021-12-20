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

  alias SideType = Array(UInt8)
  # alias SimpleScoresType = Hash(Symbol, Int16 | SideType | String)
  alias SimpleScoresType = Hash(Symbol, Int16)

  NULL_SIMPLE_SCORES = SimpleScoresType{
    :effort         => 0.to_i16,
    :outward        => 0.to_i16,
    :jumps          => 0.to_i16,
    :hand           => 0.to_i16,
    :hand_im        => 0.to_i16,
    :same_finger_rp => 0.to_i16,
    :same_finger_im => 0.to_i16,
    :same_both      => 0.to_i16,
    :same_both_j    => 0.to_i16,
  }

  alias KBWeightsConfType = Hash(Constants::Key, Int32)
  alias KBFingersConfType = Hash(Constants::Key, Constants::Finger)
  alias KBRowsConfType = Hash(Constants::Key, Constants::Row)
  alias KBColumnsConfType = Hash(Constants::Key, Constants::Column)
  alias XKBListType = Hash(String, String)
  alias SideTo32Type = Array(Int32)

  alias ImproveConfigType = NamedTuple(
    stage2_count: Int16,
    effort_delta: Int16,
    filter_factor: Float64,

    # used for SQL WHERE
    sql_half_same_finger_rp: Int16,
    sql_half_same_finger_im: Int16,
    sql_half_outward: Int16,
    sql_half_jumps: Int16,

    # used to filter stage 1
    max_half_same_finger_rp: Int16,
    max_half_same_finger_im: Int16,
    max_half_hand: Int16)
end
