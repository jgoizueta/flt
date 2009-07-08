require File.dirname(__FILE__) + '/helper.rb'

class TestBinfloatConversion < Test::Unit::TestCase

  def setup
    initialize_context
  end

  def test_conversions
    float_emulation_context
    srand 12322
    [:half_even, :half_up, :half_down, :down, :up, :floor, :ceiling].each do |rounding|
      BinNum.context.rounding = rounding
      1000.times do
        x = random_float
        txt = BinNum(x).to_s
        y = BinNum(txt).to_f
        assert_equal x, y
      end
    end
  end

end
