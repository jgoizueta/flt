require File.dirname(__FILE__) + '/test_helper.rb'

class TestToInt < Test::Unit::TestCase


  def setup
    $implementations_to_test.each do |mod|
      initialize_context mod
    end
  end

  def test_to_i
    $implementations_to_test.each do |mod|

      assert_same 0, mod::Decimal('0.0').to_i
      assert_same 123, mod::Decimal('0.0123000E4').to_i
      assert 1234567890.eql?(mod::Decimal('123456789E1').to_i)
      assert 1234567890.eql?(mod::Decimal('123456789000E-2').to_i)
      assert_same(-123, mod::Decimal('-0.0123000E4').to_i)
      assert(-1234567890.eql?(mod::Decimal('-123456789E1').to_i))
      assert(-1234567890.eql?(mod::Decimal('-123456789000E-2').to_i))
      assert_raise(mod::Decimal::Error) { mod::Decimal.infinity.to_i } unless mod==FPNum::BD
      assert_nil mod::Decimal.nan.to_i unless mod==FPNum::BD
      assert_same(1, mod::Decimal('1.9').to_i)
      assert_same(-1, mod::Decimal('-1.9').to_i)

    end
  end

  def test_to_integral_value
    $implementations_to_test.each do |mod|
      next if mod==FPNum::BD

      assert_equal mod::Decimal('0'), mod::Decimal('0.0').to_integral_value
      assert_equal mod::Decimal('123'), mod::Decimal('0.0123000E4').to_integral_value
      assert_equal mod::Decimal('1234567890'), mod::Decimal('123456789E1').to_integral_value
      assert_equal mod::Decimal('1234567890'), mod::Decimal('123456789000E-2').to_integral_value
      assert_equal mod::Decimal('0'), mod::Decimal('-0.0').to_integral_value
      assert_equal mod::Decimal('-123'), mod::Decimal('-0.0123000E4').to_integral_value
      assert_equal mod::Decimal('-1234567890'), mod::Decimal('-123456789E1').to_integral_value
      assert_equal mod::Decimal('-1234567890'), mod::Decimal('-123456789000E-2').to_integral_value
      mod::Decimal.context.rounding = :half_up
      assert_equal mod::Decimal('2'), mod::Decimal('1.9').to_integral_value
      assert_equal mod::Decimal('-2'), mod::Decimal('-1.9').to_integral_value
      mod::Decimal.context.rounding = :down
      assert_equal mod::Decimal('1'), mod::Decimal('1.9').to_integral_value
      assert_equal mod::Decimal('-1'), mod::Decimal('-1.9').to_integral_value
      assert mod::Decimal.nan.to_integral_value.nan?
      assert_equal mod::Decimal.infinity, mod::Decimal.infinity.to_integral_value

    end
  end

  def test_to_integral_exact
    $implementations_to_test.each do |mod|
      next if mod==FPNum::BD

      mod::Decimal.context.regard_flags mod::Decimal::Rounded
      mod::Decimal.context.traps[mod::Decimal::Rounded] = false
      mod::Decimal.context.regard_flags mod::Decimal::Rounded
      mod::Decimal.context.traps[mod::Decimal::Inexact] = true
      assert_equal mod::Decimal('0'), mod::Decimal('0').to_integral_exact
      assert !mod::Decimal.context.flags[mod::Decimal::Rounded]
      assert_equal mod::Decimal('0'), mod::Decimal('0.0').to_integral_exact
      assert !mod::Decimal.context.flags[mod::Decimal::Rounded]
      assert_equal mod::Decimal('123'), mod::Decimal('123').to_integral_exact
      assert !mod::Decimal.context.flags[mod::Decimal::Rounded]
      assert_equal mod::Decimal('123'), mod::Decimal('0.0123000E4').to_integral_exact
      assert mod::Decimal.context.flags[mod::Decimal::Rounded]
      mod::Decimal.context.flags[mod::Decimal::Rounded] = false
      assert_equal mod::Decimal('1234567890'), mod::Decimal('123456789E1').to_integral_exact
      assert !mod::Decimal.context.flags[mod::Decimal::Rounded]
      assert_equal mod::Decimal('1234567890'), mod::Decimal('123456789000E-2').to_integral_exact
      assert mod::Decimal.context.flags[mod::Decimal::Rounded]
      mod::Decimal.context.flags[mod::Decimal::Rounded] = false
      assert_equal mod::Decimal('0'), mod::Decimal('-0.0').to_integral_exact
      assert !mod::Decimal.context.flags[mod::Decimal::Rounded]
      assert_equal mod::Decimal('-123'), mod::Decimal('-0.0123000E4').to_integral_exact
      assert mod::Decimal.context.flags[mod::Decimal::Rounded]
      mod::Decimal.context.flags[mod::Decimal::Rounded] = false
      assert_equal mod::Decimal('-1234567890'), mod::Decimal('-123456789E1').to_integral_exact
      assert !mod::Decimal.context.flags[mod::Decimal::Rounded]
      assert_equal mod::Decimal('-1234567890'), mod::Decimal('-123456789000E-2').to_integral_exact
      assert mod::Decimal.context.flags[mod::Decimal::Rounded]
      mod::Decimal.context.flags[mod::Decimal::Rounded] = false
      assert_raise(mod::Decimal::Inexact) { mod::Decimal('1.9').to_integral_exact }
      assert mod::Decimal.context.flags[mod::Decimal::Rounded]
      mod::Decimal.context.flags[mod::Decimal::Rounded] = false
      assert_raise(mod::Decimal::Inexact) { mod::Decimal('-1.9').to_integral_exact }
      assert mod::Decimal.nan.to_integral_exact.nan?
      assert_equal mod::Decimal.infinity, mod::Decimal.infinity.to_integral_exact
      assert mod::Decimal.context.flags[mod::Decimal::Rounded]
      mod::Decimal.context.flags[mod::Decimal::Rounded] = false
      mod::Decimal.context.traps[mod::Decimal::Inexact] = false
      mod::Decimal.context.rounding = :half_up
      assert_equal mod::Decimal('2'), mod::Decimal('1.9').to_integral_exact
      assert mod::Decimal.context.flags[mod::Decimal::Inexact]
      mod::Decimal.context.flags[mod::Decimal::Inexact] = false
      assert_equal mod::Decimal('-2'), mod::Decimal('-1.9').to_integral_exact
      assert mod::Decimal.context.flags[mod::Decimal::Inexact]
      mod::Decimal.context.flags[mod::Decimal::Inexact] = false
      mod::Decimal.context.rounding = :down
      assert_equal mod::Decimal('1'), mod::Decimal('1.9').to_integral_exact
      assert mod::Decimal.context.flags[mod::Decimal::Inexact]
      mod::Decimal.context.flags[mod::Decimal::Inexact] = false
      assert_equal mod::Decimal('-1'), mod::Decimal('-1.9').to_integral_exact
      assert mod::Decimal.nan.to_integral_exact.nan?
      assert_equal mod::Decimal.infinity, mod::Decimal.infinity.to_integral_exact

    end
  end


end