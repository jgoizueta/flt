require File.dirname(__FILE__) + '/test_helper.rb'

class TestPluginConversions < Test::Unit::TestCase


  def setup
    $implementations_to_test.each do |mod|
      initialize_context mod
    end
  end

  def test_big_decimal_conversions
    mod = FPNum::RB

    mod::Decimal.convert_from(BigDecimal) do |x|
      Decimal(x.to_s) # or use x.split etc.
    end

    assert_equal BigDecimal.new('0'), mod::Decimal('0')
    assert_equal BigDecimal.new('1.2345'), mod::Decimal('1.2345')
    assert_equal BigDecimal.new('-1.2345'), mod::Decimal('-1.2345')
    assert_equal BigDecimal.new('1.2345'), mod::Decimal('0.0012345000E3')
    assert_equal mod::Decimal('7.1'), BigDecimal.new('7')+mod::Decimal('0.1')
    assert_equal mod::Decimal('7.1'), mod::Decimal('7')+BigDecimal.new('0.1')
    assert_equal mod::Decimal('1.1'), mod::Decimal(BigDecimal.new('1.1'))
    assert mod::Decimal(BigDecimal.new('1.1')).is_a?(mod::Decimal)

    mod::Decimal.convert_to(BigDecimal, :to_d) do |x|
      BigDecimal.new(x.to_s) # TODO: use x.split and handle special values
    end

    ['0.1', '-0.1', '0.0', '1234567.1234567', '-1234567.1234567', '1.234E7', '1.234E-7'].each do |n|
      f = BigDecimal.new(n)
      d = mod::Decimal(n)
      assert d.to_d.is_a?(BigDecimal)
      assert_equal f, d.to_d
    end

  end

  def test_float_conversions
    mod = FPNum::RB

    mod::Decimal.convert_from(Float) do |x|
      s,e = Math.frexp(x)
      significand = Math.ldexp(s, Float::MANT_DIG).to_i
      exponent = e - Float::MANT_DIG
      # the number is (as a Rational) significand * exponent**Float::RADIX
      mod::Decimal(significand*(exponent**Float::RADIX))
    end

    assert_equal 0.0, mod::Decimal('0')
    assert_equal mod::Decimal('0'), 0.0
    assert_equal 1.2345, Decimal('1.2345')
    assert_equal mod::Decimal('1.2345'), 1.2345
    assert_equal -1.2345, mod::Decimal('-1.2345')
    assert_equal 1.2345, mod::Decimal('0.0012345000E3')
    mod::assert_equal mod::Decimal('7.1'), 7.0+mod::Decimal('0.1')
    Decimal.local_context(:precision=>12) do
      assert_equal mod::Decimal('7.1'), mod::Decimal('7')+0.1
    end
    assert_equal mod::Decimal('11'), mod::Decimal(11.0)
    assert mod::dDecimal(11.0).is_a?(mod::Decimal)

  end

end