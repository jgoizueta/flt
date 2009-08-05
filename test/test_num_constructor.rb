require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestNumConstructor < Test::Unit::TestCase


  def setup
    initialize_context
    DecNum.context.precision = 28
    @dprec5 = DecNum::Context(:precision=>5)
    @bprec5 = BinNum::Context(:precision=>5)
  end

  def test_direct
    assert_equal [1, 1234, -2], DecNum(+1, 1234, -2).split
    assert_equal [1, 1234, -2],  DecNum(+1, 1234, -2, @dprec5).split
    assert_equal [1, 1234, -2],  DecNum(+1, 1234, -2, :precision=>2).split
    assert_equal [1, 1234, -2],  DecNum(+1, 1234, -2, nil).split

    assert_equal [1, 1234, -2],  BinNum(+1, 1234, -2).split
    assert_equal [1, 1234, -2],  BinNum(+1, 1234, -2, @bprec5).split
    assert_equal [1, 1234, -2],  BinNum(+1, 1234, -2, :precision=>2).split
    assert_equal [1, 1234, -2],  BinNum(+1, 1234, -2, nil).split
    assert_equal [1, 1234, -2],  BinNum(+1, 1234, -2, :xxx=>3).split
  end

  def test_conversion
    assert_equal [1, 3333333333333333333333333333, -28], DecNum(Rational(1,3)).split
    assert_equal [1, 33333, -5], DecNum(Rational(1,3), @dprec5).split
    assert_equal [1, 33333, -5], DecNum(Rational(1,3), :precision=>5).split
    assert_equal [1, 3333333333333333333333333333, -28], DecNum(Rational(1,3), nil).split

    assert_equal [1, 6004799503160661, -54], BinNum(Rational(1,3)).split
    assert_equal [1, 21, -6], BinNum(Rational(1,3), @bprec5).split
    assert_equal [1, 21, -6], BinNum(Rational(1,3), :precision=>5).split
    assert_equal [1, 6004799503160661, -54], BinNum(Rational(1,3), nil).split
  end

  def test_literal_free
    assert_equal [1, 1234567, -8], DecNum('1.234567E-2', :free).split
    assert_equal [1, 1234567, -8], DecNum('1.234567E-2', :free, :precision=>5).split
    assert_equal [1, 1, -1], DecNum('0.1', :free).split
    assert_equal [1, 1000, -4], DecNum('0.1000', :free).split
    assert_equal [1, 1, -1],  DecNum('0.1',:short).split
    assert_equal [1, 1000, -4], DecNum('0.1000',:short).split

    assert_equal [1, 1, -3], BinNum('0.1E-2', :free, :base=>2).split
    assert_equal [1, 1, -1], BinNum('0.1', :free, :base=>2).split
    assert_equal [1, 8, -4], BinNum('0.1000', :free, :base=>2).split
    assert_equal [1, 1, -1], BinNum('0.1',:short, :base=>2).split
    assert_equal [1, 8, -4], BinNum('0.1000',:short, :base=>2).split
  end

  def test_literal_free_base

    assert_equal [1, 12, -2], DecNum('0.1E-2', :free, :base=>2).split
    assert_equal [1, 13, -2], DecNum('0.1E-2', :free, :base=>2, :rounding=>:half_up).split
    assert_equal [1, 1250, -4], DecNum('0.1000000E-2', :free, :base=>2).split
    assert_equal [1, 125, -3], DecNum('0.1000000E-2', :short, :base=>2).split

    assert_equal [1, 26, -8], BinNum('0.1', :free).split
    assert_equal [1, 13107, -17], BinNum('0.1000', :free).split
    assert_equal [1, 1, -3], BinNum('0.1',:short).split
    assert_equal [1, 1639, -14], BinNum('0.1000',:short).split
  end

  def test_fixed

    assert_equal [1, 1000000000000000000000000000, -28], DecNum('0.1',:fixed).split
    assert_equal [1, 1000000000000000000000000000, -28], DecNum('0.1000',:fixed).split
    assert_equal [1, 10000, -5], DecNum('0.1',:fixed,:precision=>5).split
    assert_equal [1, 10000, -5], DecNum('0.1000',:fixed,:precision=>5).split
    assert_equal [1, 10000, -5], DecNum('0.1',:fixed,@dprec5).split
    assert_equal [1, 10000, -5], DecNum('0.1000',:fixed,@dprec5).split
    DecNum.context(:precision=>5) do
      assert_equal [1, 10000, -5], DecNum('0.1',:fixed).split
      assert_equal [1, 10000, -5], DecNum('0.1000',:fixed).split
    end

    assert_equal [1, 4503599627370496, -53], BinNum('0.1',:fixed,:base=>2).split
    assert_equal [1, 4503599627370496, -53], BinNum('0.1000',:fixed,:base=>2).split
    assert_equal [1, 16, -5], BinNum('0.1',:fixed,:precision=>5,:base=>2).split
    assert_equal [1, 16, -5], BinNum('0.1000',:fixed,:precision=>5,:base=>2).split
    context = BinNum::Context(:precision=>5)
    assert_equal [1, 16, -5], BinNum('0.1',:fixed,context,:base=>2).split
    assert_equal [1, 16, -5], BinNum('0.1000',:fixed,context,:base=>2).split
    BinNum.context(:precision=>5) do
      assert_equal [1, 16, -5], BinNum('0.1',:fixed,:base=>2).split
      assert_equal [1, 16, -5], BinNum('0.1000',:fixed,:base=>2).split
    end
  end

  def test_fixed_base
    assert_equal [1, 7205759403792794, -56], BinNum('0.1',:fixed).split
    assert_equal [1, 7205759403792794, -56], BinNum('0.1000',:fixed).split
    assert_equal [1, 26, -8], BinNum('0.1',:fixed,:precision=>5).split
    assert_equal [1, 26, -8], BinNum('0.1000',:fixed,:precision=>5).split
    assert_equal [1, 26, -8], BinNum('0.1',:fixed,@bprec5).split
    assert_equal [1, 26, -8], BinNum('0.1000',:fixed,@bprec5).split
    BinNum.context(:precision=>5) do
      assert_equal [1, 26, -8], BinNum('0.1',:fixed).split
      assert_equal [1, 26, -8], BinNum('0.1000',:fixed).split
    end

    assert_equal [1, 5000000000000000000000000000, -28], DecNum('0.1',:fixed,:base=>2).split
    assert_equal [1, 5000000000000000000000000000, -28], DecNum('0.1000',:fixed,:base=>2).split
    assert_equal [1, 50000, -5], DecNum('0.1',:fixed,:precision=>5,:base=>2).split
    assert_equal [1, 50000, -5], DecNum('0.1000',:fixed,:precision=>5,:base=>2).split
    assert_equal [1, 50000, -5], DecNum('0.1',:fixed,@dprec5,:base=>2).split
    assert_equal [1, 50000, -5], DecNum('0.1000',:fixed,@dprec5,:base=>2).split
    DecNum.context(:precision=>5) do
      assert_equal [1, 50000, -5], DecNum('0.1',:fixed,:base=>2).split
      assert_equal [1, 50000, -5], DecNum('0.1000',:fixed,:base=>2).split
    end

  end

  def test_default
    assert_equal [1, 1234567, -8], DecNum('1.234567E-2').split
    assert_equal [1, 1234567, -8], DecNum('1.234567E-2', :precision=>5).split
    assert_equal [1, 1, -1], DecNum('0.1').split
    assert_equal [1, 1000, -4], DecNum('0.1000').split
    assert_equal [1, 1, -3], BinNum('0.1E-2', :base=>2).split
    assert_equal [1, 1, -1], BinNum('0.1', :base=>2).split
    assert_equal [1, 8, -4], BinNum('0.1000', :base=>2).split
    # base conversion
    assert_equal [1, 12, -2], DecNum('0.1E-2', :base=>2, :rounding=>:half_even).split
    assert_equal [1, 13, -2], DecNum('0.1E-2', :base=>2, :rounding=>:half_up).split
    assert_equal [1, 26, -8], BinNum('0.1').split
    assert_equal [1, 13107, -17], BinNum('0.1000').split
  end


end
