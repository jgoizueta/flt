require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

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
    eps = BinNum.context.epsilon
    assert_equal((BinNum(1).next_plus - BinNum(1)), eps)
    assert_equal BinNum(1,1,1-BinNum.context.precision), eps
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
      BinNum.context.rounding = rounding
      eps = BinNum.context.strict_epsilon
      eps_1 = BinNum(1)+eps
      r = eps.next_minus
      r_1 = BinNum(1)+r
      assert((eps_1 > BinNum(1)) && (r_1 == BinNum(1)), "Test strict binary epsilon for rounding #{rounding}")
      assert_equal(((BinNum(1)+eps)-BinNum(1)), BinNum.context.epsilon)
    end
  end

  def test_half_epsilon
    assert_equal DecNum.context.epsilon/2, DecNum.context.half_epsilon
  end

  def test_half_epsilon_bin
    assert_equal BinNum.context.epsilon/2, BinNum.context.half_epsilon
  end


end