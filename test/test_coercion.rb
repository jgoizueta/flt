require File.dirname(__FILE__) + '/test_helper.rb'

class TestCoercion < Test::Unit::TestCase


  def setup
    $implementations_to_test.each do |mod|
      initialize_context mod
    end
  end

  def test_coerce
    $implementations_to_test.each do |mod|

      assert_equal mod::Decimal('7.1'), mod::Decimal('0.1') + 7
      assert_equal mod::Decimal('7.1'), 7 + mod::Decimal('0.1')
      assert_equal mod::Decimal('14'), mod::Decimal(7) * 2
      assert_equal mod::Decimal('14'), 2 * mod::Decimal(7)

      assert_equal mod::Decimal('7.1'), mod::Decimal(7) + Rational(1,10)
      assert_equal mod::Decimal('7.1'), Rational(1,10) + mod::Decimal(7)
      assert_equal mod::Decimal('1.4'), mod::Decimal(7) * Rational(2,10)
      assert_equal mod::Decimal('1.4'), Rational(2,10) * mod::Decimal(7)

    end
  end

end