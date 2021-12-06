require "big"

# require "gc"

module Kilo
  class EffortFilter
    @characters = FreqHash.new(1)
    @side_to_32 = Array(Int32).new
    @score : Int16 = 0.to_i16

    def initialized
      @kb_weights = ProjectConfig.instance.config[:kb_weights]
    end

    def initialized(@characters, @side_to_32)
      @kb_weights = ProjectConfig.instance.config[:kb_weights]
    end

    def score
      (@score/EFFORT_SCALE).to_i16
    end

    # use an object
    def scan(side)
      @score = 0.to_i16
      side.each_index do |i|
        index = @side_to_32[i]
        w = @characters.data_i[index]
        key = KEYS_32[index]
        @score += (@kb_weights[key] * w)
      end
      return score
    end
  end

  class Improve < Command
    PERMUTATIONS_MAX =   9
    FILTER_FACTOR    = 1.1
    SAME_HAND_MAX    = 500.to_i16

    @db = DB_Helper.new
    @layout_score = LayoutScore.new
    @layouts = Array(UserLayout).new
    @left_32_index_by_weight : Array(Int32)
    @right_32_index_by_weight : Array(Int32)
    @slow = 0
    @left_sided_filter = OneSidedFilter.new
    @right_sided_filter = OneSidedFilter.new
    @l_effort_score = EffortFilter.new
    @r_effort_score = EffortFilter.new

    def initialize
      super

      left_to_32 = ProjectConfig.instance.config[:left_to_32]
      right_to_32 = ProjectConfig.instance.config[:right_to_32]

      @left_32_index_by_weight = Utils.index_by_weight(side_to_32: left_to_32)
      @right_32_index_by_weight = Utils.index_by_weight(side_to_32: right_to_32)

      @eval = Eval.new

      @lr_filter = SameHandEvalFilter.new(SAME_HAND_MAX)
    end

    def run(
      global_opts : OptionsHash,
      opts : OptionsHash,
      args : Array(String)
    ) : Nil
      assert_inside_project_dir()
      opts_args(global_opts, opts, args)

      @args.each do |x|
        Helper.assert_file(x)
      end

      _layouts = @opts["layouts"].to_s

      @slow = @opts["slow"].to_s.to_i

      Helper.assert_file(_layouts)

      @layouts = Utils.load_user_layouts(_layouts)

      out_db = @opts["out"].to_s
      Helper.timer {
        improve_layouts(out_db)
        add_scores(out_db) if out_db != ""
      }
    end

    private def do_join(left_lookup, right_lookup) : Array(String)
      results = Array(String).new

      right_lookup.each_key do |k|
        unless left_lookup.has_key? k
          Cleaner.exit_failure("layout #{k} is missing in the left file")
        end
        val_r = right_lookup[k]
        val_l = left_lookup[k]
        lefts = Array(Array(UInt8)).new
        rights = Array(Array(UInt8)).new

        char_array = (val_r[0] + val_l[0]).split("").uniq
        filter_characters(char_array)
        chars = @characters

        val_r.each_index do |i|
          tmp, right = Utils.string_to_lr(val_r[i], chars)
          rights << right
        end
        val_l.each_index do |i|
          left, tmp = Utils.string_to_lr(val_l[i], chars)
          lefts << left
        end

        counter = 0
        lefts.each_cartesian(rights) do |x|
          results << Utils.lr_to_string(x[0], x[1], chars.sorted) + " " + k + "-" + counter.to_s
          counter += 1
        end
      end
      return results
    end

    private def db_exists?(name) : Bool
      if name == ""
        Cleaner.exit_failure("a layout name is required for optimization")
      end

      if File.file? db_name(name, "left")
        return true
      else
        return false
      end
    end

    # We selection with sql to find best results
    private def improved_selection(name)
      layouts_left = Array(Score).new
      layouts_right = Array(Score).new

      # We read from db
      db_left = DB_Helper.new(db_name(name, "left"))
      db_right = DB_Helper.new(db_name(name, "right"))

      @args.each do |file|
        sql = Utils.read_user_sql(
          file.to_s, default: DEFAULT_SELECT, limit: @opts["limit"].to_s)
        layouts_left.concat(Utils.query_layouts_db(db_left, sql))
        layouts_right.concat(Utils.query_layouts_db(db_right, sql))
      end

      db_left.close
      db_right.close

      return {layouts_left.uniq, layouts_right.uniq}
    end

    # Returns a lookup for layouts by name
    private def build_layouts_lookup(layouts)
      layouts_lookup = Hash(String, Array(String)).new

      layouts.each do |x|
        unless layouts_lookup.has_key? x.name
          layouts_lookup[x.name] = Array(String).new
        end
        layouts_lookup[x.name] << x.layout
      end

      return layouts_lookup
    end

    private def improve_layouts(db_out)
      Helper.put_verbose("hi")
      @layouts.each do |x|
        name = x[:name]

        if db_exists? name
          STDERR.puts ("* #{name} already improved.")
        else
          Helper.timer {
            improve(x)
          }
          add_left_right_scores(name)
        end

        layouts_left, layouts_right = improved_selection(name)

        layouts_lookup_left = build_layouts_lookup(layouts_left)
        layouts_lookup_right = build_layouts_lookup(layouts_right)
        next if layouts_lookup_left.empty? || layouts_lookup_right.empty?

        results = do_join(layouts_lookup_left, layouts_lookup_right)

        save_results(results, db_out)
      end
    end

    private def setup_eval_options(db_out)
      options = OptionsHash.new
      options["out"] = db_out
      options["print"] = false
      options["score"] = @opts["score"]

      score_script = @opts["score"].to_s

      unless score_script == ""
        score_script = File.join(Kilo.pwd, score_script)
      end
      return options, score_script
    end

    private def save_results(results, db_out)
      return if results.size == 0

      if db_out != ""
        options, score_script = setup_eval_options(db_out)
        db = Utils.create_db(db_out)
        _layouts = Utils.load_user_layouts(results)

        puts "will save to " + db_out

        @eval.opts = options
        @eval.eval_layouts(_layouts, db, score_script, @lr_filter)

        db.close
      end
    end

    private def add_scores(file)
      Utils.update_score(file, @opts["score"].to_s)
    end

    private def add_left_right_scores(name)
      if @opts["score"] != ""
        ["left", "right"].each do |side|
          add_scores(db_name(name, side))
        end
      end
    end

    private def set_side_filter_min(filter, side, hand)
      filter.pass?(side, hand: hand)
      filter.min = (filter.score * FILTER_FACTOR).to_i16
    end

    private def set_side_max_effort(filter, side, hand)
      filter.pass?(side, hand: hand)
      filter.min = (filter.score * FILTER_FACTOR).to_i16
    end

    # Does optimization or left and right
    private def improve(layout)
      # all this can be passed to improve
      name = layout[:name]
      layout_s = layout[:k32]
      new_chars = layout_s.split("")

      filter_characters(new_chars)

      @layout_score = LayoutScore.new(
        characters: @characters.clone,
        bigrams: @bigrams
      )

      @left_sided_filter = OneSidedFilter.new(
        @characters.clone,
        @bigrams,
        10_000.to_i16
      )

      @right_sided_filter = OneSidedFilter.new(
        @characters.clone,
        @bigrams,
        10_000.to_i16
      )

      left, right = Utils.string_to_lr(layout_s, @characters)

      set_side_filter_min(@left_sided_filter, left, Hand::LEFT)
      set_side_filter_min(@right_sided_filter, right, Hand::RIGHT)

      # improve anyway
      left, right = Utils.get_best_effort(left,
        right,
        @left_32_index_by_weight,
        @right_32_index_by_weight)

      @layout_score.scan(left, right, layout_s, name)

      # just get the score and set it to min
      @lr_filter.pass?(@layout_score.score)
      @lr_filter.min = (@lr_filter.score * FILTER_FACTOR).to_i16

      STDERR.puts "* improving #{name}"

      h_left = char_by_weight(Hand::LEFT, left)
      h_right = char_by_weight(Hand::RIGHT, right)

      perm = side_permutations(h_left)
      prod = permutations_product(perm)
      scanner(prod, name: name, other_side: right)

      perm = side_permutations(h_right)
      prod = permutations_product(perm)
      scanner(prod, name: name, other_side: left, direction: "right")
    end

    private def db_name(name, direction)
      return "db/#{name}-#{direction}.db"
    end

    # Scans and scores
    private def scanner(array, name, other_side, direction = "left")
      STDERR.puts(" - #{direction}")
      @db.close
      @db = Utils.create_db(db_name(name, direction))

      array.each do |x|
        _tmp = x.clone
        if direction == "left"
          # FIXME: function cleaner
          _tmp.each_index do |i|
            x[@left_32_index_by_weight[i]] = _tmp[i]
          end

          next unless @left_sided_filter.pass?(x, hand: Hand::LEFT)

          scan(x, other_side, name)
        else
          _tmp.each_index do |i|
            x[@right_32_index_by_weight[i]] = _tmp[i]
          end

          next unless @right_sided_filter.pass?(x, hand: Hand::RIGHT)

          scan(other_side, x, name)
        end
      end
      @db.close
    end

    private def scan(left, right, name)
      layout = Utils.lr_to_string(left, right, @characters.sorted)

      # need name
      @layout_score.scan(left, right, layout, name)

      if @lr_filter.pass? @layout_score.score
        @db.db.exec(SQL_TBL_LAYOUTS_INSERT, *@layout_score.score.values)
      end
    end

    # Returns the product of two arrays (of permutations)
    private def get_products(one : Array(Array(UInt8)), two : Array(Array(UInt8))) : Array(Array(UInt8))
      res = Array(Array(UInt8)).new
      one.each_cartesian(two) do |x|
        y = x[0].clone.concat(x[1])
        res << y
      end
      return res
    end

    # Fixme: is this a util function
    private def char_by_weight(hand : Hand, side : Array(UInt8)) : Hash(Int32, Array(UInt8))
      result = Hash(Int32, Array(UInt8)).new

      kb_weights = ProjectConfig.instance.config[:kb_weights]

      index_by_weight = @left_32_index_by_weight
      to_32 = ProjectConfig.instance.config[:left_to_32]

      if hand == Hand::RIGHT
        index_by_weight = @right_32_index_by_weight

        to_32 = ProjectConfig.instance.config[:right_to_32]
      end

      index_by_weight.each_index do |i|
        key = KEYS_32[to_32[i]]
        w = kb_weights[key]
        unless result.has_key? w
          result[w] = Array(UInt8).new
        end
        # don't add index add char?
        result[w] << side[i]
      end

      # added?
      w_keys = result.keys.sort
      w_keys_index = -1
      last_w = w_keys[w_keys_index]

      # this selects one more?
      1.upto(@slow).each do |i|
        w_keys_index -= 1
        tmp_key = w_keys[w_keys_index]
        rev_result = result[tmp_key].sort.reverse
        result[last_w].concat(rev_result)
        result.delete tmp_key
      end

      if result[last_w].size > PERMUTATIONS_MAX
        Cleaner.exit_failure("slow: #{@slow} -> #{result[last_w].size}, will lead to too many permutations")
      end

      Helper.debug_inspect(result, context: "result")

      return result
    end

    # returns permutations for each array of weight
    private def side_permutations(lookup) : Array(Array(Array(UInt8)))
      result = Hash(Int32, Array(Array(UInt8))).new

      lookup.each_key do |k|
        v = lookup[k]
        result[k] = Array(Array(UInt8)).new
        v.permutations.each do |x|
          result[k] << x
        end
      end
      return result.to_a.sort { |a, b| a[0] <=> b[0] }.map { |x| x[1] }
    end

    # Combines all permutations together in possible layouts
    # There is no way to do this product by product so it is a limit
    # in how many permutations we can have
    private def permutations_product(perm) : Array(Array(UInt8))
      result = Array(Array(UInt8)).new

      result = get_products(perm[0], perm[1])
      2.upto(perm.size - 1).each do |i|
        result = get_products(result, perm[i])
      end
      return result
    end
  end
end
