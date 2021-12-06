module Kilo
  class Freq < Command
    include Constants

    def run(
      global_opts : OptionsHash,
      opts : OptionsHash,
      args : Array(String)
    ) : Nil
      assert_inside_project_dir()

      Helper.timer { obj = FreqData.instance(opts["from-bigrams"].to_s) }

      if opts["data"]
        FreqData.instance.print_data
      end

      if opts["info"]
        FreqData.instance.print_info
      end

      if opts["bigrams"]
        FreqData.instance.export_bigrams
      end
      if opts["characters"]
        FreqData.instance.print_chars
      end
    end
  end
end
