module Kilo
  include Comandante::OptParserTypes

  abstract class Command < CommandAction
    include Constants

    @characters : FreqHash = FreqHash.new(1)
    @bigrams : FreqHash = FreqHash.new(2)
    @verbose = false

    # to allow setting of opts for testing or calling one command from
    # another
    property opts
    property args
    property global_opts

    def initialize
    end

    def assert_inside_project_dir
      ProjectDirs.each do |d|
        unless File.exists? d
          Cleaner.exit_failure("not inside a project directory")
        end
      end
    end

    # creates dir if it doesn't exist
    private def ensure_exports_dir(dir)
      unless File.directory? dir
        Dir.mkdir_p(dir)
      end
    end

    # Initializes opts and args
    private def opts_args(global_opts, opts, args)
      @verbose = global_opts["verbose"].as(Bool)
      @global_opts = global_opts
      @opts = opts
      @args = args

      Helper.debug_inspect(opts, context: "@opts")
      Helper.debug_inspect(global_opts, context: "@global_opts")
      Helper.debug_inspect(args, context: "@args")
    end

    # Filters characters and bigrams, expensive operation
    private def filter_characters(filter)
      @characters = FreqData.instance.characters.filter_by(filter)
      @bigrams = FreqData.instance.bigrams.filter_by(filter)
    end

    abstract def run(
      global_opts : OptionsHash,
      opts : OptionsHash,
      args : Array(String)
    ) : Nil
  end
end
