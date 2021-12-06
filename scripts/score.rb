#!/bin/env ruby

require 'yaml'
require 'sqlite3'
DIR = File.dirname(File.absolute_path(__FILE__))
require "#{DIR}/common_db.rb"
require "#{DIR}/weights.rb"
require "#{DIR}/base_score.rb"

unless ARGV.size == 1
  warn 'wrong argument count'
  exit 1
end

# FIXME: have tri in another scorer?

db = DB_Helper.new(ARGV[0])

class Score < BaseScore
  INT16_MAX = (2**15 - 1)
  INT16_MIN = -(2**15 - 1)
  QWERTY = "qwertyuiop[asdfghjkl;'zxcvbnm,./".split('')
  SCALE = 10_000

  def get_jumps(layouts)
    value_or_min(layouts['jumps'], MIN_JUMPS) * HAND_WEIGHTS[:jumps]
  end

  def get_outward(layouts)
    value_or_min(layouts['outward'], MIN_OUTWARD) * HAND_WEIGHTS[:outward]
  end

  def get_same_finger_rp(layouts)
    value_or_min(layouts['same_finger_rp'], MIN_SAME_FINGER) * HAND_WEIGHTS[:same_finger_rp]
  end

  def get_same_finger_im(layouts)
    value_or_min(layouts['same_finger_im'], MIN_SAME_FINGER_IM) * HAND_WEIGHTS[:same_finger_im]
  end


  def get_balance_delta(value)
    value_or_min(value, BALANCE_DELTA)
  end

  # The main scoring criteria: jumps, outward, same_finger_rp
  # edit HAND_WEIGHTS to change bias here
  def score_hand(layout)
    _sum = get_jumps(layout) + get_outward(layout) + get_same_finger_rp(layout) +
      + get_same_finger_im(layout)

    hand_score = scale((100.0 / _sum) * SCALE)
    (hand_score * WEIGHTS[:hand])
  end

 DIRECTION_FACTOR = SCALE / (MAX_DIRECTION - MIN_DIRECTION)

  # Less that TRI_TEXT_DIRECTION_LEVEL gets a penalty
  def score_tri_text_direction(value)
    return value - TRI_TEXT_DIRECTION_LEVEL
  end


  # Less that TEXT_DIRECTION_LEVEL gets a penalty
  def score_text_direction(value)
    return value - TEXT_DIRECTION_LEVEL

    # FIXME: remove this
    _score = 0
    if value > MAX_DIRECTION
      _score = SCALE
    elsif value > MIN_DIRECTION
      _score = (value - MIN_DIRECTION) * DIRECTION_FACTOR
    end
    return _score * DIRECTION_WEIGHT
  end

  # Less that ALTERNATION_LEVEL gets a penalty
  def score_alternation(value)
    value - ALTERNATION_LEVEL
  end

  # Less that TRI_ALTERNATION_LEVEL gets a penalty
  def score_tri_alternation(value)
    value - TRI_ALTERNATION_LEVEL
  end


  # Similarity with qwerty gets some points
  def score_qwerty(layout)
    _score = 0
    layout.split('').each_index do |i|
      _score += QWERTY_BONUS_POINT if layout[i] == QWERTY[i]
    end
    _score
  end

  # Penalties below EFFORT_LEVEL
  def score_positional_effort(value)
    positional_effort_score = (EFFORT_LEVEL.to_f / value) * SCALE
    positional_effort_score * WEIGHTS[:positional_effort]
  end

  # No points if not within BALANCE_DELTA
  def score_balance(value)
    # unless within range no points
    balance_score = 0

    delta = get_balance_delta((HALF_SCALE - value).abs)

    balance_score = (BALANCE_DELTA.to_f / delta) * SCALE if delta == BALANCE_DELTA

    balance_score * WEIGHTS[:balance]
  end

  def get_fingers(value, name)
    (FINGERS_LEVELS[name].to_f / value) * SCALE * FINGERS_WEIGHTS[name]
  end

  def score_fingers(layout)
    _sum = 0

    _indices = layout['fingers3'] + layout['fingers6']
    _sum += get_fingers(layout['fingers3'] + layout['fingers6'], :indices) if _indices > FINGERS_LEVELS[:indices_min]
    _sum += get_fingers(layout['fingers0'] + layout['fingers9'], :pinkies)
    _sum += get_fingers(layout['fingers1'] + layout['fingers8'], :rings)

    _sum * WEIGHTS[:fingers]
  end

  def score(layout)
    _score = 0
    _score += score_hand(layout)
    _score += score_alternation(layout['alternation'])
    _score += score_text_direction(layout['text_direction'])
    _score += score_positional_effort(layout['positional_effort'])
    _score += score_balance(layout['balance'])
    _score += score_qwerty(layout['layout'])
    _score += score_fingers(layout)
    _score += score_text_direction(layout['text_direction'])
#    _score += score_tri_alternation(layout['tri_alternation'])
#    _score += score_tri_text_direction(layout['tri_text_direction'])

    scale(_score)
  end
end

scorer = Score.new

begin
  db.update do |row|
    row['score'] = scorer.score(row)
  end
rescue => e
  puts e.message
  exit 1
end
exit 0
