require "./spec_helper"

alias Finger = Kilo::Constants::Finger

# describe Kilo::LayoutData do
#  #  it "maps[hand_maps] and is_left? is_right should work" do
#  #    obj = Kilo::LayoutData.new
#  #    hmaps = Kilo::LayoutData.maps_32["hand_maps"].as(Array(UInt32))
#  #    hmaps.size.should eq(2)
#  #    hmaps[0].popcount.should eq(Kilo::Constants::LEFT_TO_32.size)
#  #    hmaps[1].popcount.should eq(Kilo::Constants::RIGHT_TO_32.size)
#  #
#  #    Kilo::Helper.bits_to_string(hmaps[0]).should eq(
#  #      "0"*4 + "1"*6 + "0" * 6 + "1"*5 + "0"*6 + "1"*5)
#  #    Kilo::Helper.bits_to_string(hmaps[1]).should eq(
#  #      "1"*4 + "0"*6 + "1" * 6 + "0"*5 + "1"*6 + "0"*5)
#  #
#  #    x = 1.to_u32
#  #    Kilo::LayoutData.is_left?(x).should eq(true)
#  #    Kilo::LayoutData.is_right?(x).should eq(false)
#  #
#  #    y = (1.to_u32 << 31)
#  #    Kilo::LayoutData.is_left?(y).should eq(false)
#  #    Kilo::LayoutData.is_right?(y).should eq(true)
#  #
#  #    Kilo::LayoutData.same_hand?(x, y).should eq(false)
#  #    Kilo::LayoutData.same_hand?(x, x << 1).should eq(true)
#  #    Kilo::LayoutData.same_hand?(x, x << 11).should eq(true)
#  #    Kilo::LayoutData.same_hand?(x, x << 12).should eq(true)
#  #    Kilo::LayoutData.same_hand?(x, x << 10).should eq(false)
#  #  end
#  #
#  #  it "maps[row_maps] and in_row? should work" do
#  #    obj = Kilo::LayoutData.new
#  #    rmaps = Kilo::LayoutData.maps_32["row_maps"].as(Array(UInt32))
#  #    rmaps.size.should eq(5)
#  #    rmaps[1].popcount.should eq(11)
#  #    rmaps[2].popcount.should eq(11)
#  #    rmaps[3].popcount.should eq(10)
#  #
#  #    Kilo::Helper.bits_to_string(rmaps[1]).should eq("0"*21 + "1"*11)
#  #    Kilo::Helper.bits_to_string(rmaps[2]).should eq("0"*10 + "1"*11 +
#  #                                                    "0"*11)
#  #    Kilo::Helper.bits_to_string(rmaps[3]).should eq("1"*10 + "0"*22)
#  #
#  #    x = 1.to_u32
#  #    Kilo::LayoutData.in_row?(x, 1).should eq(true)
#  #    Kilo::LayoutData.in_row?(x, 2).should eq(false)
#  #    Kilo::LayoutData.in_row?(x, 3).should eq(false)
#  #
#  #    x = (1.to_u32 << 31)
#  #    Kilo::LayoutData.in_row?(x, 1).should eq(false)
#  #    Kilo::LayoutData.in_row?(x, 2).should eq(false)
#  #    Kilo::LayoutData.in_row?(x, 3).should eq(true)
#  #  end
#  #
#  #  it "maps[jump_map] and row_jump?(i1,i2) should work" do
#  #    jmap = Kilo::LayoutData.maps_32["jump_map"].as(UInt32)
#  #    jmap.popcount.should eq(21)
#  #
#  #    Kilo::Helper.bits_to_string(jmap).should eq("1"*10 + "0"*11 + "1"*11)
#  #
#  #    x = 1.to_u32
#  #    y = (1.to_u32 << 31)
#  #    z = (1.to_u32 << 2)
#  #
#  #    Kilo::LayoutData.row_jump?(x, y).should eq(true)
#  #    Kilo::LayoutData.row_jump?(x, z).should eq(false)
#  #  end
#  #  it "maps[finger_maps] and finger should work" do
#  #    obj = Kilo::LayoutData.new
#  #    fmaps = Kilo::LayoutData.maps_32["finger_maps"].as(Array(UInt32))
#  #    fmaps.size.should eq(10)
#  #
#  #    fmaps[0].popcount.should eq(3)
#  #    fmaps[1].popcount.should eq(3)
#  #    fmaps[2].popcount.should eq(3)
#  #    fmaps[3].popcount.should eq(7)
#  #    fmaps[4].popcount.should eq(0)
#  #
#  #    fmaps[5].popcount.should eq(0)
#  #    fmaps[6].popcount.should eq(5)
#  #    fmaps[7].popcount.should eq(3)
#  #    fmaps[8].popcount.should eq(3)
#  #    fmaps[9].popcount.should eq(5)
#  #
#  #    # puts
#  #    # puts Kilo::Helper.bits_to_string(fmaps[0])
#  #    # puts Kilo::Helper.bits_to_string(fmaps[1])
#  #    # puts Kilo::Helper.bits_to_string(fmaps[2])
#  #    # puts Kilo::Helper.bits_to_string(fmaps[3])
#  #    # puts Kilo::Helper.bits_to_string(fmaps[4])
#  #    # puts Kilo::Helper.bits_to_string(fmaps[5])
#  #    # puts Kilo::Helper.bits_to_string(fmaps[6])
#  #    # puts Kilo::Helper.bits_to_string(fmaps[7])
#  #    # puts Kilo::Helper.bits_to_string(fmaps[8])
#  #    # puts Kilo::Helper.bits_to_string(fmaps[9])
#  #    x = 1.to_u32
#  #    y = (1.to_u32 << 31)
#  #    z = x << 11
#  #    Kilo::LayoutData.which_finger(x).should eq(Finger::LF5)
#  #    Kilo::LayoutData.which_finger(y).should eq(Finger::RF5)
#  #
#  #    Kilo::LayoutData.same_finger?(x, y).should eq(false)
#  #    Kilo::LayoutData.same_finger?(x, z).should eq(true)
#  #
#  #    # Kilo::Helper.bits_to_string(rmaps[1]).should eq("0"*21 + "1"*11)
#  #    # Kilo::Helper.bits_to_string(rmaps[2]).should eq("0"*10 + "1"*11 +
#  #    #                                                "0"*11)
#  #    # Kilo::Helper.bits_to_string(rmaps[3]).should eq("1"*10 + "0"*22)
#  #
#  #    # x = 1.to_u32
#  #    # Kilo::LayoutData.in_row?(x, 1).should eq(true)
#  #    # Kilo::LayoutData.in_row?(x, 2).should eq(false)
#  #    # Kilo::LayoutData.in_row?(x, 3).should eq(false)
#  #
#  #    # x = (1.to_u32 << 31)
#  #    # Kilo::LayoutData.in_row?(x, 1).should eq(false)
#  #    # Kilo::LayoutData.in_row?(x, 2).should eq(false)
#  #    # Kilo::LayoutData.in_row?(x, 3).should eq(true)
#  #  end
#  #  it "lr_to_maps should work" do
#  #    left = Array(UInt8).new
#  #    right = Array(UInt8).new
#  #
#  #    [25, 18, 11, 15, 26, 3, 0, 1, 2, 6,
#  #     28, 27, 29, 21, 24, 31].each do |i|
#  #      left << i.to_u8
#  #    end
#  #
#  #    [30, 10, 12, 13, 16, 17, 9, 4, 5, 7,
#  #     8, 20, 14, 19, 22, 23].each do |i|
#  #      right << i.to_u8
#  #    end
#  #
#  #    maps = Kilo::LayoutData.lr_to_map32(left, right)
#  #    maps.size.should eq(32)
#  #    # puts
#  #
#  #    maps[25].should eq(1)
#  #    maps[18].should eq(2)
#  #    maps[11].should eq(4)
#  #    maps[15].should eq(8)
#  #    maps[26].should eq(16)
#  #    maps[30].should eq(32)
#  #    maps[10].should eq(64)
#  #    maps[12].should eq(128)
#  #    maps[13].should eq(256)
#  #
#  #    #    maps.each do |x|
#  #    #      puts Kilo::Helper.bits_to_string(x)
#  #    #    end
#  #  end
# end
