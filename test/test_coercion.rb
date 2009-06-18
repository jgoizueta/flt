require File.dirname(__FILE__) + '/helper.rb'

class TestCoercion < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_coerce
    assert_equal Decimal('7.1'), Decimal('0.1') + 7
    assert_equal Decimal('7.1'), 7 + Decimal('0.1')
    assert_equal Decimal('14'), Decimal(7) * 2
    assert_equal Decimal('14'), 2 * Decimal(7)

    assert_equal Decimal('7.1'), Decimal(7) + Rational(1,10)
    assert_equal Decimal('7.1'), Rational(1,10) + Decimal(7)
    assert_equal Decimal('1.4'), Decimal(7) * Rational(2,10)
    assert_equal Decimal('1.4'), Rational(2,10) * Decimal(7)
  end

end