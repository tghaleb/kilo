require "ecr"

module Kilo
  # For creation of xkb config for Linux.
  class XKB
    property map

    @@xkb_lookup : Hash(String, String) = Hash(String, String).new

    def initialize(@map : MapConfig)
      if @@xkb_lookup.empty?
        @@xkb_lookup = ProjectConfig.instance.config[:xkb_list]
      end
    end

    ECR.def_to_s "data/xkb.ecr"
  end
end
