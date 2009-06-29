require File.dirname(__FILE__) + '/helper.rb'

class TestBinfloatConversion < Test::Unit::TestCase

  def setup
    initialize_context
  end

  def test_conversions
    float_emulation_context
    srand 12322
    [:half_even, :half_up, :half_down, :down, :up, :floor, :ceiling].each do |rounding|
      BinFloat.context.rounding = rounding
      1000.times do
        x = random_float
        txt = BinFloat(x).to_s
        y = BinFloat(txt).to_f
        assert_equal x, y
      end
    end
  end

end
