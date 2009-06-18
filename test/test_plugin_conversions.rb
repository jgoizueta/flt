require File.dirname(__FILE__) + '/test_helper.rb'

class TestPluginConversions < Test::Unit::TestCase


  def setup
    $implementations_to_test.each do |mod|
      initialize_context mod
    end
  end

  def test_convert_to
    mod = FPNum::RB
    d = mod::Decimal('1.1')
    x = d.convert_to(Rational)
    assert x.is_a?(Rational)
    assert_equal d.to_r, x

    d = mod::Decimal('11')
    x = d.convert_to(Integer)
    assert x.is_a?(Integer)
    assert_equal d.to_i, x

    d = mod::Decimal('11')
    x = d.convert_to(Float)
    assert x.is_a?(Float)
    assert_equal d.to_f, x
  end


  def test_big_decimal_conversions
    mod = FPNum::RB

    mod::Decimal.local_context do

      mod::Decimal.context.define_conversion_from(BigDecimal) do |x, context|
        mod::Decimal(x.to_s) # or use x.split etc.
      end
      assert mod::Decimal('0') == BigDecimal.new('0')
      assert_equal BigDecimal.new('0'), mod::Decimal('0')
      assert_equal BigDecimal.new('1.2345'), mod::Decimal('1.2345')
      assert_equal BigDecimal.new('-1.2345'), mod::Decimal('-1.2345')
      assert_equal BigDecimal.new('1.2345'), mod::Decimal('0.0012345000E3')
      assert_equal mod::Decimal('7.1'), BigDecimal.new('7')+mod::Decimal('0.1')
      assert_equal mod::Decimal('7.1'), mod::Decimal('7')+BigDecimal.new('0.1')
      assert_equal mod::Decimal('1.1'), mod::Decimal(BigDecimal.new('1.1'))
      assert mod::Decimal(BigDecimal.new('1.1')).is_a?(mod::Decimal)

      mod::Decimal.context.define_conversion_to(BigDecimal) do |x|
        BigDecimal.new(x.to_s) # TODO: use x.split and handle special values
      end

      ['0.1', '-0.1', '0.0', '1234567.1234567', '-1234567.1234567', '1.234E7', '1.234E-7'].each do |n|
        f = BigDecimal.new(n)
        d = mod::Decimal(n)
        c = d.convert_to(BigDecimal)
        assert c.is_a?(BigDecimal)
        assert_equal f, c
      end
    end

    assert_raise(TypeError) { mod::Decimal('0') == BigDecimal.new('0') }
    assert_not_equal BigDecimal.new('0'), mod::Decimal('0')
    assert_not_equal BigDecimal.new('1.2345'), mod::Decimal('1.2345')
    assert_not_equal BigDecimal.new('-1.2345'), mod::Decimal('-1.2345')
    assert_not_equal BigDecimal.new('1.2345'), mod::Decimal('0.0012345000E3')
    assert_raise(TypeError) { BigDecimal.new('7')+mod::Decimal('0.1') }
    assert_raise(TypeError) { mod::Decimal('7')+BigDecimal.new('0.1') }
    assert_raise(TypeError) { mod::Decimal(BigDecimal.new('1.1')) }

    ['0.1', '-0.1', '0.0', '1234567.1234567', '-1234567.1234567', '1.234E7', '1.234E-7'].each do |n|
      assert_raise(TypeError) { mod::Decimal(n).convert_to(BigDecimal) }
    end

  end

  # def test_float_conversions
  #   mod = FPNum::RB
  #
  #   # Exact Float to Decimal conversion limited to context precision
  #   # => Decimal('0.1') != Decimal(0.1) unless precision is low enough
  #   mod::Decimal.context.convert_from(Float) do |x, context|
  #     s,e = Math.frexp(x)
  #     significand = Math.ldexp(s, Float::MANT_DIG).to_i
  #     exponent = e - Float::MANT_DIG
  #     # the number is (as a Rational) significand * exponent**Float::RADIX
  #     mod::Decimal(significand*(Float::RADIX**exponent ))
  #   end
  #
  #   assert_equal 0.0, mod::Decimal('0')
  #   assert_equal mod::Decimal('0'), 0.0
  #   assert_equal 1234.5, mod::Decimal('1234.5')
  #   assert_equal mod::Decimal('1234.5'), 1234.5
  #   assert_equal -1234.5, mod::Decimal('-1234.5')
  #   assert_equal 1234.5, mod::Decimal('0.0012345000E6')
  #   assert_equal mod::Decimal('7.1'), 7.0+mod::Decimal('0.1')
  #   mod::Decimal.context.local_context(:precision=>12) do
  #     assert_equal mod::Decimal('7.1'), mod::Decimal('7')+0.1
  #   end
  #   assert_equal mod::Decimal('11'), mod::Decimal(11.0)
  #   assert mod::Decimal(11.0).is_a?(mod::Decimal)
  #
  # end

end