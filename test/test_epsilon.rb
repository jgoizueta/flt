require File.dirname(__FILE__) + '/helper.rb'

class TestEpsilon < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_epsilon
    eps = Decimal.context.epsilon
    assert_equal((Decimal(1).next_plus - Decimal(1)), eps)
    assert_equal Decimal(1,1,1-Decimal.context.precision), eps
  end

  def test_strict_epsilon

    [:up, :ceiling, :down, :floor, :half_up, :half_down, :half_even, :up05].each do |rounding|
      Decimal.context.rounding = rounding
      eps = Decimal.context.strict_epsilon
      eps_1 = Decimal(1)+eps
      r = eps.next_minus
      r_1 = Decimal(1)+r
      assert((eps_1 > Decimal(1)) && (r_1 == Decimal(1)), "Test stritct epsilon for rounding #{rounding}")
      assert_equal(((Decimal(1)+eps)-Decimal(1)), Decimal.context.epsilon)
    end
  end

  def test_half_epsilon
    assert_equal Decimal.context.epsilon/2, Decimal.context.half_epsilon
  end


end