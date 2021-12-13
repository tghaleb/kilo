module Kilo
  module Constants
    include Comandante
    include Comandante::OptParserTypes

    class ColorOffAction < OptionAction
      def run(
        parser : OptParser,
        id : String,
        value : OptionValue
      ) : OptionValue
        Colorize.enabled = false if value
        value
      end
    end

    class DebugAction < OptionAction
      def run(
        parser : OptParser,
        id : String,
        value : OptionValue
      ) : OptionValue
        Comandante::Cleaner.debug = true
        value
      end
    end

    class VersionAction < OptionAction
      def run(
        parser : OptParser,
        id : String,
        value : OptionValue
      ) : OptionValue
        STDERR.puts(VERSION)
        Comandante::Cleaner.exit_success
        value
      end
    end

    VERBOSE_OPT = OptionConfig.new(
      name: "verbose",
      short: "v",
      label: "verbose mode.",
      simple_action: OptParser::OptProc.new { |v| Cleaner.verbose = true }
    )

    VERSION_OPT = OptionConfig.new(
      name: "version",
      label: "display version and exit.",
      action: VersionAction.new
    )

    COLOR_OFF_OPT = OptionConfig.new(
      name: "no-color",
      short: "C",
      label: "color mode off.",
      action: ColorOffAction.new
    )

    DEBUG_OPT = OptionConfig.new(
      name: "debug",
      short: "D",
      label: "debug mode.",
      action: DebugAction.new
    )

    LABEL = %q{
      _    _ _
     | | _(_) | ___
     | |/ / | |/ _ \
     |   <| | | (_) |
     |_|\_\_|_|\___/  }.gsub(/^\n/, "").colorize(:cyan).to_s + LABEL_TEXT

    LABEL_TEXT = "A keyboard layout optimizer."

    SQL_OPT = OptionConfig.new(
      name: "sql",
      short: "q",
      label: "Sql file to use for selection.",
      option_type: OptionStyle::Option,
      argument_string: "FILE"
    )

    SQL_LIMIT = OptionConfig.new(
      name: "limit",
      short: "l",
      label: "Sql LIMIT for selection.",
      option_type: OptionStyle::Option,
      argument_string: "NUMBER",
      default: "1000000000"
    )

    SCORE_OPT =
      OptionConfig.new(
        name: "score",
        short: "s",
        label: "regenerate user_score and exists.",
      )

    OUT_DB_OPT = OptionConfig.new(
      name: "out",
      short: "o",
      label: "Db file to write results to.",
      option_type: OptionStyle::Option,
      argument_string: "DB"
    )

    EVAL_OPTS = CommandConfig.new(
      name: "eval",
      label: "Evaluates keyboard layouts from file.",
      description: <<-E.to_s,
                layouts file is a text file with one layout per line.
                Each line is a 32-character layout and optional name.
                When not given an out, will write to stdout.
    
                Example:
                  #{Constants::NAME} eval --out layouts.db layouts.txt
                E

      action: Eval.new,
      arguments_string: "LAYOUTS.txt",
      arguments_range: 1..1,
      options: [
        OUT_DB_OPT,
        #        OptionConfig.new(
        #          name: "print",
        #          short: "p",
        #          label: "Prints to STDOUT.",
        #        ),
      ],
    )

    EXPORT_OPTS = CommandConfig.new(
      name: "export",
      label: "Exports to svg, xkb config, and typing lessons.",
      description: <<-E.to_s,
         EXAMPLES 

         First you'll want to create templates for layouts from a LAYOUTS file 
         with --create-templates. 

           #{Constants::NAME} export --create-templates layouts.txt

         Next, you can edit the generated templates in your maps/ directory and add
         missing values for keys. You will probably also want to create a grouping file 
         which will bind certain characters together. For example lowercase characters
         with their uppercase counterparts, etc.

         Finally you can export

           #{Constants::NAME} export --image --xkb --typing --short-typing maps/candidate1.yaml

           #{Constants::NAME} export --xkb --use-group maps/group.yaml maps/candidate1.yaml
         E

      action: Export.new,
      arguments_range: 0..MAX_ARGS,
      arguments_string: "MAP-CONFIG.yaml ...",
      options: [
        OptionConfig.new(
          name: "image",
          short: "i",
          label: "Exports layout as svg image.",
        ),

        OptionConfig.new(
          name: "heat-map",
          short: "m",
          label: "Exports layout with heat-map as svg image.",
        ),

        OptionConfig.new(
          name: "weights",
          short: "w",
          label: "Exports weights as svg image.",
        ),

        OptionConfig.new(
          name: "typing",
          short: "t",
          label: "Exports layout as text lessons for typing.",
        ),

        OptionConfig.new(
          name: "short-typing",
          short: "s",
          label: "Exports layout as short text lessons for typing.",
        ),

        OptionConfig.new(
          name: "xkb",
          short: "x",
          label: "Exports layout as xkb config for X (Linux).",
        ),
        OptionConfig.new(
          name: "create-templates",
          short: "T",
          label: "Writes a template to file.",
          option_type: OptionStyle::Option,
          argument_string: "FILE",
        ),
        OptionConfig.new(
          name: "use-group",
          short: "g",
          label: "Use given key grouping yaml file.",
          option_type: OptionStyle::Option,
          argument_string: "FILE",
        ),
      ],
    )

    FREQ_OPTS = CommandConfig.new(
      name: "freq",
      label: "Calculates letter frequency from configured corpus.",
      description: <<-E.to_s,
              To build corpus data the first time you just call it
              without arguments. Will use corpus defined in config file.

              Example:
                #{Constants::NAME} freq
              E

      action: Freq.new,
      arguments_range: 0..0,
      options: [
        OptionConfig.new(
          name: "info",
          short: "i",
          label: "Shows info for configured corpus.",
          default: false
        ),
        OptionConfig.new(
          name: "data",
          short: "a",
          label: "Prints all the freqency data of configured corpus",
          default: false
        ),
        OptionConfig.new(
          name: "bigrams",
          short: "b",
          label: "Exports bigrams of configured corpus",
          default: false
        ),
        OptionConfig.new(
          name: "characters",
          short: "c",
          label: "Exports characters in order as a string",
          default: false
        ),
        OptionConfig.new(
          name: "from-bigrams",
          short: "f",
          label: "Uses bigram files (json/yaml) to generate the data
    instead",
          argument_string: "FILE",
          option_type: OptionStyle::Option,
        ),

      ],
    )

    GEN_OPTS = CommandConfig.new(
      name: "gen",
      label: "Generates candidate layouts worth considering.",
      description: <<-E.to_s,
              Example:
                #{Constants::NAME} gen
                #{Constants::NAME} gen --best 10 > top10.raw.txt
              E

      arguments_range: 0..0,
      action: Gen.new,
      options: [
        OptionConfig.new(
          name: "best",
          short: "p",
          label: "Prints candidate layouts by alternation (letters ordered by best effort).",
          option_type: OptionStyle::Option,
          argument_string: "COUNT",
          default: 0,
        ),
        OptionConfig.new(
          name: "export-fast",
          short: "e",
          label: "Generates and exports fast config for fast generation filter.",
        ),
        OptionConfig.new(
          name: "fast",
          short: "f",
          label: "Generates faster using a high scoring patterns.",
          option_type: OptionStyle::Option,
          argument_string: "FILE"
        ),
        OptionConfig.new(
          name: "dryrun",
          label: "Dryrun mode.",
        ),
      ],
    )

    IMPROVE_OPTS = CommandConfig.new(
      name: "improve",
      label: "Optimizes given layouts",
      arguments_range: 1..MAX_ARGS,
      description: <<-E.to_s,
             Example:
               #{Constants::NAME} improve --layouts top10.raw.txt
                 --out top10.db sql/improve-*.sql
             E

      arguments_string: "SQL-FILE ...",
      action: Improve.new,
      options: [
        OptionConfig.new(
          name: "layouts",
          label: "Input layouts file (Required)",
          option_type: OptionStyle::Option,
          argument_string: "FILE",
        ),
        OptionConfig.new(
          name: "fast",
          label: "generates only one better layout, for debuging mostly",
        ),
        OUT_DB_OPT,
        SQL_LIMIT,
      ],
    )

    INIT_OPTS = CommandConfig.new(
      name: "init",
      label: "Intializes a new project in current directory.",
      description: <<-E.to_s,
            Creates directory tree for new project and copies default
            configuratin files.
 
            Example:
              #{Constants::NAME} init new-project
            E
      action: Init.new,
      arguments_string: "PROJECT-NAME",
      arguments_range: 1..1
    )

    QUERY_OPTS = CommandConfig.new(
      name: "query",
      label: "Queries a database.",
      description: <<-E.to_s,
              Example:
                Query a database printing everything to STDOUT
                  #{Constants::NAME} query top10.db
                Query a database selecting using a user sql
                  #{Constants::NAME} query top10.db --sql sql/final.sql
                Regenerate score and print verything to STDOUT
                  #{Constants::NAME} query --score
              E

      arguments_range: 1..1,
      arguments_string: "DB",
      action: Query.new,
      options: [
        OptionConfig.new(
          name: "yaml",
          label: "Results in yaml format.",
        ),

        OptionConfig.new(
          name: "json",
          label: "Results in json format.",
        ),
        SCORE_OPT,
        SQL_OPT,
        SQL_LIMIT,
        OptionConfig.new(
          name: "layouts",
          label: "Prints layouts matching sql.",
        ),
      ],
    )

    COMPARE_OPTS = CommandConfig.new(
      name: "compare",
      label: "Compares layouts from a database.",
      description: <<-E.to_s,
              Example:
                  #{Constants::NAME} compare top10.db
              E
      arguments_range: 1..1,
      arguments_string: "DB",
      action: Compare.new,
      options: [
        OptionConfig.new(
          name: "full",
          label: "Generate extra digrams.",
        ),
        SQL_OPT,
        SQL_LIMIT,

      ],
    )
  end
end
