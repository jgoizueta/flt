require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))


class TestExact < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_binary_to_decimal_formatter
    Flt::BinNum.context = Flt::BinNum::IEEEDoubleContext
    formatter = Flt::Support::Formatter.new(BinNum.radix, BinNum.context.etiny, 10)

    x = BinNum(0.1)
    s, f, e = x.split

    digits = formatter.format(x, f, e, :half_even, BinNum.context.precision, false)
    assert_equal [1], digits

    digits = formatter.format(x, f, e, :half_even, BinNum.context.precision, true)
    assert_equal [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], digits
    assert_equal :hi, formatter.round_up

    digits = formatter.format(x, f, e, :up, BinNum.context.precision, false)
    assert_equal [1], digits

    assert_raise(Flt::Support::InfiniteLoopError) { formatter.format(x, f, e, :up, BinNum.context.precision, true) }

    digits = formatter.format(x, f, e, :down, BinNum.context.precision, false)
    assert_equal [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
                 digits

    digits = formatter.format(x, f, e, :down, BinNum.context.precision, true)
    assert_equal [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 5, 1, 1, 1, 5, 1, 2, 3, 1, 2, 5, 7, 8, 2, 7, 0, 2, 1, 1, 8, 1, 5, 8, 3, 4, 0, 4, 5, 4, 1, 0, 1, 5, 6, 2, 5],
                 digits

    x = BinNum(0.5)
    s, f, e = x.split

    digits = formatter.format(x, f, e, :half_even, BinNum.context.precision, false)
    assert_equal [5], digits

    digits = formatter.format(x, f, e, :half_even, BinNum.context.precision, true)
    assert_equal [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], digits
    refute formatter.round_up

    digits = formatter.format(x, f, e, :up, BinNum.context.precision, false)
    assert_equal [5], digits

    assert_raise(Flt::Support::InfiniteLoopError) { formatter.format(x, f, e, :up, BinNum.context.precision, true) }

    digits = formatter.format(x, f, e, :down, BinNum.context.precision, false)
    assert_equal [5], digits

    digits = formatter.format(x, f, e, :down, BinNum.context.precision, true)
    assert_equal [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], digits
    refute formatter.round_up
  end

def test_binary_to_repeating_decimal_formatter
    Flt::BinNum.context = Flt::BinNum::IEEEDoubleContext
    formatter = Flt::Support::Formatter.new(BinNum.radix, BinNum.context.etiny, 10, :raise_on_repeat => false)

    x = BinNum(0.1)
    s, f, e = x.split

    digits = formatter.format(x, f, e, :half_even, BinNum.context.precision, false)
    assert_equal [1], digits

    digits = formatter.format(x, f, e, :half_even, BinNum.context.precision, true)
    assert_equal [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], digits
    assert_equal :hi, formatter.round_up
    refute formatter.repeat

    digits = formatter.format(x, f, e, :up, BinNum.context.precision, false)
    assert_equal [1], digits

    assert_nothing_raised { formatter.format(x, f, e, :up, BinNum.context.precision, true) }
    digits = formatter.format(x, f, e, :up, BinNum.context.precision, true)
    assert_equal [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 5, 1, 1, 1, 5, 1, 2, 3, 1, 2, 5, 7, 8, 2, 7, 0, 2, 1, 1, 8, 1, 5, 8, 3, 4, 0, 4, 5, 4, 1, 0, 1, 5, 6, 2, 5],
                 digits
    refute formatter.round_up
    assert_equal 55, formatter.repeat

    digits = formatter.format(x, f, e, :down, BinNum.context.precision, false)
    assert_equal [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
                 digits

    digits = formatter.format(x, f, e, :down, BinNum.context.precision, true)
    assert_equal [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 5, 1, 1, 1, 5, 1, 2, 3, 1, 2, 5, 7, 8, 2, 7, 0, 2, 1, 1, 8, 1, 5, 8, 3, 4, 0, 4, 5, 4, 1, 0, 1, 5, 6, 2, 5],
                 digits

    x = BinNum(0.5)
    s, f, e = x.split

    digits = formatter.format(x, f, e, :half_even, BinNum.context.precision, false)
    assert_equal [5], digits

    digits = formatter.format(x, f, e, :half_even, BinNum.context.precision, true)
    assert_equal [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], digits
    refute formatter.round_up

    digits = formatter.format(x, f, e, :up, BinNum.context.precision, false)
    assert_equal [5], digits

    assert_nothing_raised { formatter.format(x, f, e, :up, BinNum.context.precision, true) }
    digits = formatter.format(x, f, e, :up, BinNum.context.precision, true)
    assert_equal [5], digits
    refute formatter.round_up
    assert_equal 1, formatter.repeat

    digits = formatter.format(x, f, e, :down, BinNum.context.precision, false)
    assert_equal [5], digits

    digits = formatter.format(x, f, e, :down, BinNum.context.precision, true)
    assert_equal [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], digits
    refute formatter.round_up
  end

  def test_decimal_to_binary_formatter
    Flt::DecNum.context.precision = 8
    formatter = Flt::Support::Formatter.new(DecNum.radix, DecNum.context.etiny, 2)

    x = DecNum('0.1')
    s, f, e = x.split
    digits = formatter.format(x, f, e, :half_even, DecNum.context.precision, false)
    assert_equal [1], digits

    digits = formatter.format(x, f, e, :half_even, DecNum.context.precision, true)
    assert_equal [0,1], digits
    assert_equal :hi, formatter.round_up

    x = DecNum('0.1000000')
    s, f, e = x.split

    digits = formatter.format(x, f, e, :half_even, DecNum.context.precision, false)
    assert_equal [1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1], digits

    digits = formatter.format(x, f, e, :half_even, DecNum.context.precision, true)
    assert_equal [1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1], digits
    assert_equal :hi, formatter.round_up

    digits = formatter.format(x, f, e, :up, DecNum.context.precision, false)
    assert_equal [1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1], digits

    assert_raise(Support::InfiniteLoopError) { formatter.format(x, f, e, :up, DecNum.context.precision, true) }

    digits = formatter.format(x, f, e, :down, DecNum.context.precision, false)
    assert_equal [1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1], digits

    assert_raise(Support::InfiniteLoopError) { formatter.format(x, f, e, :down, DecNum.context.precision, true) }
  end

  def test_decimal_to_repeating_binary_formatter
    Flt::DecNum.context.precision = 8
    formatter = Flt::Support::Formatter.new(DecNum.radix, DecNum.context.etiny, 2, :raise_on_repeat => false)

    x = DecNum('0.1')
    s, f, e = x.split
    digits = formatter.format(x, f, e, :half_even, DecNum.context.precision, false)
    assert_equal [1], digits

    digits = formatter.format(x, f, e, :half_even, DecNum.context.precision, true)
    assert_equal [0,1], digits
    assert_equal :hi, formatter.round_up

    x = DecNum('0.1000000')
    s, f, e = x.split

    digits = formatter.format(x, f, e, :half_even, DecNum.context.precision, false)
    assert_equal [1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1], digits

    digits = formatter.format(x, f, e, :half_even, DecNum.context.precision, true)
    assert_equal [1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1], digits
    assert_equal :hi, formatter.round_up

    digits = formatter.format(x, f, e, :up, DecNum.context.precision, false)
    assert_equal [1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1], digits

    assert_nothing_raised { formatter.format(x, f, e, :up, DecNum.context.precision, true) }
    digits = formatter.format(x, f, e, :up, DecNum.context.precision, true)
    assert_equal [1, 1, 0, 0], digits
    refute formatter.round_up
    assert_equal 0, formatter.repeat

    digits = formatter.format(x, f, e, :down, DecNum.context.precision, false)
    assert_equal [1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1], digits

    assert_nothing_raised { formatter.format(x, f, e, :down, DecNum.context.precision, true) }
    digits = formatter.format(x, f, e, :down, DecNum.context.precision, true)
    assert_equal [1, 1, 0, 0], digits
    refute formatter.round_up
    assert_equal 0, formatter.repeat
  end

end