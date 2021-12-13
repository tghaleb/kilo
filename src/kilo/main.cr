require "./constants/constants"
require "./constants/layout_iso"
require "./constants/sql"
require "./constants/options"
require "./macros"
require "./types"
require "./utils"
require "./db"
require "./singleton"
require "./config/embedded"
require "./config/project_config"
require "./scorers/*"

require "./data/freq_hash"
require "./data/freq_data"
require "./export/image"
require "./export/xkb"
require "./export/type"

require "./score/score"
require "./score/layout_score.cr"
require "./filters/abstract_filter.cr"
require "./filters/abstract_eval_filter.cr"
require "./filters/abstract_oneside_filter.cr"
require "./filters/balance_filter.cr"
require "./filters/alternation_filter.cr"
require "./filters/fast_filter.cr"
require "./filters/onesided_filter.cr"
require "./filters/same_hand_eval_filter.cr"
require "./commands/command"
require "./commands/init"
require "./commands/freq"
require "./commands/eval"
require "./commands/query"
require "./commands/gen"
require "./commands/improve"
require "./commands/export"
require "./commands/compare"
require "./config/options"

module Kilo
  @@pwd : String = FileUtils.pwd
  class_property pwd

  class App
    def run
      Comandante::Cleaner.run do
        Embedded.embed
        Options.parse
      end
    end
  end
end
