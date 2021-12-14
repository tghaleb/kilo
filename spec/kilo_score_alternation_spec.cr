require "./spec_helper"
require "process"
include Kilo

# this one requires .kilo/corpus
describe Kilo::AlternationFilter do
  it "score() should retun same as LayoutScore" do
    filter = QWERTY.split("")
    characters, bigrams = freq_hash_data(filter)

    alternation_score = AlternationFilter.new(
      characters: characters,
      bigrams: bigrams,
      min: 0
    )

    layout_score = LayoutScore.new(
      characters: characters.clone,
      bigrams: bigrams,
    )

    left, right = Kilo::Utils.string_to_lr(QWERTY, characters)
    alternation_score.pass? Utils.left_array_to_u32(left)

    layout_score.scan(left, right, "qwerty")

    alternation_score.score.should eq(layout_score.score.alternation)
  end
end
