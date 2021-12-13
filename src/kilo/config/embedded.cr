module Kilo
  # For embedding files in binary and managing them
  module Embedded
    include Constants
    include Comandante

    SRC_DIR = "data"

    FILES = {
      config:     "config.yaml",
      xkb_list:   "xkb.yaml",
      kb_weights: "kb_weights.yaml",
      kb_fingers: "kb_fingers.yaml",
      kb_rows:    "kb_rows.yaml",
      kb_columns: "kb_columns.yaml",
    }

    EXTRA_FILES = {
      bigrams_eng_web_2014_1M:      "data/bigrams.eng_web_2014_1M-sentences.txt.yml.zst",
      fast_eng_web_2014_1M:         "data/fast.eng_web_2014_1M-sentences.txt.yml",
      default_scorer:               "data/default_scorer.yaml",
      score_base:                   "scripts/base_score.rb",
      score:                        "scripts/score.rb",
      common_db:                    "scripts/common_db.rb",
      layouts_ar:                   "data/layouts.ar.txt",
      layouts_en:                   "data/layouts.en.txt",
      weights:                      "scripts/weights.rb",
      corpus_en_filter:             "scripts/corpus-en-filter.rb",
      sql_by_alternation_grouped:   "sql/by_alternation_grouped.sql",
      sql_by_alternation:           "sql/by_alternation.sql",
      sql_by_direction_grouped:     "sql/by_direction_grouped.sql",
      sql_by_direction:             "sql/by_direction.sql",
      sql_by_hand_grouped:          "sql/by_hand_grouped.sql",
      sql_by_hand:                  "sql/by_hand.sql",
      sql_by_indices:               "sql/by_indices.sql",
      sql_by_jumps_grouped:         "sql/by_jumps_grouped.sql",
      sql_by_jumps:                 "sql/by_jumps.sql",
      sql_by_outward_grouped:       "sql/by_outward_grouped.sql",
      sql_by_outward:               "sql/by_outward.sql",
      sql_by_pinkies:               "sql/by_pinkies.sql",
      sql_by_effort:                "sql/by_effort.sql",
      sql_by_effort_grouped:        "sql/by_effort_grouped.sql",
      sql_by_rings:                 "sql/by_rings.sql",
      sql_by_same_both_grouped:     "sql/by_same_both_grouped.sql",
      sql_by_same_both:             "sql/by_same_both.sql",
      sql_by_same_im:               "sql/by_same_im.sql",
      sql_by_same_rp_grouped:       "sql/by_same_rp_grouped.sql",
      sql_by_same_rp:               "sql/by_same_rp.sql",
      sql_by_score_grouped:         "sql/by_score_grouped.sql",
      sql_by_score:                 "sql/by_score.sql",
      sql_final:                    "sql/final.sql",
      sql_improve_direction:        "sql/improve_direction.sql",
      sql_improve_hand_grouped:     "sql/improve_hand_grouped.sql",
      sql_improve_hand:             "sql/improve_hand.sql",
      sql_improve_jumps:            "sql/improve_jumps.sql",
      sql_improve_outward:          "sql/improve_outward.sql",
      sql_improve_same_finger_both: "sql/improve_same_finger_both.sql",
      sql_improve_same_finger_rp:   "sql/improve_same_finger_rp.sql",
      sql_improve_score_grouped:    "sql/improve_score_grouped.sql",
      sql_improve_score:            "sql/improve_score.sql",
      sql_pre_slow_improve:         "sql/pre_slow_improve.sql",
    }

    # Embeds multiple files
    macro rucksack_embed_files
      {% for k in FILES %}
          rucksack("{{SRC_DIR.id}}/{{FILES[k].id}}")
      {% end %}
    end

    macro rucksack_embed_extra_files
      {% for k in EXTRA_FILES %}
          rucksack("{{EXTRA_FILES[k].id}}")
      {% end %}
    end

    #
    # Embeds one file from constants name
    macro rucksack_embed(name)
       rucksack("{{name.resolve}}")
    end

    #    macro rucksack_embed_dir(dir)
    #        {% for name in `find ./sql -type f`.split('\n') %}
    #           rucksack({{name}})
    #        {% end %}
    #    end
    #
    #    macro rucksack_embed_dir2(dir)
    #        {% for name in `find {{dir}} -type f`.split('\n') %}
    #           rucksack({{name}})
    #        {% end %}
    #    end
    #
    # To Make sure files get embedded
    def self.embed
      rucksack_embed_files
      rucksack_embed_extra_files
      # rucksack_embed_dir("./sql")
      # rucksack_embed_dir("./scripts")
    end

    # Returns filesystem path
    def self.user_file(name : Symbol) : String
      if FILES.has_key? name
        path = File.join(CONFIG_DIR, FILES[name])
        if File.file? path
          path
        else
          File.join(SRC_DIR, FILES[name])
        end
      elsif EXTRA_FILES.has_key? name
        EXTRA_FILES[name]
      else
        return ""
      end
    end

    # Returns rucksack path
    def self.embedded_file(name : Symbol) : String
      path = user_file(name)
      if path == ""
        raise "Embedded: bad symbol name %s" % name
      end
      return path
    end

    # Reads rucksack file into memory
    def self.read_rucksack(file : String) : String
      io = IO::Memory.new

      rucksack(file).read(io)
      io.rewind
      s = io.gets_to_end
      io.close
      return s
    end

    # Reads from filesystem first, else from rucksack
    def self.read(name : Symbol) : String
      if File.file? user_file(name)
        return File.read(user_file(name))
      else
        return read_rucksack(embedded_file(name))
      end
    end

    # Reads a value by key in a hash yaml config
    def self.read_value_in_user_yaml(name : Symbol, key : String) : YAML::Any
      filename = Embedded.user_file(name)
      result = Helper.parse_yaml(Embedded.read(name), context: filename)
      unless result.as_h.has_key? key
        Cleaner.exit_failure("key `#{key}` missing in `#{filename}`")
      end
      return result.as_h[key]
    end

    # Write user File (only if not present)
    def self.write(file : String) : Nil
      if File.file? file
        return
      else
        Helper.string_to_file(read_rucksack(file), file)
      end
    end

    # FIXME: maybe remove this?
    # Write user File (only if not present)
    def self.write(name : Symbol) : Nil
      if File.file? user_file(name)
        return
      else
        Helper.string_to_file(read(name), user_file(name))
      end
    end

    # Loads into Type (a key in a user yaml file)
    # FIXME: or maybe also non user, embeded? latter
    module YamlTo(T)
      def self.load(name : Symbol, key : String) : T
        Helper::YamlTo(T).load(
          Embedded.read_value_in_user_yaml(name, key).to_yaml,
          name.to_s)
      end
    end
  end
end
