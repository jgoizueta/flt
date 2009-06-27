require File.dirname(__FILE__) + '/helper.rb'

class TestBinfloatConversion < Test::Unit::TestCase

  def setup
    initialize_context
  end

  def rand_in(min, max)
    n = max - min + 1
    rand(n) + min
  end

  def test_conversions
    BinFloat.context.precision = Float::MANT_DIG
    BinFloat.context.emin = Float::MIN_EXP-1
    BinFloat.context.emax = Float::MAX_EXP-1
    srand 12322
    [:half_even, :half_up, :half_down, :down, :up, :floor, :ceiling].each do |rounding|
      BinFloat.context.rounding = rounding
      1000.times do
        f = rand(2**Float::MANT_DIG)
        f = -f if rand(1)==0
        e = rand_in(Float::MIN_EXP-Float::MANT_DIG, Float::MAX_EXP-Float::MANT_DIG)
        x = Math.ldexp(f, e)

        txt = BinFloat(x).to_s
        y = BinFloat(txt).to_f
        assert_equal x, y
      end
    end
  end

end
