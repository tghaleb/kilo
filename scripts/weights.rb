WEIGHTS = {
  hand: 0.8,
  positional_effort: 0.16,
  balance: 0.02,
  fingers: 0.02
}.freeze

HAND_WEIGHTS = {
  jumps: 0.5,
  outward: 0.3,
  same_finger_rp: 0.19,
  same_finger_im: 0.01
}.freeze

FINGERS_WEIGHTS = {
  indices: 0.2,
  rings: 0.3,
  pinkies: 0.5
}.freeze

# Points to add for each key match with qwerty layout
QWERTY_BONUS_POINT = 10

# These are excellent values that we would accept
# We use these values to make sure that values below these
# don't skew the results. Less that this value will still be
# scored at this level.
MIN_JUMPS = 10
MIN_OUTWARD = 10
MIN_SAME_FINGER = 40
MIN_SAME_FINGER_IM = 600

# Acceptable delta in balance
BALANCE_DELTA = 500

# Below this alternation level layout gets penalties
ALTERNATION_LEVEL = 7000

# Below this alternation level layout gets penalties
TRI_ALTERNATION_LEVEL = 3800


# Below this alternation level layout gets penalties
TEXT_DIRECTION_LEVEL = 5000

# Below this alternation level layout gets penalties
TRI_TEXT_DIRECTION_LEVEL = 1600


# Bellow this effort level layout gets penalties
EFFORT_LEVEL = 3500

FINGERS_LEVELS = {
  indices: 3800,
  indices_min: 2800, # minimum indices to get score
  pinkies: 1500,
  rings: 1800
}.freeze

# used for direction scoring (probably no need to edit this)
MAX_DIRECTION = 5500
MIN_DIRECTION = 4000

# This is an extra added to score
DIRECTION_WEIGHT = 0.2
