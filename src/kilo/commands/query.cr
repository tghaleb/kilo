module Kilo
  class Query < Command
    include Constants

    @db = DB_Helper.new
    @sql = DEFAULT_SELECT

    def run(
      global_opts : OptionsHash,
      opts : OptionsHash,
      args : Array(String)
    ) : Nil
      assert_inside_project_dir()
      opts_args(global_opts, opts, args)

      _db_file = @args[0]

      unless File.file? _db_file
        Cleaner.exit_failure("not a file '#{_db_file}'")
      end

      @sql = Utils.read_user_sql(
        @opts["sql"].to_s, default: DEFAULT_SELECT, limit: @opts["limit"].to_s)

      # Utils.update_score(_db_file, @opts["score"].to_s)

      @db = DB_Helper.new(_db_file)

      begin
        print_results(@sql)
      rescue e
        @db.close
        Cleaner.exit_failure("SQL: " + e.message.to_s)
      end

      @db.close
    end

    private def print_layout(layout)
      if @opts["layouts"]
        puts layout.layout + " " + layout.name
      else
        puts layout.to_string
        puts
      end
    end

    # Prints results in desired user format
    private def print_results(sql)
      layouts = Utils.query_layouts_db(@db, sql)

      if @opts["score"].as(Bool)
        layouts.each do |layout|
          layout.calculate_score
          @db.db.exec(UPDATE_SCORE_SQL, layout.score, layout.layout)
        end
        return
      end

      if @opts["yaml"]
        puts layouts.to_yaml
      elsif @opts["json"]
        puts layouts.to_json
      else
        layouts.each do |layout|
          print_layout(layout)
        end
      end
    end

    def finalize
      @db.close
    end
  end
end
