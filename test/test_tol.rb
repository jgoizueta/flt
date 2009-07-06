require File.dirname(__FILE__) + '/helper.rb'
require File.dirname(__FILE__) + '/../../lib/bigfloat/tolerance'

class TestTolerance < Test::Unit::TestCase


  def setup
    initialize_context

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

  def test_significant_decimals
    t = SigDecimalsTolerance.new(4)

    assert t.equal?(Decimal('1.2345678'), Decimal('1.235'))
    assert t.equal?(Decimal('12345678'), Decimal('12350000'))

  end

  def test_ulps
    t = SigDecimalsTolerance.new(4)

    assert t.equal?(Decimal('1.2345678'), Decimal('1.235'))
    assert t.equal?(Decimal('12345678'), Decimal('12350000'))

  end


end