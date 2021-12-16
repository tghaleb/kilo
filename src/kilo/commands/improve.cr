require "big"

# NOTE: need to not forget that some left/right here are not in correct
# order and therefore can't be filtered by any filter that doesn't
# understand how to filter no-ordered
module Kilo
  class Improve < Command
    # allow up to 400 delta

    PERMUTATIONS_MAX   = 7
    EMPTY_U8_ARRAY     = Array(UInt8).new
    EMPTY_STRING_ARRAY = Array(String).new

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
    @l_effort_score = HalfEffortFilter.new
    @r_effort_score = HalfEffortFilter.new

    @pre_scores : Hash(Hand, Array(SimpleScoresType)) = {
      Hand::LEFT  => Array(SimpleScoresType).new(size: 3, value: NULL_SIMPLE_SCORES.clone),
      Hand::RIGHT => Array(SimpleScoresType).new(size: 3, value: NULL_SIMPLE_SCORES.clone),
    }

    @simple_results = Array(SimpleScoresType).new
    @config : ImproveConfigType

    def initialize
      super

      @config = ProjectConfig.instance.config[:improve_config]

      left_to_32 = ProjectConfig.instance.config[:left_to_32]
      right_to_32 = ProjectConfig.instance.config[:right_to_32]

      @left_32_index_by_weight = Utils.index_by_weight(side_to_32: left_to_32)
      @right_32_index_by_weight = Utils.index_by_weight(side_to_32: right_to_32)

      @eval = Eval.new

      @lr_filter = SameHandEvalFilter.new(@config[:max_half_hand])
    end

    def run(
      global_opts : OptionsHash,
      opts : OptionsHash,
      args : Array(String)
    ) : Nil
      assert_inside_project_dir()
      opts_args(global_opts, opts, args)

      Helper.debug_inspect(@config, "@config")

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
      }
    end

    private def improve_layouts(db_out)
      @layouts.each do |x|
        name = x[:name]

        Helper.timer {
          improve(x, db_out)
        }

        next if @opts["fast"].as(Bool)

        results = prepare_results

        # append original layout
        results << x[:k32] + " " + x[:name]

        save_results(results, db_out)
      end
    end

    private def prepare_results
      layouts_left, layouts_right = improved_selection

      return EMPTY_STRING_ARRAY if layouts_left.empty? && layouts_right.empty?

      Helper.debug_inspect(layouts_left.size, "ll_size")
      Helper.debug_inspect(layouts_right.size, "rr_size")

      layouts_lookup_left = build_layouts_lookup(layouts_left)
      layouts_lookup_right = build_layouts_lookup(layouts_right)

      Helper.debug_inspect(layouts_lookup_right.keys, "layout right keys")
      Helper.debug_inspect(layouts_lookup_left.keys, "layout left keys")

      do_join(layouts_lookup_left, layouts_lookup_right)
    end

    private def do_join(left_lookup, right_lookup) : Array(String)
      results = Array(String).new
      return results if left_lookup.empty? && right_lookup.empty?

      if right_lookup.empty?
        right_lookup = left_lookup
      elsif left_lookup.empty?
        left_lookup = right_lookup
      end

      right_lookup.each_key do |k|
        next unless left_lookup.has_key? k
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

        # FIXME: only do this if we have 2? else no cartesian
        lefts.each_cartesian(rights) do |x|
          results << Utils.lr_to_string(x[0], x[1], chars.sorted) + " " + k + "-" + counter.to_s
          counter += 1
        end
      end
      return results
    end

    # We do selection with sql to find best results
    private def improved_selection
      layouts_left = Array(Score).new
      layouts_right = Array(Score).new

      @args.each do |file|
        sql = Utils.read_user_sql(
          file.to_s, default: DEFAULT_SELECT, limit: @opts["limit"].to_s)
        layouts_left.concat(Utils.query_layouts_db(@db_left, sql))
        layouts_right.concat(Utils.query_layouts_db(@db_right, sql))
      end

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

    private def save_results(results, db_out)
      return if results.size == 0

      if db_out != ""
        options = setup_eval_options(db_out)
        db = Utils.create_db(db_out)
        _layouts = Utils.load_user_layouts(results)

        STDERR.puts "will save to " + db_out

        @eval.opts = options
        # @eval.eval_layouts(_layouts, db, score_script, @lr_filter)
        @eval.eval_layouts(_layouts, db)

        db.close
      end
    end

    private def set_side_filter_min(filter, side, hand)
      filter.scan(side, hand: hand)

      # get score and if score is above max use max
      max_hand = (filter.score * @config[:filter_factor]).to_i16
      if max_hand > @config[:max_half_hand]
        max_hand = @config[:max_half_hand]
      end

      filter.min_hand = max_hand

      max_both = (filter.score_same_both * @config[:filter_factor]).to_i16
      if max_both > @config[:max_half_same_both]
        max_both = @config[:max_half_same_both]
      end

      filter.min_same_both = max_both
      debug_half_hand(filter, hand)
    end

    private def improve_stage1(name, left, right)
      puts_stage(1)

      do_stage1(
        name,
        hand: Hand::LEFT,
        side: left,
        other_side: right,
      )

      do_stage1(
        name,
        hand: Hand::RIGHT,
        side: right,
        other_side: left,
      )
    end

    private def improve_stage2(name, left, right)
      # add original left/right
      scanner([left], name: name, other_side: right, hand: Hand::RIGHT, ordered: true)
      scanner([right], name: name, other_side: left, hand: Hand::LEFT, ordered: true)

      puts_stage(2)

      @pre_scores[Hand::RIGHT].each_index do |i|
        right = @pre_scores[Hand::RIGHT][i][:side].as(Array(UInt8))
        left = @pre_scores[Hand::LEFT][i][:side].as(Array(UInt8))

        # add stage1 originals
        scanner([left], name: name, other_side: right, hand: Hand::RIGHT, ordered: true)
        scanner([right], name: name, other_side: left, hand: Hand::LEFT, ordered: true)

        # FIXME: lr get switched in the second run so what is this? and
        # does it work
        # and do we have something broken as we switch sides, with
        # filters

        setup_filters_min(left, right, name)
        setup_lr_filter

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

    # Does optimization or left and right
    private def improve(layout, db_out)
      # all this can be passed to improve
      name = layout[:name]
      layout_s = layout[:k32]
      setup_filters(layout_s)

      left, right = Utils.string_to_lr(layout_s, @characters)

      # do we need a min effort here?

      # FIXME: this can come before all setup of filters plus
      # make filter setup in another function

      puts_improving(name)

      left, right = Utils.get_best_min_effort(left,
        right,
        @left_32_index_by_weight,
        @right_32_index_by_weight,
        @characters.data_i,
        delta: @config[:effort_delta])

      setup_filters_min(left, right, name)
      # FIXME: not here if any before but not here

      #      _left, _right = Utils.get_best_effort(left,
      #        right,
      #        @left_32_index_by_weight,
      #        @right_32_index_by_weight)
      #
      improve_stage1(name, left, right)

      if @opts["fast"].as(Bool)
        save_fast(db_out)
        return
      end

      Utils.reinit_db(@db_left)
      Utils.reinit_db(@db_right)

      improve_stage2(name, left, right)
    end

    private def save_fast(db_out)
      @db.close
      @db = Utils.create_db(db_out)

      @pre_scores[Hand::LEFT].each_index do |i|
        ldata = @pre_scores[Hand::LEFT][i]
        left = ldata[:side].as(Array(UInt8))
        right = @pre_scores[Hand::RIGHT][i][:side].as(Array(UInt8))
        name = ldata[:name].as(String)

        Helper.debug_inspect(left, "left " + name)
        Helper.debug_inspect(right, "right " + name)

        layout = Utils.lr_to_string(left, right, @characters.sorted)

        @layout_score.scan(left, right, name)

        @db.db.exec(SQL_TBL_LAYOUTS_INSERT, *@layout_score.score.values)
        @db.db.exec(UPDATE_SCORE_SQL, @layout_score.score.score, @layout_score.score.layout)
      end
      @db.close
    end

    private def get_hand_filters(hand)
      if hand == Hand::LEFT
        hand_filter = @left_sided_filter
        effort_filter = @l_effort_score
      else
        hand_filter = @right_sided_filter
        effort_filter = @r_effort_score
      end
      return hand_filter, effort_filter
    end

    private def multi_filter(
      hand,
      index,
      scores,
      keys
    )
      key = keys.shift
      if @pre_scores[hand][index][key].as(Int16) > scores[key].as(Int16)
        set_side_data(index, hand, scores)
      elsif @pre_scores[hand][index][key].as(Int16) == scores[key].as(Int16)
        multi_filter(
          hand: hand,
          index: index,
          scores: scores,
          keys: keys
        ) if keys.size != 0
      end
    end

    @[AlwaysInline]
    private def good_half_scores?(scores)
      # FIXME: use constants
      (scores[:hand].as(Int16) < @config[:max_half_hand]) &&
        (scores[:same_rp].as(Int16) < @config[:max_half_same_rp]) &&
        (scores[:same_both].as(Int16) < @config[:max_half_same_both])
    end

    private def do_stage1(
      name : String,
      hand : Hand,
      side : Array(UInt8),
      other_side : Array(UInt8)
    )
      hand_filter, effort_filter = get_hand_filters(hand)

      side_p_ordered = order_side_by_position(side, hand)
      hand_filter.scan(side_p_ordered, hand: hand)

      scores = hand_filter.scores
      scores[:effort] = effort_filter.score
      scores[:name] = name
      scores[:side] = side_p_ordered

      # set starting point
      set_side_data(0, hand, scores)
      set_side_data(1, hand, scores)
      set_side_data(2, hand, scores)

      char_by_weight(hand, side).each do |lookup|
        perm = side_permutations(lookup)
        prod = permutations_product(perm)
        permutations_product(perm).each do |x|
          # Important this is what we work with
          side_p_ordered = order_side_by_position(x, hand)
          hand_filter.scan(side_p_ordered, hand: hand)

          # test for effort
          # sort order best_side, best_rp, best_hand, best effort
          next unless effort_filter.pass?(side_p_ordered)

          scores = hand_filter.scores
          scores[:effort] = effort_filter.score
          scores[:side] = side_p_ordered
          scores[:name] = name

          next unless good_half_scores?(scores)

          multi_filter(
            hand: hand,
            index: 0,
            scores: scores,
            keys: [:same_both, :same_rp, :hand, :effort]
          )

          multi_filter(
            hand: hand,
            index: 1,
            scores: scores,
            keys: [:same_both_j, :same_rp, :jumps, :outward, :effort] # keys: [:hand, :same_both, :same_rp, :effort]
          )

          multi_filter(
            hand: hand,
            index: 2,
            scores: scores,
            keys: [:hand_im, :hand, :effort]
          )
        end
      end
      Helper.debug_inspect(@pre_scores, "pre best_side_scores " + hand.to_s)
    end

    private def set_side_data(index, hand, scores)
      @pre_scores[hand][index] = scores.clone
    end

    private def do_products(
      name : String,
      hand : Hand,
      side : Array(UInt8),
      other_side : Array(UInt8)
    )
      direction = hand.to_s.downcase

      hand_filter, effort_filter = get_hand_filters(hand)
      # use
      # FIXME: does this work?
      # hand_filter = @left_sided_filter
      # effort_filter = @l_effort_score

      counter = 0
      tmp = Array(Array(UInt8)).new
      tmp << side

      # Important this is what we work with
      side_w_ordered = order_side_by_weight(side, hand)

      s_count = @config[:stage2_count]
      last_n = side_w_ordered[s_count..-1]

      # FIXME: do this outside? or here
      perm_n = last_n.permutations

      # if hand == Hand::RIGHT
      debug_half_effort(effort_filter, name, "right")
      debug_half_hand(hand_filter, hand)
      # end
      # Cleaner.exit_success

      side_w_ordered[0..s_count - 1].each_permutation(s_count) do |x|
        counter += 1

        # Here x is w_ordered not by position
        next unless effort_filter.pass_w_ordered?(x + last_n)
        # FIXME hand_filter? does it need hand?

        hand_filter.scan(order_side_by_position(x + last_n, hand), hand: hand)
        next unless hand_filter.pass?

        #   Helper.debug_inspect(hand_filter.scores, "do_products scores " + hand.to_s)
        #   Helper.debug_inspect(hand_filter.min_hand, "do_products min_hand " + hand.to_s)
        #   Helper.debug_inspect(hand_filter.min_same_both, "do_products min_same_both " + hand.to_s)

        permutations_product([[x], perm_n]).each do |p|
          next unless effort_filter.pass_w_ordered?(p)

          # FIXME: try order only last_n and have others pre ordered?
          # or what?
          ordered = order_side_by_position(p, hand: hand)
          hand_filter.scan(ordered, hand)
          tmp << ordered if hand_filter.pass?
        end
        if tmp.size > 20_000_000
          STDERR.puts "       captured #{hand.to_s}: " + tmp.size.to_s
          scanner(tmp, name: name, other_side: other_side, hand: hand, ordered: true)
          tmp.clear
        end
      end
      unless tmp.empty?
        STDERR.puts "     + total captured #{hand.to_s}: " + tmp.size.to_s
        scanner(tmp, name: name, other_side: other_side, hand: hand, ordered: true)
        tmp.clear
        Helper.put_debug("* total permutations: " + counter.to_s)
      end
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
      if hand == Hand::LEFT
        db = @db_left
        array.each do |x|
          _tmp = x.clone
          #          unless ordered
          #            x = order_side_by_position(x, hand)
          #            next unless @l_effort_score.pass?(x)
          #            next unless @left_sided_filter.pass?(x, hand: hand)
          #          end
          scan(x, other_side, name, db)
        end
      else
        db = @db_right
        array.each do |x|
          _tmp = x.clone
          #          unless ordered
          #            x = order_side_by_position(x, hand)
          #            next unless @r_effort_score.pass?(x)
          #            next unless @right_sided_filter.pass?(x, hand: hand)
          #          end
          scan(other_side, x, name, db)
        end
      end
    end

    # Scans, Scores and Writes to db
    private def scan(left, right, name, db)
      layout = Utils.lr_to_string(left, right, @characters.sorted)

      @layout_score.scan(left, right, name)

      # fixm this filter
      # if @lr_filter.pass? @layout_score.score
      db.db.exec(SQL_TBL_LAYOUTS_INSERT, *@layout_score.score.values)
      # db.db.exec(UPDATE_SCORE_SQL, @layout_score.score.score, @layout_score.score.layout)
      # end
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

    private def combine_weights_helper(ar1, ar2)
      result1 = ar1.clone
      ar2_rev = ar2.sort.reverse
      result2 = ar2_rev.clone
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

    #    private def set_side_max_effort(filter, side, hand)
    #      filter.pass?(side, hand: hand)
    #      # filter.min = (filter.score * FILTER_FACTOR).to_i16
    #    end
    #
    private def setup_filters(layout)
      filter_characters(layout.split(""))

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
      @right_sided_filter = OneSidedFilter.new(
        @characters.clone,
        @bigrams,
      )

      @l_effort_score = HalfEffortFilter.new(
        @characters.clone,
        ProjectConfig.instance.config[:left_to_32],
        @left_32_index_by_weight
      )
      @r_effort_score = HalfEffortFilter.new(
        @characters.clone,
        ProjectConfig.instance.config[:right_to_32],
        @right_32_index_by_weight
      )
    end

    private def setup_filters_min(left, right, name)
      set_side_filter_min(@left_sided_filter, left, Hand::LEFT)
      set_side_filter_min(@right_sided_filter, right, Hand::RIGHT)

      # FIXME: we don't need string or do we?
      @layout_score.scan(left, right, name)
      debug_layout_score(name)

      @l_effort_score.scan(left)
      @l_effort_score.min = @l_effort_score.score + @config[:effort_delta]
      debug_half_effort(@l_effort_score, name, "left")

      @r_effort_score.scan(right)
      @r_effort_score.min = @r_effort_score.score + @config[:effort_delta]
      debug_half_effort(@r_effort_score, name, "right")
    end

    private def setup_lr_filter
      # just get the score and set it to min
      @lr_filter.pass?(@layout_score.score)
      # FIXME: maybe here different factor
      @lr_filter.min_hand = (@lr_filter.score * @config[:filter_factor]).to_i16
      @lr_filter.min_same_both = (@lr_filter.score_same_both * @config[:filter_factor]).to_i16
      # combined should not be below EFFORT_DELTA
      @lr_filter.min_effort = (@lr_filter.score_effort + (@config[:effort_delta])).to_i16
    end

    @[AlwaysInline]
    private def db_name(name, hand)
      return "db/#{name}-#{hand}.db"
    end

    @[AlwaysInline]
    private def setup_eval_options(db_out)
      return OptionsHash{"out" => db_out, "print" => false}
    end

    @[AlwaysInline]
    private def stage1_name(name, index)
      name + "_" + index.to_s
    end

    @[AlwaysInline]
    private def puts_stage(num)
      STDERR.puts "  . stage#{num}"
    end

    @[AlwaysInline]
    private def puts_improving(name)
      STDERR.puts "* improving #{name}:"
    end

    private def debug_half_effort(filter, name, side)
      Helper.debug_inspect(
        filter.score,
        "#{name} (effort_filter #{side}) half effort"
      )
      Helper.debug_inspect(
        filter.min,
        "#{name} (effort_filter #{side}) min"
      )
    end

    private def debug_half_hand(filter, hand)
      side = hand
      Helper.debug_inspect(
        filter.scores[:hand],
        "(half_hand_filter #{side}) hand"
      )
      Helper.debug_inspect(
        filter.scores[:hand_im],
        "(half_hand_filter #{side}}) hand_im"
      )
      Helper.debug_inspect(
        filter.min_hand,
        "(half_hand_filter #{side}) min_hand"
      )
      Helper.debug_inspect(
        filter.min_same_both,
        "(half_hand_filter #{side}) min_same_both"
      )
    end

    private def debug_layout_score(name)
      Helper.debug_inspect(
        @layout_score.score.layout,
        "#{name} layout"
      )

      Helper.debug_inspect(
        @layout_score.score.same_finger_rp,
        "#{name} same_finger_rp"
      )
      Helper.debug_inspect(
        @layout_score.score.same_finger_im,
        "#{name} same_finger_im"
      )
      Helper.debug_inspect(
        @layout_score.score.positional_effort,
        "#{name} positional_effort"
      )
    end
  end
end
