module Kilo
  class Eval < Command
    @db = DB_Helper.new
    @layouts = Array(UserLayout).new
    @layout_score = LayoutScore.new

    def run(
      global_opts : OptionsHash,
      opts : OptionsHash,
      args : Array(String)
    ) : Nil
      assert_inside_project_dir()
      opts_args(global_opts, opts, args)

      _layouts = args[0]

      unless File.file? _layouts
        Cleaner.exit_failure("not a file '#{_layouts}'")
      end

      if @opts["out"] != ""
        @db.close
        @db = Utils.create_db(@opts["out"].to_s)
      else
        Cleaner.exit_failure("--out option is required")
      end

      @layouts = Utils.load_user_layouts(_layouts)

      eval_layouts(@layouts, @db, @opts["score"].to_s)
    end

    # FIXME: use a constant
    def eval_layouts(layouts, db, score_script, filter = NULL_EVAL_FILTER) : Nil
      # data object for each layout
      # not efficient to do object per object what if all share same
      # characters, we need to group them?
      #       name Text,
      #       alternation Real,
      #       balance Real,
      #       effort Real,

      layouts.each do |x|
        layout = x[:k32]
        name = x[:name]
        # FIXME: score needs so class vars as well, else we can call
        # from outside try to minimize them and run?
        score = score(layout, name)

        if filter.pass?(score)
          db.db.exec(SQL_TBL_LAYOUTS_INSERT, *score.values)
        end
      end

      Utils.update_score(db.current_path, score_script, inplace: true)
      print_results(db)
      db.close
      # maybe return scores as well as an object, but that could be huge
      # so no
    end

    def print_results(db)
      return unless @opts["print"].as(Bool)

      db.query("select * from #{TBL_LAYOUTS} order by alternation") do |rs|
        Score.from_rs(rs).each do |x|
          puts x.to_string
          puts
        end
      end
    end

    private def score(layout_s, name) : Score
      new_chars = layout_s.split("").sort

      # this is an expensive test find a way to simplify it?
      # FIXME: maybe option for different characters then we use
      # expensive in that case only otherwise,
      # just cache the first one.
      # if @data.characters.sorted.sort != new_chars
      if @characters.sorted.sort != new_chars
        filter_characters(new_chars)

        @layout_score = LayoutScore.new(
          characters: @characters.clone,
          bigrams: @bigrams
        )
      end

      left, right = Utils.string_to_lr(layout_s, @characters)
      @layout_score.scan(left, right, layout_s, name)

      return @layout_score.score
    end
  end
end
