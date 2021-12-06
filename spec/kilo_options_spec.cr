require "./spec_helper"

module Kilo::Options
  def self.options
    return @@options
  end
end

# describe Kilo::Options do
#  it "should be testable" do
#    options = [] of String
#    Kilo::Options.parse_options(options, testing: true)
#  end
#
#  it "should have the expected sub commands" do
#    options = [] of String
#    Kilo::Options.parse_options(options, testing: true)
#    opts = Kilo::Options.options
#
#    ["main", "init", "eval", "freq", "gen", "improve"].each do |k|
#      (opts.has_key? k).should eq(true)
#    end
#  end
# end
