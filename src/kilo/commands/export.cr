module Kilo
  class Export < Command
    @map_config : MapConfig = {name: "", group: "", map: MapData.new,
                               heat: HeatMap.new}

    DEFAULT_EXTRA_KEYS = {
      Key::RTSH => ["Shift_R"],
      Key::LFSH => ["Shift_L"],
      Key::CAPS => ["Caps_Lock"],
      Key::SPCE => ["Space"],
      Key::BKSP => ["BackSpace"],
      Key::RTRN => ["Return"],
      Key::TAB  => ["Tab"],
      Key::LCTL => ["Ctrl_L"],
      Key::RCTL => ["Ctrl_R"],
      Key::LALT => ["Alt_L"],
      Key::RALT => ["Alt_R"],
      Key::COMP => ["Multi_key"],
      Key::LWIN => ["Win_L"],
      Key::RWIN => ["Win_R"],
    }

    def run(
      global_opts : OptionsHash,
      opts : OptionsHash,
      args : Array(String)
    ) : Nil
      assert_inside_project_dir()
      opts_args(global_opts, opts, args)

      ensure_exports_dir(EXPORTS_DIR)

      if @opts["create-templates"].to_s != ""
        OptParser.assert_arg_count(@args, 0..0)
        write_tpl
        Cleaner.exit_success
      elsif @opts["weights"]
        # FIXME: or maybe with other ops?
        # or at least with create-templates
        OptParser.assert_arg_count(@args, 0..0)
        gen_weights(EXPORTS_DIR)
        Cleaner.exit_success
      else
        OptParser.assert_arg_count(@args, 1..MAX_ARGS)
      end

      do_exports
    end

    private def do_exports
      @args.each do |arg|
        _maps_file = arg

        unless File.file? _maps_file
          Cleaner.exit_failure("not a file '#{_maps_file}'")
        end

        @map_config = load_map_config(_maps_file)

        export(EXPORTS_DIR)
      end
    end

    private def ensure_exports_dir(dir)
      unless File.directory? dir
        Dir.mkdir_p(dir)
      end
    end

    def export(dir)
      map = @map_config[:map]
      name = @map_config[:name]

      if name == ""
        Cleaner.exit_failure("missing name in map")
      end

      if @opts["image"]
        obj = Image.new
        str = obj.svg(@map_config)
        path = File.join(dir, name + ".svg")

        write_export(str, path)
      end

      if @opts["heat-map"]
        obj = Image.new
        str = obj.svg(@map_config, heat: true)
        path = File.join(dir, name + ".heat.svg")

        write_export(str, path)
      end

      # if @opts["export"]["xkb"]
      if @opts["xkb"]
        obj = XKB.new(@map_config)
        str = obj.to_s
        path = File.join(dir, name + ".xkb")
        write_export(str, path)
      end

      if @opts["typing"]
        obj = Type.new(@map_config)
        obj.word_limit = ProjectConfig.instance.config[:typing_word_limit]
        str = obj.to_s
        path = File.join(dir, name + ".txt")

        write_export(str, path)
      end

      if @opts["short-typing"]
        obj = Type.new(@map_config)
        obj.word_limit = ProjectConfig.instance.config[:short_typing_word_limit]
        str = obj.to_s
        path = File.join(dir, name + ".short.txt")
        write_export(str, path)
      end
    end

    # Writes file
    private def write_export(str, path)
      Helper.string_to_file(str, path)
      STDERR.puts("* wrote #{path}")
    end

    # Will use as a template and populate
    private def base_map(extra = true) : MapData
      h = MapData.new
      Key.each do |k|
        h[k] = Array(String).new
      end
      if extra
        return h.merge(DEFAULT_EXTRA_KEYS)
      else
        return h
      end
    end

    private def gen_weights_32_data : MapData
      h = base_map(extra: false).clone
      kb_weights = ProjectConfig.instance.config[:kb_weights]
      KEYS_32.each_index do |i|
        h[KEYS_32[i]] = [kb_weights[KEYS_32[i]].to_s]
      end
      return h
    end

    private def gen_heat_32_data(layout_chars : Array(String)) : HeatMap
      h = HeatMap.new

      new_chars = layout_chars.sort

      if @characters.sorted.sort != new_chars
        filter_characters(new_chars)
      end

      Key.each do |k|
        h[k] = 0.to_i64
      end

      KEYS_32.each_index do |i|
        h[KEYS_32[i]] = @characters.data[layout_chars[i]]
      end

      return h
    end

    private def gen_weights(dir)
      name = WEIGHTS_IMAGE_FILE
      h = gen_weights_32_data
      map_config = {name:  name,
                    group: "",
                    map:   h,
                    heat:  HeatMap.new,
      }
      obj = Image.new
      str = obj.svg(map_config)
      path = File.join(dir, name + ".svg")
      write_export(str, path)
    end

    private def write_tpl
      layouts = Utils.load_user_layouts(@opts["create-templates"].to_s)
      base = base_map
      layouts.each do |layout|
        h = base.clone

        # add layouts
        layout_chars = layout[:k32].split("")

        layout_chars.each_index do |i|
          h[KEYS_32[i]] << layout_chars[i]

          up_char = layout_chars[i].upcase
          if up_char != layout_chars[i]
            h[KEYS_32[i]] << up_char
          end
        end

        yaml = {name:  layout[:name],
                group: "",
                map:   h,
                heat:  gen_heat_32_data(layout_chars),
        }

        out_file = tpl_file(layout[:name])

        if File.file? out_file
          STDERR.puts("* will not overwrite #{out_file}")
        else
          Helper.string_to_file(yaml.to_yaml, out_file)
          STDERR.puts("* wrote #{out_file}")
        end
      end
    end

    # Merges groups into map_config
    private def merge_group_config(map)
      if @opts["use-group"] != ""
        group_file = @opts["use-group"].to_s
        Helper.assert_file(group_file)
        x = Helper::YamlTo(Hash(String, Array(String))).load(
          File.read(group_file), group_file)
        map[:map].each_key do |k|
          v = map[:map][k]
          unless v.size == 0
            if x.has_key? v[0]
              map[:map][k] = [v[0]] + x[v[0]]
            end
          end
        end
      end
    end

    # Reads and loads map config
    private def load_map_config(file)
      _map_config = Helper::YamlTo(MapConfig).load(File.read(file), file)
      merge_group_config(_map_config)
      return _map_config
    end

    # path to tpl_file
    private def tpl_file(name)
      return "maps/#{name}.yaml"
    end
  end
end
