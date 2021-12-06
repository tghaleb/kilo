require "./spec_helper"

describe Kilo::ProjectConfig do
  it "should initialize as a singleton" do
    obj = Kilo::ProjectConfig.instance
    obj.class.should eq(Kilo::ProjectConfig)
  end

  it "should return a tupple with config keys" do
    obj = Kilo::ProjectConfig.instance
    (obj.config.has_key? "characters").should eq(true)
    (obj.config.has_key? "corpus").should eq(true)
  end

  #  it "config should return defaults since not in a project directory" do
  #    defaults = Kilo::Constants::DEFAULT_PROJECT_CONFIG
  #    obj = Kilo::ProjectConfig.instance
  #    obj.config["characters"].should eq(defaults["characters"])
  #    obj.config["corpus"].should eq(defaults["corpus"])
  #  end
end
