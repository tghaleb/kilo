require "../ishi_svg"

module Kilo
  class Compare < Command
    include Constants

    EXTRA_CHARTS = Set.new([:same_both, :indices, :middles, :rings, :pinkies])

    @db = DB_Helper.new
    @sql = SELECT_ALL

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

      @db = DB_Helper.new(_db_file)
      @sql = Utils.read_user_sql(
        @opts["sql"].to_s, default: SELECT_ALL, limit: @opts["limit"].to_s)

      begin
        layouts = Utils.query_layouts_db(@db, @sql)
        compare(layouts, @db.file)
      rescue e
        @db.close
        Cleaner.exit_failure(e.message.to_s)
      end

      @db.close
    end

    private def plot(data, names, colors, outfile, ylabel = "", sort = false, assending = true)
      indices = (0..(data.size - 1)).to_a
      if sort
        if assending
          indices.sort! { |a, b| data[a].as(Float) <=> data[b].as(Float) }
        else
          indices.sort! { |a, b| data[b].as(Float) <=>
            data[a].as(Float) }
        end
      end

      File.open(outfile, "w") do |io|
        Ishi.new(io) do
          indices.each_with_index do |pos, i|
            y = data[pos].as(Float)
            x = i + 1
            plot([x], [y],
              title: names[pos + 1],
              style: :boxes,
              fs: 0.5,
              lc: colors[pos + 1])
              .boxwidth(0.8)
              # we don't want labels on x
              .xtics({(data.size + 1).to_f => ""})
          end
          extra_sp = (data.size * 2).to_i
          plot([extra_sp], [0],
            title: "",
            style: :boxes,
            fs: 0.5,
            lc: "black")
            .boxwidth(0.8)
            .ylabel(ylabel)
          show
        end
        STDERR.puts("* wrote #{outfile}") if @verbose
      end
    end

    private def gen_comparison(layouts)
      outward = Array(Float64).new
      jumps = Array(Float64).new
      same_finger_rp = Array(Float64).new
      same_finger_both = Array(Float64).new
      positional_effort = Array(Float64).new
      score = Array(Float64).new
      alternation = Array(Float64).new
      text_direction = Array(Float64).new
      same_hand_effort = Array(Float64).new
      indices = Array(Float64).new
      middles = Array(Float64).new
      pinkies = Array(Float64).new
      rings = Array(Float64).new

      tics = Hash(Float64, String).new
      names = Hash(Int32, String).new
      colors = Hash(Int32, String).new
      colors_new = Utils.color_gen(layouts.size)

      layouts.each_with_index do |layout, i|
        outward << layout.outward/100
        jumps << layout.jumps/100
        same_finger_rp << layout.same_finger_rp/100
        same_finger_both << (layout.same_finger_rp/100) + (layout.same_finger_im/100)
        positional_effort << layout.positional_effort/100
        alternation << layout.alternation/100
        text_direction << layout.text_direction/100
        same_hand_effort << same_finger_rp[-1] + jumps[-1] + outward[-1]
        pinkies << layout.pinkies/100
        middles << layout.middles/100
        indices << layout.indices/100
        rings << layout.rings/100
        score << layout.score/100
        tic = i + 1
        tics[tic.to_f] = tic.to_s
        names[tic] = layout.name
        colors[tic] = colors_new[i]
      end

      return {
        names:             names,
        colors:            colors,
        jumps:             jumps,
        outward:           outward,
        same_finger_rp:    same_finger_rp,
        same_finger_both:  same_finger_both,
        same_hand_effort:  same_hand_effort,
        positional_effort: positional_effort,
        indices:           indices,
        middles:           middles,
        rings:             rings,
        pinkies:           pinkies,
        alternation:       alternation,
        text_direction:    text_direction,
        score:             score,
      }
    end

    private def compare(layouts, db_file)
      data = gen_comparison(layouts)
      # full or not?

      db_name = File.basename(db_file)
      ensure_exports_dir(EXPORTS_DIR)

      data.each_key do |k|
        next if (k == :names) || (k == :colors)

        unless @opts["full"].as(Bool)
          next if EXTRA_CHARTS.includes? k
        end

        assending = true

        if (k == :score) || (k == :alternation) || (k == :text_direction)
          assending = false
        end

        plot(
          data[k],
          data[:names],
          data[:colors],
          outfile: File.join(EXPORTS_DIR, "#{db_name}.#{k}.svg"),
          ylabel: k.to_s.capitalize,
          sort: true,
          assending: assending)
      end
    end
  end
end
