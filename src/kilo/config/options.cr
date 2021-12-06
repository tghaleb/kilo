module Kilo
  module Options
    include Constants

    def self.parse
      opts = OptParser.new(Constants::NAME, LABEL)

      opts.append_option(VERBOSE_OPT)
      opts.append_option(DEBUG_OPT)
      opts.append_option(COLOR_OFF_OPT)
      opts.append_option(VERSION_OPT)

      opts.append(EVAL_OPTS)
      opts.append(EXPORT_OPTS)
      opts.append(FREQ_OPTS)
      opts.append(GEN_OPTS)
      opts.append(IMPROVE_OPTS)
      opts.append(INIT_OPTS)
      opts.append(QUERY_OPTS)
      opts.append(COMPARE_OPTS)

      opts.parse
    end
  end
end
