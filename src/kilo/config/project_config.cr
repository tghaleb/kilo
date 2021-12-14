module Kilo
  # A Singlton class that holds project config, reads config during
  # initialization and merges config with default config. If no
  # config files found, returns default config values.
  # Should work even if config/ directory is empty
  class ProjectConfig < Singleton
    include Constants

    include Comandante

    @config : NamedTuple(
      kb_weights: KBWeightsConfType,
      kb_fingers: KBFingersConfType,
      kb_rows: KBRowsConfType,
      kb_columns: KBColumnsConfType,
      xkb_list: XKBListType,
      corpus: String,
      ltr: Bool,
      typing_word_limit: Int32,
      short_typing_word_limit: Int32,
      balance_delta: Float64,
      alternation_min: Float64,
      alternation_max: Float64,
      characters: String,
      left_to_32: SideTo32Type,
      right_to_32: SideTo32Type,
      improve_config: ImproveConfigType)

    getter config

    # Returns merged config
    private def get_config
      filename = Embedded.user_file(:config)

      config_user = Embedded.read(:config)
      config_default = Embedded.read_rucksack(Embedded.embedded_file(:config))

      result = Helper.parse_yaml(config_default, context: filename)

      # if config_user != config_default
      # result = result.as_h.merge(Helper.parse_yaml(config_user,
      #  context: filename).as_h)
      # end

      if result["characters"].to_s.size != 32
        Cleaner.exit_failure("config characters key needs 32 characters")
      end

      return result
    end

    # These lookups are generated once (index-side -> index-keys_32)
    def self.set_hand_keys_32(hand, kb_fingers) : SideTo32Type
      result = SideTo32Type.new
      KEYS_32.each_with_index do |k, i|
        if FINGER_HAND[kb_fingers[k]] == hand
          result << i
        end
      end
      return result
    end

    def self.get_improve_config(hash)
      Helper::YamlTo(ImproveConfigType).load(hash.to_yaml)
    end

    private def initialize
      tmp_conf = get_config

      kb_fingers = Embedded::YamlTo(KBFingersConfType).load(:kb_fingers, :kb_fingers.to_s)

      @config = {
        # not the most efficient but simple and safe
        kb_weights: Embedded::YamlTo(KBWeightsConfType).load(
          :kb_weights, :kb_weights.to_s),
        kb_fingers: kb_fingers,
        kb_rows:    Embedded::YamlTo(KBRowsConfType).load(:kb_rows, :kb_rows.to_s),
        kb_columns: Embedded::YamlTo(KBColumnsConfType).load(:kb_columns,
          :kb_columns.to_s),
        xkb_list:                Embedded::YamlTo(XKBListType).load(:xkb_list, :xkb_list.to_s),
        corpus:                  tmp_conf["corpus"].as_s,
        improve_config:          ProjectConfig.get_improve_config(tmp_conf["improve_config"]),
        balance_delta:           tmp_conf["balance_delta"].as_f,
        alternation_min:         tmp_conf["alternation_min"].as_f,
        alternation_max:         tmp_conf["alternation_max"].as_f,
        characters:              tmp_conf["characters"].as_s,
        typing_word_limit:       tmp_conf["typing_word_limit"].as_i,
        short_typing_word_limit: tmp_conf["short_typing_word_limit"].as_i,
        ltr:                     tmp_conf["ltr"].as_bool,
        left_to_32:              ProjectConfig.set_hand_keys_32(Hand::LEFT, kb_fingers),
        right_to_32:             ProjectConfig.set_hand_keys_32(Hand::RIGHT, kb_fingers),
      }
    end
  end
end
