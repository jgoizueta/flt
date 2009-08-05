require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestTolerance < Test::Unit::TestCase


  def setup
    initialize_context
    float_emulation_context

    DecNum.context.define_conversion_from(Float) do |x, dec_context|
      BinNum.context(:rounding=>dec_context.rounding) do |bin_context|
        BinNum(x).to_decimal
      end
    end

    DecNum.context.define_conversion_from(BinNum) do |x, dec_context|
      BinNum.context(:rounding=>dec_context.rounding) do |bin_context|
        x.to_decimal
      end
    end

    BinNum.context.define_conversion_from(DecNum) do |x, bin_context|
      BinNum(x.to_s)
    end

  end

  def test_absolute

    tol = Tolerance(100, :absolute)
    assert_equal 100, tol.value(1.0)
    assert_equal 100, tol.value(1.5)
    assert_equal 100, tol.value(1.0E10)
    assert_equal 100, tol.value(-1.0E10)
    assert_equal 100, tol.value(DecNum('1.0'))
    assert_equal 100, tol.value(DecNum('1.5'))
    assert_equal 100, tol.value(DecNum('1.0E10'))
    assert_equal 100, tol.value(DecNum('-1.0E10'))
    assert tol.eq?(11234.0, 11280.0)
    assert tol.eq?(11234.0, 11135.0)
    assert tol.eq?(-11234.0, -11280.0)
    assert tol.eq?(DecNum('11234.0'), DecNum('11280.0'))
    assert tol.eq?(DecNum('11234.0'), DecNum('11135.0'))
    assert tol.eq?(DecNum('-11234.0'), DecNum('-11280.0'))
    assert tol.eq?(DecNum('-11234.0'), DecNum('-11135.0'))
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
    assert_equal 100, tol.value(DecNum('1.0'))
    assert_equal 150, tol.value(DecNum('1.5'))
    assert_equal 1E12, tol.value(DecNum('1.0E10'))
    assert_equal 1E12, tol.value(DecNum('-1.0E10'))

  end

  def test_floating

    tol = Tolerance(100, :floating)
    assert_equal 100, tol.value(1.0)
    assert_equal 200, tol.value(1.5)
    assert_equal 100*2.0**34, tol.value(1.0E10)
    assert_equal 100*2.0**34, tol.value(-1.0E10)
    assert_equal 100, tol.value(DecNum('1.0'))
    assert_equal 1000, tol.value(DecNum('1.5'))
    assert_equal 1E12, tol.value(DecNum('1.0E10'))
    assert_equal 1E12, tol.value(DecNum('-1.0E10'))

  end

  def test_significant_decimals
    t = SigDecimalsTolerance.new(4)

    assert t.eq?(DecNum('1.2345678'), DecNum('1.235'))
    assert t.eq?(DecNum('12345678'), DecNum('12350000'))
    assert !t.eq?(DecNum('1.2345678'), DecNum('1.234'))

  end

  def test_ulps
    DecNum.context.precision = 4
    t = UlpsTolerance.new(2)

    assert t.eq?(DecNum('1.2345678'), DecNum('1.236'))
    assert !t.eq?(DecNum('1.2345678'), DecNum('1.237'))
    assert t.eq?(DecNum('12345678'), DecNum('12360000'))
    assert !t.eq?(DecNum('12345678'), DecNum('12370000'))

  end


end