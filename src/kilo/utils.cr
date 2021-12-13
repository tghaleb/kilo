require "big"

module Kilo
  module Utils
    include Constants

    # Returns how many combinations for a given N and R
    def self.calculate_ncr(n, r)
      return BigInt.new(n).factorial/BigInt.new(r).factorial/BigInt.new(n - r).factorial
    end

    # Validates format of user layouts from a file.
    # the format is columns separated by space
    # col 0 : 32 main characters (required)
    # col 1 : name (optional if nothing comes after it)
    def self.validate_user_layout(layout : String, line_num) : Tuple
      {Bool, Array(String)}
      parts = layout.split(/\s+/)
      cols = parts.size

      if cols == 1
        parts << ""
      elsif cols > 2
        Cleaner.exit_failure(
          "too many columns in layout (given #{cols}):\n >> #{layout}")
      end

      if parts[0].size != 32
        Cleaner.exit_failure(
          "not enough characters in col 0, need 32:\n >>
            #{parts[0]}")
      end

      return true, parts if cols <= 2
      return false, parts
    end

    def self.load_user_layouts(array : Array(String)) : Array(UserLayout)
      _layouts = Array(UserLayout).new
      counter = 0

      array.each do |line|
        line = line.strip
        next if line.size == 0

        short, parts = Utils.validate_user_layout(line.strip, counter)
        counter += 1

        _layouts << {
          k32:  parts[0],
          name: parts[1],
        }
      end
      return _layouts
    end

    # Loads layouts from a file
    def self.load_user_layouts(file : String) : Array(UserLayout)
      _layouts = Array(UserLayout).new
      counter = 0
      # file_in_directory(file, remove: true) do |_file|
      File.open(file).each_line do |line|
        line = line.strip
        next if line.size == 0

        short, parts = Utils.validate_user_layout(line.strip, counter)
        counter += 1

        _layouts << {
          k32:  parts[0],
          name: parts[1],
        }
      end
      # end
      return _layouts
    end

    def self.lr_to_string(left, right, chars)
      layout = Array(String).new(value: " ", size: 32)

      lr_to_32(left, right).each_with_index do |x, i|
        layout[i] = chars[x]
      end

      return layout.join("")
    end

    # Returns Left/Right to a combined 32 Array of UInt8
    def self.lr_to_32(left, right)
      layout = Array(UInt8).new(size: 32, value: 0)

      left_to_32 = ProjectConfig.instance.config[:left_to_32]
      right_to_32 = ProjectConfig.instance.config[:right_to_32]

      left.each_with_index { |x, i| layout[left_to_32[i]] = x }
      right.each_with_index { |x, i| layout[right_to_32[i]] = x }
      return layout
    end

    # debugger for layouts
    def self.debug_layout(left, right, name = "layout")
      #      layout = Array(String).new(value: " ", size: 32)

      #      lr_to_32(left, right).each_with_index do |x, i|
      #        layout[i] = "%2d" % x
      #      end
      #
      layout = Array(String).new(value: " ", size: 32)

      lr_to_32(left, right).each_with_index do |x, i|
        layout[i] = "%2d" % x
      end

      debug_layout(layout)
      # Helper.debug_inspect(layout[0..10].join(" "), "layout r1")
      # Helper.debug_inspect(layout[11..21].join(" "), "layout r2")
      # Helper.debug_inspect(layout[22..31].join(" "), "layout r3")
    end

    def self.debug_layout(layout : Array(String), name = "layout")
      Helper.put_debug(name)
      Helper.debug_inspect(layout[0..10].join(" "), "layout r1")
      Helper.debug_inspect(layout[11..21].join(" "), "layout r2")
      Helper.debug_inspect(layout[22..31].join(" "), "layout r3")
    end

    # debugger for layouts
    def self.debug_diff_layouts(left1, right1, left2, right2, name1 = "layout1", name2 = "layout2")
      layout1 = Array(String).new(value: "--", size: 32)
      layout2 = Array(String).new(value: "--", size: 32)

      _layout1 = lr_to_32(left1, right1)
      _layout2 = lr_to_32(left2, right2)

      debug_layout(left1, right1, name1)
      debug_layout(left2, right2, name2)

      layout1.each_index do |i|
        unless _layout1[i] == _layout2[i]
          layout1[i] = "%2d" % _layout1[i]
          layout2[i] = "%2d" % _layout2[i]
        end
      end

      debug_layout(layout1, name1)
      debug_layout(layout2, name2)
    end

    # left array (or right) to uint32 layout
    @[AlwaysInline]
    def self.left_array_to_u32(layout)
      u32 = 0.to_u32
      mask1 = 1.to_u32
      layout.each do |i|
        u32 |= mask1 << i
      end
      return u32
    end

    def self.index_by_weight(side_to_32) : Array(Int32)
      kb_weights = ProjectConfig.instance.config[:kb_weights]
      return (0..side_to_32.size - 1).to_a.sort do |a, b|
        key_a = KEYS_32[side_to_32[a]]
        key_b = KEYS_32[side_to_32[b]]
        kb_weights[key_a] <=> kb_weights[key_b]
      end
    end

    # use an object
    def self.half_effort(side, side_to_32, characters)
      kb_weights = ProjectConfig.instance.config[:kb_weights]
      effort = 0
      side.each_index do |i|
        index = side_to_32[i]
        # puts index
        w = characters[side[i]]
        # puts w
        key = KEYS_32[index]
        # puts key
        effort += (kb_weights[key] * w)
      end
      if effort > Int16::MAX
        return Int16::MAX
      else
        return (effort/EFFORT_SCALE).to_i16
      end
    end

    def self.get_best_min_effort(left, right, l_by_weight, r_by_weight, chars, delta = 100)
      l, r = get_best_effort(left, right, l_by_weight, r_by_weight)

      left_to_32 = ProjectConfig.instance.config[:left_to_32]
      right_to_32 = ProjectConfig.instance.config[:right_to_32]

      if (half_effort(left, left_to_32, chars) - half_effort(l,
           left_to_32, chars)).abs > delta
        _left = l
      else
        _left = left
      end

      if (half_effort(right, right_to_32, chars) - half_effort(r,
           right_to_32, chars)).abs > delta
        _right = r
      else
        _right = right
      end

      return _left, _right
    end

    def self.get_best_effort(left, right, l_by_weight, r_by_weight)
      l = Array(UInt8).new(size: left.size, value: 0)
      r = Array(UInt8).new(size: right.size, value: 0)

      l_sorted = left.sort
      r_sorted = right.sort

      # Helper.debug_inspect(kb_weights, "kb_weights")
      # Helper.debug_inspect(l_sorted, "l_sorted")

      # FIXME: if in group don't place it.
      l_sorted.each_index do |i|
        #        if kb_weights[i] = l_sorted[i]
        #        end
        l[l_by_weight[i]] = l_sorted[i]
      end

      r_sorted.sort.each_index do |i|
        r[r_by_weight[i]] = r_sorted[i]
      end

      return l, r
    end

    def self.string_to_lr(layout : String, chars)
      list = layout.split("")

      left_to_32 = ProjectConfig.instance.config[:left_to_32]
      right_to_32 = ProjectConfig.instance.config[:right_to_32]

      left = Array(UInt8).new(size: left_to_32.size, value: 0)
      right = Array(UInt8).new(size: right_to_32.size, value: 0)

      left.each_index do |i|
        char = list[left_to_32[i]]
        left[i] = chars.sorted_rev[char].to_u8
      end
      right.each_index do |i|
        char = list[right_to_32[i]]
        right[i] = chars.sorted_rev[char].to_u8
      end

      return [left, right]
    end

    # converts layout to left/right arrays
    def self.u32_to_lr(layout : UInt32)
      # do we set right and left correctly? or not
      # probably not non of our business

      left = Array(UInt8).new
      right = Array(UInt8).new

      Bits.loop_over_set_bits(layout) do |x|
        left << x.to_u8
      end

      Bits.loop_over_set_bits(~layout) do |x|
        right << x.to_u8
      end

      return [left, right]
    end

    # Reads user sql file or exits.
    def self.read_user_sql(file : String, default : String, limit : String) : String
      sql = default.strip
      if file.to_s != ""
        _sql_file = file
        unless File.file? _sql_file
          Cleaner.exit_failure("not a file '#{_sql_file}'")
        end
        sql = File.read(_sql_file).strip
      end
      return sql.sub(/(LIMIT.*|;)?$/i, " LIMIT #{limit};")
    end

    def self.query_layouts_db(db, sql, &block)
      db.query(sql) do |rs|
        Score.from_rs(rs).each do |x|
          yield x
        end
      end
    end

    def self.query_layouts_db(db, sql) : Array(Score)
      layouts = Array(Score).new
      db.query(sql) do |rs|
        Score.from_rs(rs).each do |x|
          layouts << x
        end
      end
      return layouts
    end

    # Uses user script to update score column
    def self.update_score(db_file, script, inplace = false)
      return if script == ""

      unless File.executable? script
        Cleaner.exit_failure("Not an excecutable '#{script}'")
      end

      STDERR.puts(" + updating scores in #{db_file}")

      Helper.run(script, args: [db_file], msg: "user script failed")
    end

    @[AlwaysInline]
    def self.row_jump?(key1 : Key, key2 : Key) : Bool
      kb_rows = ProjectConfig.instance.config[:kb_rows]
      if (kb_rows[key1].value - kb_rows[key2].value).abs > 1
        return true
      else
        return false
      end
    end

    @[AlwaysInline]
    def self.which_finger(key : Key) : Constants::Finger
      kb_fingers = ProjectConfig.instance.config[:kb_fingers]
      return kb_fingers[key]
    end

    @[AlwaysInline]
    def self.which_hand(key : Key) : Constants::Hand
      return FINGER_HAND[which_finger(key)]
    end

    @[AlwaysInline]
    def self.same_hand?(finger1 : Finger, finger2 : Finger)
      if FINGER_HAND[finger1] == FINGER_HAND[finger2]
        return true
      end
      return false
    end

    # make these info function

    @[AlwaysInline]
    def self.key_32_left(index : Int32) : Key
      left_to_32 = ProjectConfig.instance.config[:left_to_32]

      KEYS_32[left_to_32[index]]
    end

    @[AlwaysInline]
    def self.key_32_right(index : Int32) : Key
      right_to_32 = ProjectConfig.instance.config[:right_to_32]
      KEYS_32[right_to_32[index]]
    end

    # builds chari => {bi_i => freq, bi_i, freq ...
    # when combined is given it combines ab with ba into one value,
    # used by alternation for example, and useful for getting
    # information using one side only. But for working on one hand only
    # you should set combined = false.
    def self.build_char_bigram_i_2(characters, bigrams, combined)
      char_bigram_i = Array(Hash(UInt32, Int64)).new

      characters.sorted.each do |k|
        char_bigram_i << {} of UInt32 => Int64

        bigrams.sorted.each do |bi|
          # skip 0 counts
          next if bigrams.data[bi] == 0

          test_bigram = (bi.includes? k)

          unless combined
            test_bigram = (bi[0].to_s == k)
          end

          if test_bigram
            char = k
            unless bi == (k + k)
              # this is the usual one
              char = bi.delete(k[0]) # NOTE: some characters cause problems, this is explicity character
              # could be a bug in crystal
            end

            idx = characters.sorted_rev[char].to_u32

            unless char_bigram_i[-1].has_key? idx
              char_bigram_i[-1][idx] = 0
            end

            if combined
              char_bigram_i[-1][idx] += bigrams.data[bi]
            else
              char_bigram_i[-1][idx] = bigrams.data[bi]
            end
          end
        end
      end

      return char_bigram_i
    end

    def self.build_char_bigram_i(characters, bigrams)
      char_bigram_i = Array(Array(Tuple(UInt32, Int64))).new

      characters.sorted.each do |k|
        char_bigram_i << Array(Tuple(UInt32, Int64)).new
        bigrams.data.each_key do |bi|
          # skip 0 counts
          next if bigrams.data[bi] == 0
          count = 0
          char1 = bi[0].to_s
          char2 = bi[1].to_s

          if char1 == k
            count = bigrams.data[bi]
            idx1 = characters.sorted_rev[char2.to_s].to_u32
            char_bigram_i[-1] << {idx1, count.to_i64}
          end
        end
      end

      return char_bigram_i
    end

    # Returns a color with brightness in given range
    def Utils.get_rand_color(min = 0, max = 255) : String
      while 1
        rgb = (Random.rand * 0xffffff).to_i
        r = (rgb >> 16) & 0xff
        g = (rgb >> 8) & 0xff
        b = (rgb >> 0) & 0xff
        luma = 0.2126 * r + 0.7152 * g + 0.0722 * b # per ITU-R BT.709
        return "#%06x" % rgb if (luma >= min) && (luma <= max)
      end
      return ""
    end

    # Returns a number of color in given brightness range
    def Utils.color_gen(count, min = 50, max = 190) : Array(String)
      set = Set(String).new

      while set.size < count
        set.add(Utils.get_rand_color(min, max))
      end
      return set.to_a
    end

    # Reads a compressed or non-compressed file
    def self.read_compressed_file(path) : String
      Helper.assert_file(path)
      exten = Path[path].extension.downcase

      if exten == ".zst"
        return Helper.read_zstd(path)
      elsif exten == ".gz"
        return Helper.read_gzip(path)
      else
        return File.read(path)
      end
    end

    def self.read_corpus_lines(&block)
      conf = ProjectConfig.instance.config
      path = File.join(conf["corpus"])
      exten = Path[path].extension.downcase

      if exten == ".zst"
        Helper.read_zstd(path) do |line|
          yield line
        end
      elsif exten == ".gz"
        Helper.read_gzip(path) do |line|
          yield line
        end
      else
        Helper.assert_file(path)
        File.open(path).each_line do |line|
          yield line
        end
      end
    end

    # Returns position 0 .. 9 of finger on keyboard
    @[AlwaysInline]
    def self.finger_pos(finger)
      FINGER_POSITION[finger.value]
    end

    # Returns position of index finger of hand on keyboard
    @[AlwaysInline]
    def self.index_pos(hand)
      HAND_FINGER_OFFSET[hand.value] + 1
    end

    # Returns position of ring finger of hand on keyboard
    @[AlwaysInline]
    def self.ring_pos(hand)
      HAND_FINGER_OFFSET[hand.value] + 3
    end

    def self.create_db(file)
      db = DB_Helper.new(file)
      db.db.exec(SQL_TBL_LAYOUTS_CREATE)
      db
    end

    def self.reinit_db(db)
      db.db.exec(SQL_TBL_LAYOUTS_DROP)
      db.db.exec(SQL_TBL_LAYOUTS_CREATE)
      db
    end
  end
end
