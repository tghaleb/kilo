module Kilo
  module Constants
    TBL_LAYOUTS = "layouts"

    COL_NAMES = {
      layout:            String,
      name:              String,
      score:             Int16,
      alternation:       Int16,
      positional_effort: Int16,
      balance:           Int16,
      jumps:             Int16,
      same_finger_rp:    Int16,
      same_finger_im:    Int16,
      inward:            Int16,
      outward:           Int16,
      text_direction:    Int16,
      rows:              Array(Int16),
      fingers:           Array(Int16),
    }

    COL_ARRAY_SIZES = {
      rows:    3,
      fingers: 10,
    }

    macro build_table_sql
      SQL_TBL_LAYOUTS_CREATE = "CREATE TABLE IF NOT EXISTS #{TBL_LAYOUTS} (
      {% for key, val in COL_NAMES %}
        {% if val.stringify == "Int16" %}
        {{key}} INTEGER NOT NULL,
        {% elsif val.stringify == "Bool" %}
        {{key}} INT,
        {% elsif val.stringify == "String" %}
        {{key}} TEXT,
        {% elsif val.stringify == "Array(Int64)" %}
          {% for i in 0..COL_ARRAY_SIZES[key.symbolize] - 1 %}
            {{key}}{{i}} INTEGER NOT NULL,
          {% end %}
        {% elsif val.stringify == "Array(Int16)" %}
          {% for i in 0..COL_ARRAY_SIZES[key.symbolize] - 1 %}
            {{key}}{{i}} INTEGER NOT NULL,
          {% end %}
        {% end %}
      {% end %}
      PRIMARY KEY (layout),
      );
      ".gsub(/\s+/," ").sub(", )", ")")
    end

    macro build_insert_sql
      SQL_TBL_LAYOUTS_INSERT = "INSERT OR IGNORE INTO #{TBL_LAYOUTS} (
      {% num = 0 %}
      {% for key, val in COL_NAMES %}
        {% if val.stringify.includes? "Array(" %}
          {% for i in 0..COL_ARRAY_SIZES[key.symbolize] - 1 %}
            {{key}}{{i}},
            {% num += 1 %}
          {% end %}
       {% else %}
            {{key}},
            {% num += 1 %}
        {% end %}
      {% end %}
      )".gsub(/\s+/," ").sub(", )", ")") +
      " VALUES (" + ("?,"*{{num}}).sub(/,$/, "") + ")"
    end

    build_table_sql
    build_insert_sql

    SQL_TBL_LAYOUTS_DROP = "DROP TABLE IF EXISTS #{TBL_LAYOUTS}"
    DEFAULT_SELECT       = "select * from #{TBL_LAYOUTS} order by alternation desc"
    SELECT_ALL           = "select * from #{TBL_LAYOUTS};"
    SCORE_COL            = "score"
    UPDATE_SCORE_SQL     = "UPDATE #{TBL_LAYOUTS} set #{SCORE_COL} = (?) WHERE layout = (?)"
  end
end
