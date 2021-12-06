require "./spec_helper"
require "process"

describe Kilo::BalanceFilter do
  it "pass() should work and return same like score_layout" do
    filter = QWERTY.split("")
    characters, bigrams = freq_hash_data(filter)

    balance_score = BalanceFilter.new(
      characters: characters,
    )

    layout_score = LayoutScore.new(
      characters: characters.clone,
      bigrams: bigrams,
    )

    left, right = Kilo::Utils.string_to_lr(QWERTY, characters)
    balance_score.pass? Utils.left_array_to_u32(left)

    layout_score.scan(left, right, QWERTY, "qwerty")

    balance_score.score.should eq(layout_score.score.balance)
  end
end
