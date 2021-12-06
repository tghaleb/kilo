require "./spec_helper"
require "process"

# FIXME:
# not written to be testable
# compliacted in testing

# module Kilo
#  # we need this so that we can
#  # test with a different corpi and in a different directory
#  class ProjectConfig < Singleton
#    def config
#      return {
#        "corpi_dir":  "tmp",
#        "corpus":     "test",
#        "ncr_dir":    "ncr",
#        "characters": %Q(abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789`~@#$%^&*()-_=+[{]}'"\\|,<.>/?€),
#      }
#    end
#  end
# end
#
def run_in_proj_dir
  Kilo::Experimental.mktmpdir do |dir|
    Dir.cd(dir) do
      proj = "proj"
      opts = Kilo::OptionsType.new
      Kilo::Init.new(opts, [proj]).run
      Dir.cd("proj") do
        yield
      end
      FileUtils.rm_r(proj)
    end
    puts dir
  end
end

describe Kilo::FreqData do
  #  it "should initialize as a singleton 1" do
  #    # just a test
  #    # dow we get the right config?
  #    run_in_proj_dir do
  #      Process.run("ls") do |io|
  #        line = ""
  #        while true
  #          begin
  #            line = io.output.read_line
  #            puts line
  #          rescue
  #            break
  #          end
  #        end
  #      end
  #    end
  #  end
  #  it "should initialize as a singleton" do
  #    # just a test
  #
  #    config_yaml = File.expand_path("spec/files/config.yaml")
  #    corpus = File.expand_path("spec/files/test")
  #
  #    run_in_proj_dir do
  #      FileUtils.cp(config_yaml, "config.yaml")
  #      FileUtils.cp(corpus, "test")
  #
  #      # this doesn't work because of working dir
  #      # obj = Kilo::FreqData.instance
  #      # copy config to out!
  #      # copy a corpus
  #      #   obj.class.should eq(Kilo::ProjectConfig)
  #    end
  #  end
end
