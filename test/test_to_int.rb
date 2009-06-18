require File.dirname(__FILE__) + '/helper.rb'

class TestToInt < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_to_i

    assert_same 0, Decimal('0.0').to_i
    assert_same 123, Decimal('0.0123000E4').to_i
    assert 1234567890.eql?(Decimal('123456789E1').to_i)
    assert 1234567890.eql?(Decimal('123456789000E-2').to_i)
    assert_same(-123, Decimal('-0.0123000E4').to_i)
    assert(-1234567890.eql?(Decimal('-123456789E1').to_i))
    assert(-1234567890.eql?(Decimal('-123456789000E-2').to_i))
    assert_raise(Decimal::Error) { Decimal.infinity.to_i }
    assert_nil Decimal.nan.to_i
    assert_same(1, Decimal('1.9').to_i)
    assert_same(-1, Decimal('-1.9').to_i)

  end

  def test_to_integral_value

    assert_equal Decimal('0'), Decimal('0.0').to_integral_value
    assert_equal Decimal('123'), Decimal('0.0123000E4').to_integral_value
    assert_equal Decimal('1234567890'), Decimal('123456789E1').to_integral_value
    assert_equal Decimal('1234567890'), Decimal('123456789000E-2').to_integral_value
    assert_equal Decimal('0'), Decimal('-0.0').to_integral_value
    assert_equal Decimal('-123'), Decimal('-0.0123000E4').to_integral_value
    assert_equal Decimal('-1234567890'), Decimal('-123456789E1').to_integral_value
    assert_equal Decimal('-1234567890'), Decimal('-123456789000E-2').to_integral_value
    Decimal.context.rounding = :half_up
    assert_equal Decimal('2'), Decimal('1.9').to_integral_value
    assert_equal Decimal('-2'), Decimal('-1.9').to_integral_value
    Decimal.context.rounding = :down
    assert_equal Decimal('1'), Decimal('1.9').to_integral_value
    assert_equal Decimal('-1'), Decimal('-1.9').to_integral_value
    assert Decimal.nan.to_integral_value.nan?
    assert_equal Decimal.infinity, Decimal.infinity.to_integral_value

  end

  def test_to_integral_exact

    Decimal.context.regard_flags Decimal::Rounded
    Decimal.context.traps[Decimal::Rounded] = false
    Decimal.context.regard_flags Decimal::Rounded
    Decimal.context.traps[Decimal::Inexact] = true
    assert_equal Decimal('0'), Decimal('0').to_integral_exact
    assert !Decimal.context.flags[Decimal::Rounded]
    assert_equal Decimal('0'), Decimal('0.0').to_integral_exact
    assert !Decimal.context.flags[Decimal::Rounded]
    assert_equal Decimal('123'), Decimal('123').to_integral_exact
    assert !Decimal.context.flags[Decimal::Rounded]
    assert_equal Decimal('123'), Decimal('0.0123000E4').to_integral_exact
    assert Decimal.context.flags[Decimal::Rounded]
    Decimal.context.flags[Decimal::Rounded] = false
    assert_equal Decimal('1234567890'), Decimal('123456789E1').to_integral_exact
    assert !Decimal.context.flags[Decimal::Rounded]
    assert_equal Decimal('1234567890'), Decimal('123456789000E-2').to_integral_exact
    assert Decimal.context.flags[Decimal::Rounded]
    Decimal.context.flags[Decimal::Rounded] = false
    assert_equal Decimal('0'), Decimal('-0.0').to_integral_exact
    assert !Decimal.context.flags[Decimal::Rounded]
    assert_equal Decimal('-123'), Decimal('-0.0123000E4').to_integral_exact
    assert Decimal.context.flags[Decimal::Rounded]
    Decimal.context.flags[Decimal::Rounded] = false
    assert_equal Decimal('-1234567890'), Decimal('-123456789E1').to_integral_exact
    assert !Decimal.context.flags[Decimal::Rounded]
    assert_equal Decimal('-1234567890'), Decimal('-123456789000E-2').to_integral_exact
    assert Decimal.context.flags[Decimal::Rounded]
    Decimal.context.flags[Decimal::Rounded] = false
    assert_raise(Decimal::Inexact) { Decimal('1.9').to_integral_exact }
    assert Decimal.context.flags[Decimal::Rounded]
    Decimal.context.flags[Decimal::Rounded] = false
    assert_raise(Decimal::Inexact) { Decimal('-1.9').to_integral_exact }
    assert Decimal.nan.to_integral_exact.nan?
    assert_equal Decimal.infinity, Decimal.infinity.to_integral_exact
    assert Decimal.context.flags[Decimal::Rounded]
    Decimal.context.flags[Decimal::Rounded] = false
    Decimal.context.traps[Decimal::Inexact] = false
    Decimal.context.rounding = :half_up
    assert_equal Decimal('2'), Decimal('1.9').to_integral_exact
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false
    assert_equal Decimal('-2'), Decimal('-1.9').to_integral_exact
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false
    Decimal.context.rounding = :down
    assert_equal Decimal('1'), Decimal('1.9').to_integral_exact
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false
    assert_equal Decimal('-1'), Decimal('-1.9').to_integral_exact
    assert Decimal.nan.to_integral_exact.nan?
    assert_equal Decimal.infinity, Decimal.infinity.to_integral_exact

  end


end