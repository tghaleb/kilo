require "big"

# NOTE: need to not forget that some left/right here are not in correct
# order and therefore can't be filtered by any filter that doesn't
# understand how to filter no-ordered
module Kilo
  # one sided effort filter needs a pass?
  class EffortFilter
    include Constants
    @characters = FreqHash.new(1)
    @side_to_32 = Array(Int32).new
    @score : Int16 = 0.to_i16
    @min : Int16 = 10_000.to_i16
    @kb_weights : Hash(Key, Int32)
    @index_by_weight = Array(Int32).new

    property min
    property characters
    property side_to_32
    property index_by_weight

    def initialize
      @kb_weights = ProjectConfig.instance.config[:kb_weights]
    end

    def initialize(@characters, @side_to_32, @index_by_weight)
      @kb_weights = ProjectConfig.instance.config[:kb_weights]
    end

    def score
      if @score > Int16::MAX
        return Int16::MAX
      else
        return (@score/EFFORT_SCALE).to_i16
      end
    end

    def pass_w_ordered?(side) : Bool
      return scan_w_ordered(side) <= @min
    end

    #    def pass?(side, ordered = true) : Bool
    #      return scan(side, ordered) <= @min
    #    end

    def pass?(side) : Bool
      return scan(side) <= @min
    end

    # in general during improvements we will not be using ordered
    # only for actual left/right or just before exports.
    def scan_w_ordered(side)
      @score = 0.to_i16
      side.each_index do |i|
        index = @side_to_32[@index_by_weight[i]]
        w = @characters.data_i[side[i]]
        key = KEYS_32[index]
        @score += (@kb_weights[key] * w)
      end

      return score
    end

    #    def scan(side, ordered = true)
    #      @score = 0.to_i16
    #      if ordered
    #        side.each_index do |i|
    #          index = @side_to_32[i]
    #          w = @characters.data_i[side[i]]
    #          key = KEYS_32[index]
    #          @score += (@kb_weights[key] * w)
    #        end
    #      else
    #        side.each_index do |i|
    #          # FIXME: this is the bug?
    #          index = @side_to_32[@index_by_weight[i]]
    #          w = @characters.data_i[side[i]]
    #          key = KEYS_32[index]
    #          @score += (@kb_weights[key] * w)
    #        end
    #      end
    #
    #      return score
    #    end
    #

    def scan(side)
      @score = 0.to_i16
      side.each_index do |i|
        index = @side_to_32[i]
        w = @characters.data_i[side[i]]
        key = KEYS_32[index]
        @score += (@kb_weights[key] * w)
      end

      return score
    end

    # need a pass?
  end

  class Improve < Command
    # allow up to 400 delta

    SLOW2_COUNT             =  10
    EFFORT_DELTA            = 400
    PERMUTATIONS_MAX        =   7
    SIDE_SAME_FINGER_RP_MAX = 70.to_i16
    FILTER_FACTOR           = 1.01
    SAME_HAND_MAX           = 500.to_i16
    SAME_FINGER_BOTH_MAX    = 700.to_i16
    # SAME_HAND_MAX  = 600.to_i16
    EMPTY_U8_ARRAY = Array(UInt8).new

    @db = DB_Helper.new

    @db_left = DB_Helper.new
    @db_right = DB_Helper.new

    @layout_score = LayoutScore.new
    @layouts = Array(UserLayout).new
    @left_32_index_by_weight : Array(Int32)
    @right_32_index_by_weight : Array(Int32)
    @left_sided_filter = OneSidedFilter.new
    @right_sided_filter = OneSidedFilter.new
    @left_sided_short_filter = OneSidedFilter.new
    @right_sided_short_filter = OneSidedFilter.new
    @l_effort_score = EffortFilter.new
    @r_effort_score = EffortFilter.new

    # fixme how to get default

    #    @pre_scores : Hash(Hand, SimpleScoresType) = {
    #      Hand::LEFT  => NULL_SIMPLE_SCORES.clone,
    #      Hand::RIGHT => NULL_SIMPLE_SCORES.clone,
    #    }
    #
    @pre_scores : Hash(Hand, Array(SimpleScoresType)) = {
      Hand::LEFT  => Array(SimpleScoresType).new(size: 2, value: NULL_SIMPLE_SCORES.clone),
      Hand::RIGHT => Array(SimpleScoresType).new(size: 2, value: NULL_SIMPLE_SCORES.clone),
    }

    @simple_results = Array(SimpleScoresType).new

    #   @best_right_scores : Hash(Symbol, Int16) = OneSidedFilter::NULL_SCORES.clone
    #   @best_left_scores : Hash(Symbol, Int16) = OneSidedFilter::NULL_SCORES.clone

    # @best_side_same_score : Int16 = 0.to_i16
    # @best_side_same_rp_score : Int16 = 0.to_i16
    # @best_side_hand_score : Int16 = 0.to_i16
    # @best_side = Array(UInt8).new

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

      Helper.assert_file(_layouts)

      @layouts = Utils.load_user_layouts(_layouts)

      out_db = @opts["out"].to_s

      if out_db == ""
        Cleaner.exit_failure("--out option is required")
      end

      Helper.timer {
        improve_layouts(out_db)
      # scores should be builtin
      # add_scores(out_db)
      }
    end

    private def do_join(left_lookup, right_lookup) : Array(String)
      results = Array(String).new
      return results if left_lookup.empty? && right_lookup.empty?

      if right_lookup.empty?
        right_lookup = left_lookup
      elsif left_lookup.empty?
        left_lookup = right_lookup
      end

      #      side1_lookup.each_key do |k|
      #        unless side2_lookup.has_key? k
      #          Cleaner.exit_failure("layout #{k} is missing in the left file")
      #        end
      #        val_r = right_lookup[k]
      #        val_l = left_lookup[k]
      #        lefts = Array(Array(UInt8)).new
      #        rights = Array(Array(UInt8)).new
      #
      #        char_array = (val_r[0] + val_l[0]).split("").uniq
      #        filter_characters(char_array)
      #        chars = @characters
      #
      #        val_r.each_index do |i|
      #          tmp, right = Utils.string_to_lr(val_r[i], chars)
      #          rights << right
      #        end
      #        val_l.each_index do |i|
      #          left, tmp = Utils.string_to_lr(val_l[i], chars)
      #          lefts << left
      #        end
      #
      #        counter = 0
      #        lefts.each_cartesian(rights) do |x|
      #          results << Utils.lr_to_string(x[0], x[1], chars.sorted) + " " + k + "-" + counter.to_s
      #          counter += 1
      #        end
      #      end

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

        lefts.uniq!
        rights.uniq!

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

    # We do selection with sql to find best results
    private def improved_selection(name)
      layouts_left = Array(Score).new
      layouts_right = Array(Score).new

      # We read from db
      # db_left = DB_Helper.new(db_name(name, "left"))
      # db_right = DB_Helper.new(db_name(name, "right"))

      @args.each do |file|
        sql = Utils.read_user_sql(
          file.to_s, default: DEFAULT_SELECT, limit: @opts["limit"].to_s)
        layouts_left.concat(Utils.query_layouts_db(@db_left, sql))
        layouts_right.concat(Utils.query_layouts_db(@db_right, sql))
      end

      # db_left.close
      # db_right.close

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

        # if db_exists? name
        #   STDERR.puts ("* #{name} already improved.")
        # else
        Helper.timer {
          improve(x, db_out)
        }
        # FIXME: add this later? or remove
        # add_left_right_scores(name)
        # end

        next if @opts["fast"].as(Bool)

        layouts_left, layouts_right = improved_selection(name)

        next if layouts_left.empty? && layouts_right.empty?

        Helper.debug_inspect(layouts_left.size, "ll_size")
        Helper.debug_inspect(layouts_right.size, "rr_size")

        layouts_lookup_left = build_layouts_lookup(layouts_left)
        layouts_lookup_right = build_layouts_lookup(layouts_right)
        #    next if layouts_lookup_left.empty? || layouts_lookup_right.empty?

        results = do_join(layouts_lookup_left, layouts_lookup_right)

        save_results(results, db_out)
      end
    end

    private def setup_eval_options(db_out)
      options = OptionsHash.new
      options["out"] = db_out
      options["print"] = false
      #      options["score"] = ""

      # FIXME: remove score option

      # score_script = @opts["score"].to_s
      score_script = ""

      #      unless score_script == ""
      #        score_script = File.join(Kilo.pwd, score_script)
      #      end
      #      return options, score_script
      return options
    end

    private def save_results(results, db_out)
      return if results.size == 0

      if db_out != ""
        # options, score_script = setup_eval_options(db_out)
        options = setup_eval_options(db_out)
        db = Utils.create_db(db_out)
        _layouts = Utils.load_user_layouts(results)

        puts "will save to " + db_out

        @eval.opts = options
        # @eval.eval_layouts(_layouts, db, score_script, @lr_filter)
        @eval.eval_layouts(_layouts, db)

        db.close
      end
    end

    #    private def add_scores(file)
    #      if File.file? file
    #        Utils.update_score(file, @opts["score"].to_s)
    #      end
    #    end
    #
    #    private def add_left_right_scores(name)
    #      if @opts["score"] != ""
    #        ["left", "right"].each do |side|
    #          add_scores(db_name(name, side))
    #        end
    #      end
    #    end

    private def set_side_filter_min(filter, side, hand)
      filter.pass?(side, hand: hand)

      # get score and if score is above max use max
      max_hand = (filter.score * FILTER_FACTOR).to_i16
      if max_hand > SAME_HAND_MAX
        max_hand = SAME_HAND_MAX
      end
      filter.min_hand = max_hand

      max_both = (filter.score_same_both * FILTER_FACTOR).to_i16
      if max_both > SAME_FINGER_BOTH_MAX
        max_both = SAME_FINGER_BOTH_MAX
      end
      filter.min_same_both = max_both

      Helper.debug_inspect(
        filter.score,
        "(side_filter #{hand.to_s}) score"
      )
      Helper.debug_inspect(
        filter.min_hand,
        "(side_filter #{hand.to_s}) min_hand"
      )
      Helper.debug_inspect(
        filter.min_same_both,
        "(side_filter #{hand.to_s}) min_same_both"
      )
    end

    private def set_side_max_effort(filter, side, hand)
      filter.pass?(side, hand: hand)
      # filter.min = (filter.score * FILTER_FACTOR).to_i16
    end

    # Does optimization or left and right
    private def improve(layout, db_out)
      # all this can be passed to improve
      name = layout[:name]
      layout_s = layout[:k32]
      new_chars = layout_s.split("")

      filter_characters(new_chars)

      # FIXME: set characters/bigrams again don't create a new one
      @layout_score = LayoutScore.new(
        characters: @characters.clone,
        bigrams: @bigrams
      )

      # FIXME: set characters/bigrams again don't create a new one
      @left_sided_filter = OneSidedFilter.new(
        @characters.clone,
        @bigrams,
      )

      # FIXME: set characters/bigrams again don't create a new one
      #      @left_sided_short_filter = OneSidedFilter.new(
      #        @characters.clone,
      #        @bigrams,
      #      )
      #
      # FIXME: set characters/bigrams again don't create a new one
      @right_sided_filter = OneSidedFilter.new(
        @characters.clone,
        @bigrams,
      )

      @l_effort_score = EffortFilter.new(
        @characters.clone,
        ProjectConfig.instance.config[:left_to_32],
        @left_32_index_by_weight
      )
      @r_effort_score = EffortFilter.new(
        @characters.clone,
        ProjectConfig.instance.config[:right_to_32],
        @right_32_index_by_weight
      )

      # FIXME: set characters/bigrams again don't create a new one
      #      @right_sided_short_filter = OneSidedFilter.new(
      #        @characters.clone,
      #        @bigrams,
      #      )
      #
      left, right = Utils.string_to_lr(layout_s, @characters)

      # do we need a min effort here?

      # FIXME: this can come before all setup of filters plus
      # make filter setup in another function

      STDERR.puts "* improving #{name}"

      set_side_filter_min(@left_sided_filter, left, Hand::LEFT)
      set_side_filter_min(@right_sided_filter, right, Hand::RIGHT)

      @layout_score.scan(left, right, layout_s, name)

      @l_effort_score.scan(left)
      @l_effort_score.min = @l_effort_score.score + EFFORT_DELTA

      @r_effort_score.scan(right)
      @r_effort_score.min = @r_effort_score.score + EFFORT_DELTA

      do_pre_products(
        name,
        hand: Hand::LEFT,
        side: left,
        other_side: right,
      )

      do_pre_products(
        name,
        hand: Hand::RIGHT,
        side: right,
        other_side: left, # direction: "right"
      )

      if @opts["fast"].as(Bool)
        save_fast(db_out)
        return
      end

      Utils.reinit_db(@db_left)
      Utils.reinit_db(@db_right)

      @pre_scores[Hand::RIGHT].each_index do |i|
        # right = @pre_scores[Hand::RIGHT][:side].as(Array(UInt8))
        # left = @pre_scores[Hand::LEFT][:side].as(Array(UInt8))

        right = @pre_scores[Hand::RIGHT][i][:side].as(Array(UInt8))
        left = @pre_scores[Hand::LEFT][i][:side].as(Array(UInt8))

        set_side_filter_min(@left_sided_filter, left, Hand::LEFT)
        set_side_filter_min(@right_sided_filter, right, Hand::RIGHT)

        # set_side_filter_min(@left_sided_short_filter, left[0..9], Hand::LEFT)
        # set_side_filter_min(@right_sided_short_filter, right[0..9], Hand::RIGHT)

        @layout_score.scan(left, right, layout_s, name)

        #      Helper.debug_inspect(
        #        @layout_score.score.same_finger_rp,
        #        "#{name} same_finger_rp"
        #      )
        #      Helper.debug_inspect(
        #        @layout_score.score.same_finger_im,
        #        "#{name} same_finger_im"
        #      )
        #      Helper.debug_inspect(
        #        @layout_score.score.positional_effort,
        #        "#{name} positional_effort"
        #      )
        #
        # FIXME: set characters/bigrams again don't create a new one

        @l_effort_score.scan(left)
        @l_effort_score.min = @l_effort_score.score + EFFORT_DELTA

        #      Helper.debug_inspect(
        #        @l_effort_score.score,
        #        "#{name} (l_effort_filter) score"
        #      )
        #      Helper.debug_inspect(
        #        @l_effort_score.min,
        #        "#{name} (l_effort_filter) min"
        #      )
        #
        # FIXME: set characters/bigrams again don't create a new one
        @r_effort_score.scan(right)
        @r_effort_score.min = @r_effort_score.score + EFFORT_DELTA

        # Helper.debug_inspect(
        #  @r_effort_score.score,
        #  "#{name} (r_effort_filter) score"
        # )
        # Helper.debug_inspect(
        #  @r_effort_score.min,
        #  "#{name} (r_effort_filter) min"
        # )

        @layout_score.scan(left, right, layout_s, name)

        # just get the score and set it to min
        @lr_filter.pass?(@layout_score.score)
        @lr_filter.min_hand = (@lr_filter.score * FILTER_FACTOR).to_i16
        @lr_filter.min_same_both = (@lr_filter.score_same_both * FILTER_FACTOR).to_i16
        @lr_filter.min_effort = (@lr_filter.score_effort + (EFFORT_DELTA*2)).to_i16

        #      Utils.debug_diff_layouts(left, right, _left, right)

        left, right = Utils.get_best_min_effort(left,
          right,
          @left_32_index_by_weight,
          @right_32_index_by_weight,
          @characters.data_i,
          delta: EFFORT_DELTA)

        #  Utils.debug_diff_layouts(left, right, l1, r1)
        #  puts l1.inspect
        #  puts r1.inspect

        do_products(
          name,
          hand: Hand::LEFT,
          side: left,
          other_side: right,
        )
        do_products(
          name,
          hand: Hand::RIGHT,
          side: right,
          other_side: left,
        )
      end
    end

    private def save_fast(db_out)
      @db.close
      @db = Utils.create_db(db_out)

      @pre_scores[Hand::LEFT].each_index do |i|
        left = @pre_scores[Hand::LEFT][i][:side].as(Array(UInt8))
        right = @pre_scores[Hand::RIGHT][i][:side].as(Array(UInt8))
        name = @pre_scores[Hand::LEFT][i][:name].as(String)

        #        left = @pre_scores[Hand::LEFT][:side].as(Array(UInt8))
        #        right = @pre_scores[Hand::RIGHT][:side].as(Array(UInt8))
        #        name = @pre_scores[Hand::LEFT][:name].as(String)
        layout = Utils.lr_to_string(left, right, @characters.sorted)

        @layout_score.scan(left, right, layout, name + "-0")

        @db.db.exec(SQL_TBL_LAYOUTS_INSERT, *@layout_score.score.values)
        @db.db.exec(UPDATE_SCORE_SQL, @layout_score.score.score, @layout_score.score.layout)
      end
      @db.close
    end

    private def get_hand_filters(hand)
      if hand == Hand::LEFT
        hand_filter = @left_sided_filter
        effort_filter = @l_effort_score
        #    side_scores = @best_left_scores
      else
        hand_filter = @right_sided_filter
        effort_filter = @r_effort_score
        #    side_scores = @best_right_scores
      end
      # return hand_filter, effort_filter, side_scores
      return hand_filter, effort_filter
    end

    # FIXME: rename?
    private def do_pre_products(
      name : String,
      hand : Hand,
      side : Array(UInt8),
      other_side : Array(UInt8)
      #  direction : String
    )
      hand_filter, effort_filter = get_hand_filters(hand)

      side_p_ordered = order_side_by_position(side, hand)
      hand_filter.pass?(side_p_ordered, hand: hand)

      # set starting point
      set_side_data(0, name, hand, hand_filter, effort_filter, side_p_ordered)
      set_side_data(1, name, hand, hand_filter, effort_filter, side_p_ordered)
      #      set_side_data(name, hand, hand_filter, effort_filter, side_p_ordered)

      char_by_weight(hand, side).each do |lookup|
        perm = side_permutations(lookup)
        prod = permutations_product(perm)
        permutations_product(perm).each do |x|
          # Important this is what we work with
          side_p_ordered = order_side_by_position(x, hand)
          hand_filter.pass?(side_p_ordered, hand: hand)

          # test for effort
          # sort order best_side, best_rp, best_hand, best effort
          next unless effort_filter.pass?(side_p_ordered)

          # FIXME: make a function
          if @pre_scores[hand][1][:hand].as(Int16) >
               hand_filter.scores[:hand].as(Int16)
            set_side_data(1, name, hand, hand_filter, effort_filter, side_p_ordered)
          elsif @pre_scores[hand][1][:hand].as(Int16) ==
                  hand_filter.scores[:hand].as(Int16)
            if @pre_scores[hand][1][:same].as(Int16) > hand_filter.scores[:same].as(Int16)
              set_side_data(1, name, hand, hand_filter, effort_filter, side_p_ordered)
            elsif @pre_scores[hand][1][:same].as(Int16) == hand_filter.scores[:same].as(Int16)
              if @pre_scores[hand][1][:effort].as(Int16) > effort_filter.score
                set_side_data(1, name, hand, hand_filter, effort_filter, side_p_ordered)
              end
            end
          end

          if @pre_scores[hand][0][:same].as(Int16) >
               hand_filter.scores[:same].as(Int16)
            set_side_data(0, name, hand, hand_filter, effort_filter, side_p_ordered)
          elsif @pre_scores[hand][0][:same].as(Int16) ==
                  hand_filter.scores[:same].as(Int16)
            if @pre_scores[hand][0][:same_rp].as(Int16) > hand_filter.scores[:same_rp].as(Int16)
              set_side_data(0, name, hand, hand_filter, effort_filter, side_p_ordered)
            elsif @pre_scores[hand][0][:same_rp].as(Int16) == hand_filter.scores[:same_rp].as(Int16)
              if @pre_scores[hand][0][:hand].as(Int16) >
                   hand_filter.scores[:hand].as(Int16)
                set_side_data(0, name, hand, hand_filter, effort_filter, side_p_ordered)
              elsif @pre_scores[hand][0][:hand].as(Int16) ==
                      hand_filter.scores[:hand].as(Int16)
                if @pre_scores[hand][0][:effort].as(Int16) > effort_filter.score
                  set_side_data(0, name, hand, hand_filter, effort_filter, side_p_ordered)
                end
                # effort_score
                # make effort score a hash that you can clone or
                # something like that.
                # if @best_side_same_rp_score < hand_filter.score_same_finger_rp
              end
            end
          end
        end
      end
      Helper.debug_inspect(@pre_scores, "pre best_side_scores " + hand.to_s)
    end

    private def set_side_data(index, name, hand, hand_filter, effort_filter, side_p_ordered)
      @pre_scores[hand][index] = hand_filter.scores.clone
      @pre_scores[hand][index][:effort] = effort_filter.score
      @pre_scores[hand][index][:side] = side_p_ordered
      @pre_scores[hand][index][:name] = name

      #      @pre_scores[hand] = hand_filter.scores.clone
      #      @pre_scores[hand][:effort] = effort_filter.score
      #      @pre_scores[hand][:side] = side_p_ordered
      #      @pre_scores[hand][:name] = name
    end

    private def do_products(
      name : String,
      hand : Hand,
      side : Array(UInt8),
      other_side : Array(UInt8)
      #      direction : String
    )
      direction = hand.to_s.downcase

      hand_filter, effort_filter = get_hand_filters(hand)
      counter = 0
      tmp = Array(Array(UInt8)).new
      tmp << side

      # Important this is what we work with
      side_w_ordered = order_side_by_weight(side, hand)

      last_n = side_w_ordered[SLOW2_COUNT..-1]

      # FIXME: do this outside? or here
      perm_n = last_n.permutations

      side_w_ordered[0..SLOW2_COUNT - 1].each_permutation(SLOW2_COUNT) do |x|
        counter += 1

        # Here x is w_ordered not by position
        next unless effort_filter.pass_w_ordered?(x + last_n)
        next unless hand_filter.pass?(order_side_by_position(x + last_n, hand), hand: hand)

        # permutations_product will filter and returns ordered
        # tmp.concat(permutations_product([[x], perm_n], hand))

        permutations_product([[x], perm_n]).each do |p|
          ordered = order_side_by_position(p, hand: hand)
          # FIXME: try order only last_n and have others pre ordered?
          # or what?
          tmp << ordered if (effort_filter.pass?(ordered) &&
                            hand_filter.pass?(ordered, hand))
        end
        #
        if tmp.size > 20_000_000
          puts "* captured: " + tmp.size.to_s
          scanner(tmp, name: name, other_side: other_side, hand: hand, ordered: true)
          tmp.clear
        end
      end
      unless tmp.empty?
        puts "* total captured: " + tmp.size.to_s
        scanner(tmp, name: name, other_side: other_side, hand: hand, ordered: true)
        tmp.clear
        Helper.put_debug("* total permutations: " + counter.to_s)
      end
    end

    private def db_name(name, hand)
      return "db/#{name}-#{hand}.db"
    end

    # Better letters first
    private def order_side_by_weight(side, hand)
      if hand == Hand::LEFT
        by_weight = @left_32_index_by_weight
      else
        by_weight = @right_32_index_by_weight
      end

      _tmp = side.clone
      side.each_index do |i|
        _tmp[i] = side[by_weight[i]]
      end
      return _tmp
    end

    # By Position on board
    private def order_side_by_position(side, hand)
      if hand == Hand::LEFT
        by_weight = @left_32_index_by_weight
      else
        by_weight = @right_32_index_by_weight
      end

      _tmp = side.clone
      side.each_index do |i|
        _tmp[by_weight[i]] = side[i]
      end
      return _tmp
    end

    # Scans and scores for an array of left/right
    private def scanner(array, name, other_side, hand = Hand::LEFT,
                        ordered = false)
      STDERR.puts(" - #{name}")
      STDERR.puts(" - #{hand.to_s}")
      @db.close
      # @db = Utils.create_db(db_name(name, hand.to_s.downcase))
      # drop tables

      if hand == Hand::LEFT
        # FIXME: reinit outside?
        db = @db_left
        array.each do |x|
          _tmp = x.clone
          unless ordered
            x = order_side_by_position(x, hand)
            next unless @l_effort_score.pass?(x)
            next unless @left_sided_filter.pass?(x, hand: hand)
          end
          scan(x, other_side, name, db)
        end
      else
        db = @db_right
        array.each do |x|
          _tmp = x.clone
          unless ordered
            x = order_side_by_position(x, hand)
            next unless @r_effort_score.pass?(x)
            next unless @right_sided_filter.pass?(x, hand: hand)
          end
          scan(other_side, x, name, db)
        end
      end
      # @db.close
    end

    # Scans, Scores and Writes to db
    private def scan(left, right, name, db)
      layout = Utils.lr_to_string(left, right, @characters.sorted)

      @layout_score.scan(left, right, layout, name)

      if @lr_filter.pass? @layout_score.score
        db.db.exec(SQL_TBL_LAYOUTS_INSERT, *@layout_score.score.values)
        # db.db.exec(UPDATE_SCORE_SQL, @layout_score.score.score, @layout_score.score.layout)
      end
    end

    # Returns the product of two arrays (of permutations)
    # private def get_products(one : Array(Array(UInt8)), two : Array(Array(UInt8)), hand) : Array(Array(UInt8))
    private def get_products(one : Array(Array(UInt8)), two : Array(Array(UInt8))) : Array(Array(UInt8))
      #      if hand == Hand::LEFT
      #        effort_filter = @l_effort_score
      #        hand_filter = @left_sided_filter
      #      else
      #        effort_filter = @r_effort_score
      #        hand_filter = @right_sided_filter
      #      end
      #
      res = Array(Array(UInt8)).new
      one.each_cartesian(two) do |x|
        y = x[0].clone.concat(x[1])

        # FIXME: these products are sub products
        #        ordered = order_side_by_position(y, direction: hand)
        #        next unless effort_filter.pass_w_ordered?(ordered)
        #        next unless hand_filter.pass?(ordered, hand: hand)
        res << y
      end
      return res
    end

    private def combine_weights_helper(ar1, ar2)
      result1 = ar1.clone
      ar2_rev = ar2.sort.reverse
      result2 = ar2_rev.clone
      # ar2_sorted.each_index do |i|
      (ar2.size - 1).downto(0) do |i|
        break unless result1.size < PERMUTATIONS_MAX
        # added
        next if (ar2.size > 2) && (ar1.size > 2)

        result1 << ar2_rev[i]
        result2.delete_at(i)
      end

      if result2.empty?
        # to save memory
        return result1, EMPTY_U8_ARRAY
      else
        return result1, result2
      end

      #      if (ar1.size + ar2.size) < PERMUTATIONS_MAX
      #        result2.each_index do |i|
      #          break unless result1.size < PERMUTATIONS_MAX
      #          result1 << result2[i]
      #        end
      #        #  rev_result = result[tmp_key].sort.reverse
      #        #  result[last_w].concat(rev_result)
      #        #  result.delete tmp_key
      #
      #        # FIXME: do by iterations
      #        return ar1 + ar2, EMPTY_U8_ARRAY
      #      else
      #        return ar1, ar2
      #      end
    end

    private def combine_weights(hash, step, from = 0)
      w_keys = hash.keys.sort
      result = Hash(Int32, Array(UInt8)).new
      empty = Array(UInt8).new
      Helper.debug_inspect(w_keys, "w_keys")
      Helper.debug_inspect(hash, "hash")
      start = from + step - 1

      # add the first ones
      0.upto(from - 1) do |i|
        k = w_keys[i]
        result[k] = hash[k]
      end

      start.step(to: w_keys.size - 1, by: step) do |i|
        k1 = w_keys[i - 1]
        k2 = w_keys[i]
        Helper.debug_inspect(k1, "k1")
        Helper.debug_inspect(k2, "k2")
        result[k1], result[k2] = combine_weights_helper(hash[k1], hash[k2])
        if step > 2
          k0 = w_keys[i - 2]
          Helper.debug_inspect(k0, "k0")
          result[k0], result[k1] = combine_weights_helper(hash[k0], result[k1])
        end
      end

      mod = (w_keys.size - from) % step
      if mod != 0
        1.upto(mod).each do |i|
          result[w_keys[-i]] = hash[w_keys[-i]]
        end
      end

      # compacting is not important
      return result
    end

    # Fixme: is this a util function
    # private def char_by_weight(hand : Hand, side : Array(UInt8)) : Hash(Int32, Array(UInt8))
    private def char_by_weight(hand : Hand, side : Array(UInt8)) : Array(Hash(Int32, Array(UInt8)))
      result = Array(Hash(Int32, Array(UInt8))).new
      result << Hash(Int32, Array(UInt8)).new

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
        unless result[-1].has_key? w
          result[-1][w] = Array(UInt8).new
        end
        # don't add index add char?
        result[-1][w] << side[i]
      end

      result[0] = combine_weights(result[-1], 2)

      # FIXME: combine only some weights

      #      if @slow > 0
      #        result << combine_weights(result[-1], 2)
      #        result << combine_weights(result[-2], 2, from: 1)
      #      end
      #
      # not needed
      #      if @slow > 1
      #        result << combine_weights(result[-3], 3)
      #        result << combine_weights(result[-4], 3, from: 1)
      #        # result << combine_weights(result[-5], 3, from: 2)
      #      end
      #
      # if slow 1
      # plus shift by one and again?
      #      w_keys = result.keys.sort
      #      result2 << Hash(Int32, Array(UInt8)).new
      #      # result2 = Hash(Int32, Array(UInt8)).new
      #      0.step(to: w_keys.size - 1, by: 2) do |i|
      #        k1 = w_keys[i - 1]
      #        k2 = w_keys[i]
      #        if (result[k1].size + result[k2].size) < 9
      #          # result2[k1] = result[k1] + result[k2]
      #          result2[-1][k1] = result[k1] + result[k2]
      #          # result2[-1][k1] = result[k1]
      #        else
      #          # result2[k1] = result[k1]
      #          # result2[k2] = result[k2]
      #          result2[-1][k1] = result[k1]
      #          result2[-1][k2] = result[k2]
      #        end
      #      end
      #
      # add last one
      # if w_keys.size % 2 != 0
      #  result2[-1][w_keys[-1]] = result[w_keys[-1]]
      #  # result2[w_keys[-1]] = result[w_keys[-1]]
      # end

      # added?
      # w_keys = result.keys.sort
      # w_keys_index = -1
      # last_w = w_keys[w_keys_index]

      # this selects one more?
      # 1.upto(@slow).each do |i|
      #  w_keys_index -= 1
      #  tmp_key = w_keys[w_keys_index]
      #  rev_result = result[tmp_key].sort.reverse
      #  result[last_w].concat(rev_result)
      #  result.delete tmp_key
      # end

      # if result[last_w].size > PERMUTATIONS_MAX
      #  Cleaner.exit_failure("slow: #{@slow} -> #{result[last_w].size}, will lead to too many permutations")
      # end

      # w_keys = result.keys.sort
      # w_keys_index = 0
      # last_w = w_keys[w_keys_index]

      # FIXME: think combine each pair but then result will be an array of
      # 1 combines each pair
      # 2 combines 3 pair
      # all start from end
      # all skip 9 or more perm

      # results?
      # this selects one more?
      #      1.upto(@slow).each do |i|
      #        w_keys_index += 1
      #        tmp_key = w_keys[w_keys_index]
      #        rev_result = result[tmp_key].sort.reverse
      #        result[last_w].concat(rev_result)
      #        result.delete tmp_key
      #      end
      #
      #      if result[last_w].size > PERMUTATIONS_MAX
      #        Cleaner.exit_failure("slow: #{@slow} -> #{result[last_w].size}, will lead to too many permutations")
      #      end
      #
      Helper.debug_inspect(result, context: "result")

      # return result
      # return result2[-1]
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
