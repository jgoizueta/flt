require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestToInt < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_to_i

    assert_same 0, DecNum('0.0').to_i
    assert_same 123, DecNum('0.0123000E4').to_i
    assert 1234567890.eql?(DecNum('123456789E1').to_i)
    assert 1234567890.eql?(DecNum('123456789000E-2').to_i)
    assert_same(-123, DecNum('-0.0123000E4').to_i)
    assert(-1234567890.eql?(DecNum('-123456789E1').to_i))
    assert(-1234567890.eql?(DecNum('-123456789000E-2').to_i))
    assert_raise(DecNum::Error) { DecNum.infinity.to_i }
    assert_nil DecNum.nan.to_i
    assert_same(1, DecNum('1.9').to_i)
    assert_same(-1, DecNum('-1.9').to_i)

  end

  def test_to_integral_value

    assert_equal DecNum('0'), DecNum('0.0').to_integral_value
    assert_equal DecNum('123'), DecNum('0.0123000E4').to_integral_value
    assert_equal DecNum('1234567890'), DecNum('123456789E1').to_integral_value
    assert_equal DecNum('1234567890'), DecNum('123456789000E-2').to_integral_value
    assert_equal DecNum('0'), DecNum('-0.0').to_integral_value
    assert_equal DecNum('-123'), DecNum('-0.0123000E4').to_integral_value
    assert_equal DecNum('-1234567890'), DecNum('-123456789E1').to_integral_value
    assert_equal DecNum('-1234567890'), DecNum('-123456789000E-2').to_integral_value
    DecNum.context.rounding = :half_up
    assert_equal DecNum('2'), DecNum('1.9').to_integral_value
    assert_equal DecNum('-2'), DecNum('-1.9').to_integral_value
    DecNum.context.rounding = :down
    assert_equal DecNum('1'), DecNum('1.9').to_integral_value
    assert_equal DecNum('-1'), DecNum('-1.9').to_integral_value
    assert DecNum.nan.to_integral_value.nan?
    assert_equal DecNum.infinity, DecNum.infinity.to_integral_value

  end

  def test_to_integral_exact

    DecNum.context.regard_flags DecNum::Rounded
    DecNum.context.traps[DecNum::Rounded] = false
    DecNum.context.regard_flags DecNum::Rounded
    DecNum.context.traps[DecNum::Inexact] = true
    assert_equal DecNum('0'), DecNum('0').to_integral_exact
    assert !DecNum.context.flags[DecNum::Rounded]
    assert_equal DecNum('0'), DecNum('0.0').to_integral_exact
    assert !DecNum.context.flags[DecNum::Rounded]
    assert_equal DecNum('123'), DecNum('123').to_integral_exact
    assert !DecNum.context.flags[DecNum::Rounded]
    assert_equal DecNum('123'), DecNum('0.0123000E4').to_integral_exact
    assert DecNum.context.flags[DecNum::Rounded]
    DecNum.context.flags[DecNum::Rounded] = false
    assert_equal DecNum('1234567890'), DecNum('123456789E1').to_integral_exact
    assert !DecNum.context.flags[DecNum::Rounded]
    assert_equal DecNum('1234567890'), DecNum('123456789000E-2').to_integral_exact
    assert DecNum.context.flags[DecNum::Rounded]
    DecNum.context.flags[DecNum::Rounded] = false
    assert_equal DecNum('0'), DecNum('-0.0').to_integral_exact
    assert !DecNum.context.flags[DecNum::Rounded]
    assert_equal DecNum('-123'), DecNum('-0.0123000E4').to_integral_exact
    assert DecNum.context.flags[DecNum::Rounded]
    DecNum.context.flags[DecNum::Rounded] = false
    assert_equal DecNum('-1234567890'), DecNum('-123456789E1').to_integral_exact
    assert !DecNum.context.flags[DecNum::Rounded]
    assert_equal DecNum('-1234567890'), DecNum('-123456789000E-2').to_integral_exact
    assert DecNum.context.flags[DecNum::Rounded]
    DecNum.context.flags[DecNum::Rounded] = false
    assert_raise(DecNum::Inexact) { DecNum('1.9').to_integral_exact }
    assert DecNum.context.flags[DecNum::Rounded]
    DecNum.context.flags[DecNum::Rounded] = false
    assert_raise(DecNum::Inexact) { DecNum('-1.9').to_integral_exact }
    assert DecNum.nan.to_integral_exact.nan?
    assert_equal DecNum.infinity, DecNum.infinity.to_integral_exact
    assert DecNum.context.flags[DecNum::Rounded]
    DecNum.context.flags[DecNum::Rounded] = false
    DecNum.context.traps[DecNum::Inexact] = false
    DecNum.context.rounding = :half_up
    assert_equal DecNum('2'), DecNum('1.9').to_integral_exact
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false
    assert_equal DecNum('-2'), DecNum('-1.9').to_integral_exact
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false
    DecNum.context.rounding = :down
    assert_equal DecNum('1'), DecNum('1.9').to_integral_exact
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false
    assert_equal DecNum('-1'), DecNum('-1.9').to_integral_exact
    assert DecNum.nan.to_integral_exact.nan?
    assert_equal DecNum.infinity, DecNum.infinity.to_integral_exact

  end


end