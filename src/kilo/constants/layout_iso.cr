module Kilo
  module Constants
    KEY_COUNT = 61

    enum Hand
      LEFT
      RIGHT
      NONE
    end

    enum Row
      R0
      R1
      R2
      R3
      R4
      NONE
    end
    enum Column
      C00
      C01
      C02
      C03
      C04
      C05
      C06
      C07
      C08
      C09
      C10
      C11
      C12
      C13
      NONE
    end

    enum Finger
      LF5
      LF4
      LF3
      LF2
      LF1
      RF1
      RF2
      RF3
      RF4
      RF5
      NONE
    end

    enum Key
      TLDE
      AE01
      AE02
      AE03
      AE04
      AE05
      AE06
      AE07
      AE08
      AE09
      AE10
      AE11
      AE12
      BKSP

      TAB
      AD01
      AD02
      AD03
      AD04
      AD05
      AD06
      AD07
      AD08
      AD09
      AD10
      AD11
      AD12

      CAPS
      AC01
      AC02
      AC03
      AC04
      AC05
      AC06
      AC07
      AC08
      AC09
      AC10
      AC11
      BKSL
      RTRN

      LFSH
      AB01
      AB02
      AB03
      AB04
      AB05
      AB06
      AB07
      AB08
      AB09
      AB10
      RTSH

      LCTL
      LWIN
      LALT
      SPCE
      RALT
      RWIN
      COMP
      RCTL

      NONE
    end

    FINGER_HAND = {
      Finger::LF5 => Hand::LEFT,
      Finger::LF4 => Hand::LEFT,
      Finger::LF3 => Hand::LEFT,
      Finger::LF2 => Hand::LEFT,
      Finger::LF1 => Hand::LEFT,
      Finger::RF1 => Hand::RIGHT,
      Finger::RF2 => Hand::RIGHT,
      Finger::RF3 => Hand::RIGHT,
      Finger::RF4 => Hand::RIGHT,
      Finger::RF5 => Hand::RIGHT,
    }

    # The main 32 keys
    KEYS_32 = [
      Key::AD01,
      Key::AD02,
      Key::AD03,
      Key::AD04,
      Key::AD05,
      Key::AD06,
      Key::AD07,
      Key::AD08,
      Key::AD09,
      Key::AD10,
      Key::AD11,

      Key::AC01,
      Key::AC02,
      Key::AC03,
      Key::AC04,
      Key::AC05,
      Key::AC06,
      Key::AC07,
      Key::AC08,
      Key::AC09,
      Key::AC10,
      Key::AC11,

      Key::AB01,
      Key::AB02,
      Key::AB03,
      Key::AB04,
      Key::AB05,
      Key::AB06,
      Key::AB07,
      Key::AB08,
      Key::AB09,
      Key::AB10,
    ]

    # used as a lookup
    FINGER_POSITION = [4, 3, 2, 1, 0, 5, 6, 7, 8, 9]

    # used with FINGER position
    HAND_FINGER_OFFSET = [0, 5]
  end
end
