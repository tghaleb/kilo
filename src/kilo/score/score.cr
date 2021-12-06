module Kilo
  # Holds the Layout score
  class Score
    include DB::Serializable
    include Constants
    include Macros

    # To make sure we have the same instance variables as The table
    # columns we use a macro to build them from COL_NAMES.
    # Array like variables like row0, row1, etc. are also created\
    # that way
    macro build_properties
      {% for key, val in COL_NAMES %}
        {% if val.stringify == "Int16" %}
          @{{key}} : Int16 = 0
          property {{key}}
        {% elsif val.stringify == "Bool" %}
          @{{key}} : Bool = false
          property {{key}}
        {% elsif val.stringify == "String" %}
          @{{key}} : String = String.new
          property {{key}}
        {% elsif val.stringify == "Array(Int64)" %}
          {% for i in 0..COL_ARRAY_SIZES[key.symbolize] - 1 %}
            @{{key}}{{i}} : Int64 = 0
            property {{key}}{{i}}
          {% end %}
        {% elsif val.stringify == "Array(Int16)" %}
          {% for i in 0..COL_ARRAY_SIZES[key.symbolize] - 1 %}
            @{{key}}{{i}} : Int16 = 0
            property {{key}}{{i}}
          {% end %}
        {% end %}
      {% end %}
    end

    # This allows us to create setters/getters like rows, rows=
    # for array like variables row0, row1, etc.
    macro array_properties
     {% for key, val in COL_ARRAY_SIZES %}
 
      # Returns all items as a Tuple
      def {{key}}
          return {
      {% for c in 0..val - 1 %}
        @{{key}}{{c}},
      {% end %}
              }
      end
      
      def {{key}}=(a)
      {% for c in 0..val - 1 %}
       {% if COL_NAMES[key.symbolize].stringify == "Array(Int64)" %}
           @{{key}}{{c}} = a[{{c}}].to_i64 
        {% else %}
           @{{key}}{{c}} = a[{{c}}].to_i16 
        {% end %}

      {% end %}
      end
     {% end %}
    end

    # Returns the values method returning values to use with insert
    # statements (in table col order)
    macro build_values
      def values
        {
      {% for key, val in COL_NAMES %}
        {% if val.stringify.includes? "Array" %}
          *{{key}},
        {% else %}
          @{{key}},
        {% end %}
      {% end %}
        }
      end
    end

    # builds VAR NAMES used by to yaml
    macro build_var_names
      VAR_NAMES = [
      {% for key, val in COL_NAMES %}
        {% if val.stringify.includes? "Array" %}
          {% for i in 0..COL_ARRAY_SIZES[key.symbolize] - 1 %}
            "{{key}}{{i}}",
          {% end %}
        {% else %}
            "{{key}}",
        {% end %}
      {% end %}
      ]
    end

    build_properties
    array_properties
    build_values
    build_var_names

    # Required to be able to serialize with yaml
    def new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
      unless node.is_a?(YAML::Nodes::Mapping)
        node.raise "Expected mapping, not #{node.kind}"
      end

      YAML::Schema::Core.each(node) do |key, value|
        yield K.new(ctx, key), V.new(ctx, value)
      end
    end

    # Needed for serialization
    def initialize
    end

    # indices
    def indices : Int16
      return (@fingers3 + @fingers6)
    end

    def middles : Int16
      return (@fingers2 + @fingers7)
    end

    def rings : Int16
      return (@fingers1 + @fingers8)
    end

    def pinkies : Int16
      return (@fingers0 + @fingers9)
    end

    # To formatted string (colorized)
    def to_string
      return "" +
        "name: #{name}\n" +
        "layout: #{layout}\n" +
        build_scaled_string("score", @score) +
        build_scaled_string("positional_effort", @positional_effort) +
        build_scaled_string("alternation", @alternation) +
        build_scaled_string("text_direction", @text_direction) +
        "same_hand:\n" +
        build_scaled_string("  jumps", @jumps) +
        "  same_finger:\n" +
        build_scaled_string("    rp", @same_finger_rp) +
        build_scaled_string("    im", @same_finger_im) +
        "  adjacent-mrp:\n" +
        build_scaled_string("    inward", @inward) +
        build_scaled_string("    outward", @outward) +
        build_scaled_string("balance", @balance) +
        build_scaled_string("  rows", rows) +
        build_scaled_string("  fingers", fingers) +
        build_scaled_string("    indices", indices) +
        build_scaled_string("    middles", middles) +
        build_scaled_string("    rings", rings) +
        build_scaled_string("    pinkies", pinkies)
    end

    # Serializes into YAML.
    def to_yaml(yaml : YAML::Nodes::Builder) : Nil
      yaml.mapping(reference: self) do
        {% for name in VAR_NAMES %}
         {{name}}.to_yaml(yaml)
         @{{name.id}}.to_yaml(yaml)
        {% end %}
      end
    end

    # Serializes into JSON.
    def to_json(json : JSON::Builder) : Nil
      json.object do
        {% for name in VAR_NAMES %}
         json.field {{name}}.to_json_object_key do
              @{{name.id}}.to_json(json)
          end
        {% end %}
      end
    end

    # Used by to_string as a helper
    @[AlwaysInline]
    private def build_scaled_string(name, val : Int16)
      "#{name}: #{Score.format_scaled(val)}\n"
    end

    # Used by to_string as a helper
    @[AlwaysInline]
    private def build_scaled_string(name, val : Tuple)
      "#{name}: [#{val.map { |x| Score.format_scaled(x) }.join(", ")}]\n"
    end

    # Given characters returns (should we save the characters used?)
    # this is getting wasteful in terms of storage?
    def self.layout_to_string(chars)
      left, right = decoded
      puts Utils.lr_to_string(left, right, chars.sorted)
      puts Utils.lr_to_string_2(left, right, chars.sorted)
    end

    @[AlwaysInline]
    def self.format_float(n : Float64)
      return ("%2.2f" % n).colorize(:green)
    end

    # Places a decimal to number that is scaled with
    # DATA_SCALE to make it a percentage
    @[AlwaysInline]
    def self.format_scaled(x)
      s = x.to_s
      diff = s.size - 3
      if diff < 0
        s = ("0" * diff.abs) + s
      end
      return s.insert(-3, '.').colorize(:green)
    end
  end
end
