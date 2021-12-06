require "html"

module Kilo
  # TODO:
  # - refactor and remove some repetition in code
  # possibly cache the part that doesn't change

  class Image
    include Constants

    IMG_W        = 900
    IMG_H        = 350
    BG_COLOR     = "#888A7D"
    STROKE_COLOR = "#666666"
    NAME_COLOR   = "#3D5060"
    L3_COLOR     = "blue"
    L4_COLOR     = "blue"
    HEAT_COLOR   = "red"

    KEY_ID          = "key"
    CTRL_KEY_ID     = "ctrl"
    CTRL_KEY_FACTOR = 1.4
    KEY_W           =  50
    KEY_H           =  50
    KEY_R           =  10
    KEY_SP          =   2

    KEY_COLOR = "#D8D9C5"
    CTL_COLOR = "#EBEDD7"

    KB_MARGIN_TOP  = 50
    KB_MARGIN_LEFT = 50

    RTRN1_FACTOR = 1.5

    L_LETTER_SIZE = 14
    S_LETTER_SIZE = 14
    NAME_SIZE     = 22

    SPECIAL_KEYS = {
      Key::TAB  => 1.6,
      Key::CAPS => 1.9,
      Key::BKSP => 2.1,
      Key::LFSH => 2.6,
      Key::RTSH => 2.6,
      Key::SPCE => 5.55,
      Key::RTRN => 1.2,
      Key::LCTL => 1.4,
      Key::RCTL => 1.4,
      Key::LALT => 1.4,
      Key::RALT => 1.4,
      Key::LWIN => 1.4,
      Key::RWIN => 1.4,
      Key::COMP => 1.4,
    }

    def svg(map : MapConfig, heat = false) : String
      Celestine.draw do |ctx|
        ctx.height_units = ctx.width_units = "px"
        ctx.height = IMG_H
        ctx.width = IMG_W
        ctx.view_box = {x: 0, y: 0, w: IMG_W, h: IMG_H}

        create_background(ctx)
        create_key(ctx)
        create_key(ctx, "red")
        create_ctrl_key(ctx)

        place_keys(ctx, map[:map], map[:heat], heat)

        place_text(ctx, col: 12, row: 5, id: "label", text: map[:name],
          color: NAME_COLOR, size: NAME_SIZE)
      end
    end

    # Creates background
    private def create_background(ctx)
      id = "background"
      ctx.rectangle(define: true) do |r|
        r.id = id
        r.width = IMG_W
        r.height = IMG_H
        r.fill = BG_COLOR
        r
      end
      ctx.use(id) do |r|
        r.x = 0
        r.y = 0
        r
      end
    end

    # creates a regular key
    private def create_key(ctx, color = KEY_COLOR)
      ctx.rectangle(define: true) do |r|
        if color != KEY_COLOR
          r.id = KEY_ID + color
        else
          r.id = KEY_ID
        end
        r.width = KEY_W
        r.height = KEY_H
        r.radius_x = KEY_R
        r.fill = color
        r.stroke = STROKE_COLOR
        r.stroke_width = 1
        r.opacity = 1
        r
      end
    end

    private def create_ctrl_key(ctx)
      ctx.rectangle(define: true) do |r|
        r.id = CTRL_KEY_ID
        r.width = KEY_W * CTRL_KEY_FACTOR
        r.height = KEY_H
        r.radius_x = KEY_R
        r.fill = CTL_COLOR
        r.stroke = STROKE_COLOR
        r.stroke_width = 1
        r.opacity = 1
        r
      end
    end

    private def create_special_key(ctx, id, factor)
      ctx.rectangle(define: true) do |r|
        r.id = id
        r.width = KEY_W * factor
        r.height = KEY_H
        r.radius_x = KEY_R
        r.fill = CTL_COLOR
        r.stroke = STROKE_COLOR
        r.stroke_width = 1
        r.opacity = 1
        r
      end
    end

    @[AlwaysInline]
    def heat_value(val : Int64) : Float64
      (val * 5)/DATA_SCALE
    end

    def place_keys(ctx, map, heat_map, heat)
      last_row = 0
      col = 0
      shift = 0

      kb_rows = ProjectConfig.instance.config[:kb_rows]
      kb_rows.each_key do |key|
        row = kb_rows[key]
        if row.value != last_row
          col = 0
          shift = 0
        end
        if SPECIAL_KEYS.has_key? key
          create_special_key(ctx, key.to_s, factor: SPECIAL_KEYS[key])
          place_special_key(ctx, key: key, col: col, row: row, shift: shift, data: map[key])
          shift += (SPECIAL_KEYS[key] * KEY_W) - KEY_W
        else
          if heat_map.empty?
            place_regular_key(ctx, key: key, col: col, row: row,
              shift: shift, data: map[key], h_value: 0, heat: heat)
          else
            place_regular_key(ctx, key: key, col: col, row: row,
              shift: shift, data: map[key], h_value: heat_value(heat_map[key]), heat: heat)
          end
          if key == Key::AD12
            col += 1
            # FIXME: return correction?
            create_special_key(ctx, key.to_s + "1", factor: RTRN1_FACTOR)
            place_key(ctx, col: col, row: row.value, id: key.to_s + "1", shift: shift)
          end
        end
        last_row = row.value
        col += 1
      end

      ret_key(ctx)
    end

    private def place_special_key(ctx, key, col, row, shift, data)
      place_key(ctx, col: col, row: row.value, id: key.to_s, shift: shift)
      # FIXME where to place?
      return if data.size == 0
      if data.size == 1
        place_text(ctx, col: col, row: row.value, id: key.to_s + "x", text: data[0], shift: shift)
      elsif data.size >= 2
        place_text(ctx, col: col, row: row.value, id: key.to_s + "x",
          text: data[0], shift: shift, placement: :down)

        place_text(ctx, col: col, row: row.value, id: key.to_s + "x2",
          text: data[1], shift: shift, placement: :up)
      end
    end

    private def place_regular_key(ctx, key, col, row, shift, data,
                                  h_value, heat)
      place_key(ctx, col: col, row: row.value, shift: shift)

      if heat
        place_key(
          ctx, col: col, row: row.value,
          id: KEY_ID + HEAT_COLOR, shift: shift, opacity: h_value)
      end

      # FIXME: loop over data and place down up down-right up-right and
      # stop at 4 levels or stop at 2 cleaner?
      return if data.size == 0
      if data.size > 0
        place_text(ctx, col: col, row: row.value, id: key.to_s + "x",
          text: data[0], shift: shift, placement: :down)
      end
      if data.size > 1
        place_text(ctx, col: col, row: row.value, id: key.to_s + "x2",
          text: data[1], shift: shift, placement: :up)
      end

      if data.size > 2
        place_text(ctx, col: col, row: row.value, id: key.to_s + "x3",
          text: data[2], shift: shift, placement: :down_right, color: L3_COLOR)
      end
      if data.size > 3
        place_text(ctx, col: col, row: row.value, id: key.to_s + "x4",
          text: data[3], shift: shift, placement: :up_right, color: L4_COLOR)
      end
    end

    # private def place_key(ctx, col, row, trans_x)
    private def place_key(ctx, col, row, id = KEY_ID, shift = 0, opacity = 1)
      ctx.use(id) do |r|
        r.x = KB_MARGIN_LEFT + ((KEY_W + KEY_SP) * (col)) + shift
        r.y = KB_MARGIN_TOP + (KEY_H + KEY_SP) * row
        r.opacity = opacity
        trans_x = 0
        r.transform do |t|
          t.translate(trans_x, 0)
          t
        end
        r
      end
    end

    private def define_text(ctx, text, id, color = "black", weight = "normal", size = L_LETTER_SIZE)
      ctx.text(define: true) do |r|
        r.id = id

        # NOTE we have to escape we don't know what we have
        r.text = HTML.escape(text)

        r.fill = color
        r.font_weight = weight
        r.font_size = size
        r.opacity = 1
        r
      end
    end

    # should we create and place all in one?
    private def place_text(ctx, id, col, text, shift = 0, row = 1,
                           placement = :middle, color = "black", size = L_LETTER_SIZE)
      define_text(ctx, text, id, color: color, size: size)

      ctx.use(id) do |r|
        correction_x = (KEY_W*0.2)
        correction_y = KEY_H*0.4

        if placement == :middle
          correction_x = (KEY_W*0.1)
          correction_y = KEY_H*0.6
        end

        if placement == :down_right
          correction_x = (KEY_W*0.65)
          correction_y = KEY_H*0.8
        end

        if placement == :up_right
          correction_x = (KEY_W*0.65)
        end

        r.x = KB_MARGIN_LEFT + ((KEY_W + KEY_SP) * col) + correction_x + shift

        if placement == :down
          correction_y = KEY_H*0.8
        end
        r.y = KB_MARGIN_TOP + ((KEY_H + KEY_SP) * row) + correction_y
        r
      end
    end

    #    # Creates the return key with 2 keys and an overlay
    private def ret_key(ctx)
      ctx.rectangle(define: true) do |r|
        r.id = "reti"
        r.width = KEY_W + 8.5
        r.height = KEY_H/2
        r.fill = CTL_COLOR
        r.opacity = 1
        r
      end
      ctx.use("reti") do |r|
        r.x = KB_MARGIN_LEFT + KEY_W*14 + 22
        r.y = KB_MARGIN_TOP + (KEY_H + KEY_SP) + 40
        r
      end
    end
    #
  end
end
