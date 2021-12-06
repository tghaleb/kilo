module Kilo
  abstract class Singleton
    private def initialize
    end

    def self.instance
      @@instance ||= new
    end
  end
end
