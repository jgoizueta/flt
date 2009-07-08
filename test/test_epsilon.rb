require File.dirname(__FILE__) + '/helper.rb'

class TestEpsilon < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_epsilon
    eps = DecNum.context.epsilon
    assert_equal((DecNum(1).next_plus - DecNum(1)), eps)
    assert_equal DecNum(1,1,1-DecNum.context.precision), eps
  end

  def test_epsilon_bin
    eps = BinFloat.context.epsilon
    assert_equal((BinFloat(1).next_plus - BinFloat(1)), eps)
    assert_equal BinFloat(1,1,1-BinFloat.context.precision), eps
  end

  def test_strict_epsilon
    [:up, :ceiling, :down, :floor, :half_up, :half_down, :half_even, :up05].each do |rounding|
      DecNum.context.rounding = rounding
      eps = DecNum.context.strict_epsilon
      eps_1 = DecNum(1)+eps
      r = eps.next_minus
      r_1 = DecNum(1)+r
      assert((eps_1 > DecNum(1)) && (r_1 == DecNum(1)), "Test strict epsilon for rounding #{rounding}")
      assert_equal(((DecNum(1)+eps)-DecNum(1)), DecNum.context.epsilon)
    end
  end

  def test_strict_epsilon_bin
    [:up, :ceiling, :down, :floor, :half_up, :half_down, :half_even].each do |rounding|
      BinFloat.context.rounding = rounding
      eps = BinFloat.context.strict_epsilon
      eps_1 = BinFloat(1)+eps
      r = eps.next_minus
      r_1 = BinFloat(1)+r
      assert((eps_1 > BinFloat(1)) && (r_1 == BinFloat(1)), "Test strict binary epsilon for rounding #{rounding}")
      assert_equal(((BinFloat(1)+eps)-BinFloat(1)), BinFloat.context.epsilon)
    end
  end

  def test_half_epsilon
    assert_equal DecNum.context.epsilon/2, DecNum.context.half_epsilon
  end

  def test_half_epsilon_bin
    assert_equal BinFloat.context.epsilon/2, BinFloat.context.half_epsilon
  end


end