require "big"

# NOTE: need to not forget that some left/right here are not in correct
# order and therefore can't be filtered by any filter that doesn't
# understand how to filter no-ordered
module Kilo
  class LayoutStage
    @name : String = ""
    @sides = Array(SideType).new(size: 2, value: SideType.new(size: 16, value: 0))
    @scores = Array(SimpleScoresType).new(size: 2, value: NULL_SIMPLE_SCORES.clone)
    property name
    property sides
    property scores
  end

  class Improve < Command
    PERMUTATIONS_MAX   = 7
    EMPTY_U8_ARRAY     = SideType.new
    EMPTY_STRING_ARRAY = Array(String).new
    STAGES1            = [:stage1_0, :stage1_1, :stage1_2]

    @db = DB_Helper.new

    @db_left = DB_Helper.new
    @db_right = DB_Helper.new

    @layout_score = LayoutScore.new
    @layouts = Array(UserLayout).new
    @left_32_index_by_weight : Array(Int32)
    @right_32_index_by_weight : Array(Int32)

    @sided_filters = Array(OneSidedFilter).new(size: 2, value: OneSidedFilter.new)
    @sided_effort_filters = Array(HalfEffortFilter).new(size: 2, value: HalfEffortFilter.new)
    @layout_stages = Hash(Symbol, LayoutStage){
      :original    => LayoutStage.new,
      :best_effort => LayoutStage.new,
      :stage1_0    => LayoutStage.new,
      :stage1_1    => LayoutStage.new,
      :stage1_2    => LayoutStage.new,
    }

    # To eliminate doubles in sides in stage1
    @layout_sides = Hash(Hand, Set(SideType)){
      Hand::LEFT  => Set(SideType).new,
      Hand::RIGHT => Set(SideType).new,
    }

    @config : ImproveConfigType

    def initialize
      super

      @config = ProjectConfig.instance.config[:improve_config]

      left_to_32 = ProjectConfig.instance.config[:left_to_32]
      right_to_32 = ProjectConfig.instance.config[:right_to_32]

      @left_32_index_by_weight = Utils.index_by_weight(side_to_32: left_to_32)
      @right_32_index_by_weight = Utils.index_by_weight(side_to_32: right_to_32)

      @eval = Eval.new
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

        results = prepare_results(x)

        # append original layout
        results << x[:k32] + " " + x[:name]

        save_results(results, db_out)

        # clear sets
        @layout_sides[Hand::LEFT].clear
        @layout_sides[Hand::RIGHT].clear
      end
    end

    private def prepare_results(layout)
      layouts_left, layouts_right = improved_selection(layout)

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

        lefts = Array(SideType).new
        rights = Array(SideType).new

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

    # private def get_side_limits(left, right, hand)
    private def get_side_limits(other_hand)
      half_same_finger_rp = @config[:sql_half_same_finger_rp]
      half_same_finger_im = @config[:sql_half_same_finger_im]
      half_jumps = @config[:sql_half_jumps]
      half_outward = @config[:sql_half_outward]

      other_scores = @layout_stages[:original].scores[other_hand.value]

      Helper.debug_inspect(other_scores[:same_finger_rp],
        other_hand.to_s + " same_finger_rp")
      Helper.debug_inspect(half_same_finger_rp,
        other_hand.to_s + " half_same_finger_rp config")

      return SimpleScoresType{
        :same_finger_rp => other_scores[:same_finger_rp] + half_same_finger_rp,
        :same_finger_im => other_scores[:same_finger_im] + half_same_finger_im,
        :jumps          => other_scores[:jumps] + half_jumps,
        :outward        => other_scores[:outward] + half_outward,
      }
    end

    # We do selection with sql to find best results
    private def improved_selection(layout)
      layouts_left = Array(Score).new
      layouts_right = Array(Score).new

      name = layout[:name]
      layout_s = layout[:k32]

      left, right = Utils.string_to_lr(layout_s, @characters)

      setup_filters_min(left, right, name)
      best_effort_adjust_min(Hand::LEFT)
      best_effort_adjust_min(Hand::RIGHT)

      @args.each do |file|
        l_sql = Utils.read_user_improve_sql(
          file.to_s,
          default: DEFAULT_SELECT,
          limit: @opts["limit"].to_s,
          scores: get_side_limits(other_hand: Hand::RIGHT)
        )
        r_sql = Utils.read_user_improve_sql(
          file.to_s,
          default: DEFAULT_SELECT,
          limit: @opts["limit"].to_s,
          scores: get_side_limits(other_hand: Hand::LEFT)
        )

        layouts_left.concat(Utils.query_layouts_db(@db_left, l_sql))
        layouts_right.concat(Utils.query_layouts_db(@db_right, r_sql))
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
        @eval.eval_layouts(_layouts, db)

        db.close
      end
    end

    private def set_side_filter_min(side, hand)
      filter = @sided_filters[hand.value]
      filter.scan(side, hand: hand)

      # get score and if score is above max use max
      max_hand = (filter.score * @config[:filter_factor]).to_i16
      if max_hand > @config[:max_half_hand]
        max_hand = @config[:max_half_hand]
      end

      filter.min_hand = max_hand

      max_outward = (filter.score * @config[:filter_factor]).to_i16
      if max_outward > @config[:max_half_outward]
        max_outward = @config[:max_half_outward]
      end

      filter.min_outward = max_outward

      config_max_both = @config[:max_half_same_finger_rp] + @config[:max_half_same_finger_im]
      max_both = (filter.score_same_both * @config[:filter_factor]).to_i16
      if max_both > config_max_both
        max_both = config_max_both
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
      puts_stage(2)

      STAGES1.each do |sym|
        _left, _right = get_lr_stages(sym)

        setup_filters_min(_left, _right, name)

        do_products(
          name,
          hand: Hand::LEFT,
          side: _left,
          other_side: right,
        )

        do_products(
          name,
          hand: Hand::RIGHT,
          side: _right,
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

      # original and best_effort
      setup_originals(left, right, name)

      puts_improving(name)

      left = @layout_stages[:best_effort].sides[Hand::LEFT.value]
      right = @layout_stages[:best_effort].sides[Hand::RIGHT.value]

      setup_filters_min(left, right, name)
      improve_stage1(name, left, right)

      if @opts["fast"].as(Bool)
        save_fast(db_out)
        return
      end

      Utils.reinit_db(@db_left)
      Utils.reinit_db(@db_right)

      left, right = get_lr_stages(:original)

      # add original left/right
      scanner([left], name: name, other_side: right, hand: Hand::LEFT, ordered: true)
      scanner([right], name: name, other_side: left, hand: Hand::RIGHT, ordered: true)

      setup_filters_min(left, right, name)
      improve_stage2(name, left, right)
    end

    private def get_lr_stages(key)
      return @layout_stages[key].sides[Hand::LEFT.value],
        @layout_stages[key].sides[Hand::RIGHT.value]
    end

    private def save_fast(db_out)
      @db.close
      @db = Utils.create_db(db_out)
      STAGES1.each do |k|
        left, right = get_lr_stages(k)
        name = @layout_stages[k].name

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
      return @sided_filters[hand.value], @sided_effort_filters[hand.value]
    end

    private def multi_filter(
      hand,
      key,
      keys,
      side
    )
      scores = @sided_filters[hand.value].scores
      k = keys.shift
      name = @layout_stages[key].name
      if (@layout_stages[key].scores[hand.value][k]) > scores[k]
        setup_layout_stage(key, name, side, hand)
      elsif (@layout_stages[key].scores[hand.value][k]) == scores[k]
        multi_filter(
          hand: hand,
          key: key,
          keys: keys,
          side: side
        ) if keys.size != 0
      end
    end

    @[AlwaysInline]
    private def good_half_scores?(scores)
      (scores[:hand] < @config[:max_half_hand]) &&
        (scores[:same_finger_rp] < @config[:max_half_same_finger_rp]) &&
        (scores[:same_both] <
          @config[:max_half_same_finger_rp] +
            @config[:max_half_same_finger_im])
    end

    private def do_stage1(
      name : String,
      hand : Hand,
      side : SideType,
      other_side : SideType
    )
      hand_filter, effort_filter = get_hand_filters(hand)

      # gets effort filter from orignal 1
      best_effort_adjust_min(hand)

      side_p_ordered = order_side_by_position(side, hand)
      hand_filter.scan(side_p_ordered, hand: hand)

      # set starting point
      setup_layout_stage(:stage1_0, name, side_p_ordered, hand)
      setup_layout_stage(:stage1_1, name, side_p_ordered, hand)
      setup_layout_stage(:stage1_2, name, side_p_ordered, hand)

      char_by_weight(hand, side).each do |lookup|
        perm = side_permutations(lookup)
        prod = permutations_product(perm)
        permutations_product(perm).each do |x|
          # Important this is what we work with
          side_p_ordered = order_side_by_position(x, hand)
          hand_filter.scan(side_p_ordered, hand: hand)

          next unless effort_filter.pass?(side_p_ordered)

          scores = hand_filter.scores
          scores[:effort] = effort_filter.score

          next unless good_half_scores?(scores)

          multi_filter(
            hand: hand,
            side: side_p_ordered,
            key: :stage1_0,
            keys: [:same_both, :same_finger_rp, :hand, :effort],
          )

          multi_filter(
            hand: hand,
            side: side_p_ordered,
            key: :stage1_1,
            keys: [:same_both_j, :same_finger_rp, :jumps, :outward, :effort] # keys: [:hand, :same_both, :same_rp, :effort]
          )

          multi_filter(
            hand: hand,
            side: side_p_ordered,
            key: :stage1_2,
            keys: [:hand_im, :hand, :effort]
          )
        end
      end
      Helper.debug_inspect(@layout_stages, "layout_stages " + hand.to_s)
    end

    private def best_effort_adjust_min(hand)
      @sided_effort_filters[hand.value].min =
        @layout_stages[:best_effort].scores[hand.value][:effort] + @config[:effort_delta]
    end

    private def do_products(
      name : String,
      hand : Hand,
      side : SideType,
      other_side : SideType
    )
      return if @layout_sides[hand].includes? side
      scanner([side], name: name, other_side: other_side, hand: hand, ordered: true)

      direction = hand.to_s.downcase

      hand_filter, effort_filter = get_hand_filters(hand)

      counter = 0
      tmp = Array(SideType).new
      tmp << side

      best_effort_adjust_min(hand)

      # Important this is what we work with
      side_w_ordered = order_side_by_weight(side, hand)

      s_count = @config[:stage2_count]
      last_n = side_w_ordered[s_count..-1]

      perm_n = last_n.permutations

      side_w_ordered[0..s_count - 1].each_permutation(s_count) do |x|
        counter += 1

        # Here x is w_ordered not by position
        next unless effort_filter.pass_w_ordered?(x + last_n)

        hand_filter.scan(order_side_by_position(x + last_n, hand), hand: hand)
        next unless hand_filter.pass?

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
    private def scanner(array, name, other_side, hand, ordered = false)
      if hand == Hand::LEFT
        db = @db_left
        array.each do |x|
          _tmp = x.clone
          next if @layout_sides[hand].includes? x
          scan(x, other_side, name, db)
          @layout_sides[hand].add(x)
        end
      else
        db = @db_right
        array.each do |x|
          _tmp = x.clone
          next if @layout_sides[hand].includes? x
          scan(other_side, x, name, db)
          @layout_sides[hand].add(x)
        end
      end
    end

    # Scans, Scores and Writes to db
    private def scan(left, right, name, db)
      layout = Utils.lr_to_string(left, right, @characters.sorted)

      @layout_score.scan(left, right, name)

      db.db.exec(SQL_TBL_LAYOUTS_INSERT, *@layout_score.score.values)
    end

    # Returns the product of two arrays (of permutations)
    private def get_products(one : Array(SideType), two : Array(SideType)) : Array(SideType)
      res = Array(SideType).new
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
      result = Hash(Int32, SideType).new
      empty = SideType.new
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

    private def char_by_weight(hand : Hand, side : SideType) : Array(Hash(Int32, SideType))
      result = Array(Hash(Int32, SideType)).new
      result << Hash(Int32, SideType).new

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
          result[-1][w] = SideType.new
        end
        # don't add index add char?
        result[-1][w] << side[i]
      end

      result[0] = combine_weights(result[-1], 2)

      Helper.debug_inspect(result, context: "result")

      return result
    end

    # returns permutations for each array of weight
    private def side_permutations(lookup) : Array(Array(SideType))
      result = Hash(Int32, Array(SideType)).new

      lookup.each_key do |k|
        v = lookup[k]
        result[k] = Array(SideType).new
        v.permutations.each do |x|
          result[k] << x
        end
      end
      return result.to_a.sort { |a, b| a[0] <=> b[0] }.map { |x| x[1] }
    end

    # Combines all permutations together in possible layouts
    # There is no way to do this product by product so it is a limit
    # in how many permutations we can have
    private def permutations_product(perm) : Array(SideType)
      result = Array(SideType).new

      result = get_products(perm[0], perm[1])
      2.upto(perm.size - 1).each do |i|
        result = get_products(result, perm[i])
      end
      return result
    end

    private def setup_filters(layout)
      filter_characters(layout.split(""))

      # FIXME: set characters/bigrams again don't create a new one
      @layout_score = LayoutScore.new(
        characters: @characters.clone,
        bigrams: @bigrams
      )

      @sided_filters[Hand::LEFT.value] = OneSidedFilter.new(
        @characters.clone,
        @bigrams,
      )
      @sided_filters[Hand::RIGHT.value] = OneSidedFilter.new(
        @characters.clone,
        @bigrams,
      )

      @sided_effort_filters[Hand::LEFT.value] = HalfEffortFilter.new(
        @characters.clone,
        ProjectConfig.instance.config[:left_to_32],
        @left_32_index_by_weight
      )
      @sided_effort_filters[Hand::RIGHT.value] = HalfEffortFilter.new(
        @characters.clone,
        ProjectConfig.instance.config[:right_to_32],
        @right_32_index_by_weight
      )
    end

    private def setup_layout_stage(key, name, side, hand)
      scores = @sided_filters[hand.value].scores.clone
      scores[:effort] = @sided_effort_filters[hand.value].score
      @layout_stages[key].scores[hand.value] = scores
      @layout_stages[key].sides[hand.value] = side.clone
      @layout_stages[key].name = name
    end

    # FIXME: how to setup @left and right?
    private def setup_originals(left, right, name)
      # FUNCTIONS?
      setup_filters_min(left, right, name)
      setup_layout_stage(:original, name, left, Hand::LEFT)
      setup_layout_stage(:original, name, right, Hand::RIGHT)

      _left, _right = Utils.get_best_effort(left,
        right,
        @left_32_index_by_weight,
        @right_32_index_by_weight)

      setup_filters_min(_left, _right, name)
      setup_layout_stage(:best_effort, name, _left, Hand::LEFT)
      setup_layout_stage(:best_effort, name, _right, Hand::RIGHT)
    end

    private def setup_filters_min(left, right, name)
      set_side_filter_min(left, Hand::LEFT)
      set_side_filter_min(right, Hand::RIGHT)

      @layout_score.scan(left, right, name)
      debug_layout_score(name)

      # FIXME: need a function
      filter = @sided_effort_filters[Hand::LEFT.value]
      filter.scan(left)
      filter.min = filter.score + @config[:effort_delta]
      debug_half_effort(filter, name, "left")

      filter = @sided_effort_filters[Hand::RIGHT.value]
      filter.scan(right)
      filter.min = filter.score + @config[:effort_delta]
      debug_half_effort(filter, name, "right")
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
