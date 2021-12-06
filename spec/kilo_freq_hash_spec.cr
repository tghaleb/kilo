require "./spec_helper"
require "process"

def freq_hash_tester(obj, sum, size)
  obj.data_sum.should eq(sum)

  obj.data.size.should eq(size)

  obj.sorted.size.should eq(size)

  obj.sorted_rev.size.should eq(size)

  obj.data_i.size.should eq(size)

  obj.data_i.sum.should eq(obj.data.values.sum)
end

describe Kilo::FreqHash do
  it "append() should only initialize data at first" do
    obj = Kilo::FreqHash.new
    init_freq_hash(obj)

    obj.data_sum.should eq(0)
    obj.data_sum.should eq(0)
  end

  it "gen_lookups() should initialize all data" do
    obj = Kilo::FreqHash.new
    init_freq_hash(obj)
    obj.gen_lookups

    obj.key_length.should eq(1)

    obj.data_sum.should eq(TEST_TEXT.size)

    obj.data.size.should eq(UNIQ_CHARS)

    obj.sorted.size.should eq(UNIQ_CHARS)

    obj.sorted_rev.size.should eq(UNIQ_CHARS)

    obj.data_i.size.should eq(UNIQ_CHARS)
  end

  it "gen_lookups() should initialize all data for bigrams" do
    obj = Kilo::FreqHash.new(2)
    init_freq_hash(obj)
    obj.gen_lookups

    obj.key_length.should eq(2)

    # correction of -2, there will be depending on combinations a few
    # more or less
    obj.data_sum.should eq(TEST_TEXT.size - 1)

    data_count = obj.data.size

    obj.sorted.size.should eq(data_count)

    obj.sorted_rev.size.should eq(data_count)

    obj.data_i.size.should eq(data_count)

    # need to test key and lookup?
  end

  it "filter_by() should remove characters from data" do
    obj = Kilo::FreqHash.new
    init_freq_hash(obj)
    obj.gen_lookups

    data = ["m", "n"]
    # adds a shift

    obj2 = obj.filter_by(data)

    # freq_hash_tester(obj2, sum: 4, size: data.size)
    freq_hash_tester(obj2,
      sum: Kilo::Constants::DATA_SCALE, size: data.size)
  end

  it "filter_by() should be case sensitive" do
    obj = Kilo::FreqHash.new
    init_freq_hash(obj)
    obj.gen_lookups

    data = ["m", "n", "t", "A"]

    obj2 = obj.filter_by(data)

    freq_hash_tester(obj2, sum: Kilo::Constants::DATA_SCALE, size: data.size)
  end

  it "filter_by() should work with bigrams" do
    _obj = Kilo::FreqHash.new(2)
    init_freq_hash(_obj)
    _obj.gen_lookups

    _obj.key_length.should eq(2)

    obj = _obj.filter_by(["m", "e", "T"])

    # by trial and error
    res = Kilo::Constants::DATA_SCALE

    obj.data_sum.should eq(res)

    data_count = obj.data.size

    obj.sorted.size.should eq(data_count)

    obj.sorted_rev.size.should eq(data_count)

    obj.data_i.size.should eq(data_count)

    # need to test key and lookup?
  end

  it "has_keys?() should test if given keys are in data set" do
    obj = Kilo::FreqHash.new
    init_freq_hash(obj)
    obj.gen_lookups

    obj.has_keys?(["m", "o"]).should eq(true)
    obj.has_keys?(["m", "o", "z"]).should eq(false)
  end

  it "has_keys?() should work with bigrams" do
    obj = Kilo::FreqHash.new(2)
    init_freq_hash(obj)
    obj.gen_lookups

    obj.has_keys?(["m", "o"]).should eq(false)
    obj.has_keys?(["hi", "Th"]).should eq(true)
    obj.has_keys?(["hi", "Th", "zi"]).should eq(false)
  end

  it "missing_keys() should return missing keys or empty" do
    obj = Kilo::FreqHash.new(2)
    init_freq_hash(obj)
    obj.gen_lookups

    obj.missing_keys(["m", "o"]).should eq(["m", "o"])
    obj.missing_keys(["hi", "Th"]).should eq([] of String)
    obj.missing_keys(["hi", "Th", "zi"]).should eq(["zi"])
  end

  it "delete() should delete characters or keys with characters" do
    obj = Kilo::FreqHash.new(2)
    init_freq_hash(obj)
    obj.gen_lookups

    obj.missing_keys(["hi", "Th"]).should eq([] of String)
    obj.delete(["T", "h"])
    obj.missing_keys(["hi", "Th"]).should eq(["hi", "Th"])
  end

  it "to_yaml() should be implemented and working" do
    obj = Kilo::FreqHash.new
    init_freq_hash(obj)
    obj.gen_lookups

    obj.to_yaml.class.should eq(String)
  end
end
