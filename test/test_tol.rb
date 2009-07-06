require File.dirname(__FILE__) + '/helper.rb'
require File.dirname(__FILE__) + '/../lib/bigfloat/tolerance'

class TestTolerance < Test::Unit::TestCase


  def setup
    initialize_context
    float_emulation_context

    Decimal.context.define_conversion_from(Float) do |x, dec_context|
      BinFloat.context(:rounding=>dec_context.rounding) do |bin_context|
        BinFloat(x).to_decimal
      end
    end

    Decimal.context.define_conversion_from(BinFloat) do |x, dec_context|
      BinFloat.context(:rounding=>dec_context.rounding) do |bin_context|
        x.to_decimal
      end
    end

    BinFloat.context.define_conversion_from(Decimal) do |x, bin_context|
      BinFloat(x.to_s)
    end

  end

  def test_absolute

    tol = Tolerance(100, :absolute)
    assert_equal 100, tol.value(1.0)
    assert_equal 100, tol.value(1.5)
    assert_equal 100, tol.value(1.0E10)
    assert_equal 100, tol.value(-1.0E10)
    assert_equal 100, tol.value(Decimal('1.0'))
    assert_equal 100, tol.value(Decimal('1.5'))
    assert_equal 100, tol.value(Decimal('1.0E10'))
    assert_equal 100, tol.value(Decimal('-1.0E10'))
    assert tol.eq?(11234.0, 11280.0)
    assert tol.eq?(11234.0, 11135.0)
    assert tol.eq?(-11234.0, -11280.0)
    assert tol.eq?(Decimal('11234.0'), Decimal('11280.0'))
    assert tol.eq?(Decimal('11234.0'), Decimal('11135.0'))
    assert tol.eq?(Decimal('-11234.0'), Decimal('-11280.0'))
    assert tol.eq?(Decimal('-11234.0'), Decimal('-11135.0'))
    assert !tol.eq?(11234.0, -11280.0)
    assert !tol.eq?(-11234.0, 11280.0)
    assert !tol.eq?(11234.0, 11335.0)
    assert !tol.eq?(11234.0, 11133.0)

  end

  def test_relative

    tol = Tolerance(100, :relative)
    assert_equal 100, tol.value(1.0)
    assert_equal 150, tol.value(1.5)
    assert_equal 1E12, tol.value(1.0E10)
    assert_equal 1E12, tol.value(-1.0E10)
    assert_equal 100, tol.value(Decimal('1.0'))
    assert_equal 150, tol.value(Decimal('1.5'))
    assert_equal 1E12, tol.value(Decimal('1.0E10'))
    assert_equal 1E12, tol.value(Decimal('-1.0E10'))

  end

  def test_floating

    tol = Tolerance(100, :floating)
    assert_equal 100, tol.value(1.0)
    assert_equal 200, tol.value(1.5)
    assert_equal 100*2.0**34, tol.value(1.0E10)
    assert_equal 100*2.0**34, tol.value(-1.0E10)
    assert_equal 100, tol.value(Decimal('1.0'))
    assert_equal 1000, tol.value(Decimal('1.5'))
    assert_equal 1E12, tol.value(Decimal('1.0E10'))
    assert_equal 1E12, tol.value(Decimal('-1.0E10'))

  end

  def test_significant_decimals
    t = SigDecimalsTolerance.new(4)

    assert t.eq?(Decimal('1.2345678'), Decimal('1.235'))
    assert t.eq?(Decimal('12345678'), Decimal('12350000'))
    assert !t.eq?(Decimal('1.2345678'), Decimal('1.234'))

  end

  def test_ulps
    t = SigDecimalsTolerance.new(4)

    assert t.eq?(Decimal('1.2345678'), Decimal('1.235'))
    assert t.eq?(Decimal('12345678'), Decimal('12350000'))
    assert !t.eq?(Decimal('12345678'), Decimal('12380000'))

  end


end