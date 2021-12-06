class BaseScore
  INT16_MAX = (2**15 - 1)
  INT16_MIN = -(2**15 - 1)
  QWERTY = "qwertyuiop[asdfghjkl;'zxcvbnm,./".split('')
  SCALE = 10_000
  HALF_SCALE = SCALE / 2

  # To make sure we don't have an overflow
  def scale(_score)
    if _score > INT16_MAX
      return INT16_MAX
    elsif _score < INT16_MIN
      return INT16_MIN
    end

    _score.to_i
  end

  def value_or_min(value, min)
    if value < min
      min
    else
      value
    end
  end
end


