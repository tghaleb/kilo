module Kilo
  macro class_getter(name)
      def self.{{name}}
          return @@{{name}}
      end
  end

  module Macros
    # Adds mappings for instance variables for serializing with yaml
    # to be used inside to_yaml
    #
    # Example:
    #
    # def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    #   add_yaml_mappings ["data", "length", "name"]
    # end
    macro add_yaml_mappings(names)
        {% for name in names %}
         {{name}}.to_yaml(yaml)
         @{{name.id}}.to_yaml(yaml)
        {% end %}
    end
  end
end
