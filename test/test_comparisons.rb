require File.dirname(__FILE__) + '/test_helper.rb'

class TestComparisons < Test::Unit::TestCase


  def setup
    $implementations_to_test.each do |mod|
      initialize_context mod
    end
  end

  def test_hash
    $implementations_to_test.each do |mod|
      assert_equal mod::Decimal('1.1').hash, mod::Decimal('1.1').hash
      assert_equal mod::Decimal('1.1').hash, (mod::Decimal('1.0')+mod::Decimal('0.1')).hash
      assert_equal mod::Decimal('1.1',:precision=>10).hash, mod::Decimal('1.1',:precision=>3).hash if mod!=FPNum::BD
      assert_not_equal mod::Decimal('1.0').hash, mod::Decimal('1.1').hash
      assert_not_equal mod::Decimal('1.0').hash, 1.0.hash
      assert_not_equal mod::Decimal('1.0').hash, 1.hash

      assert mod::Decimal('1.1').eql?(mod::Decimal('1.1'))
      assert mod::Decimal('1.1').eql?(mod::Decimal('1.0')+mod::Decimal('0.1'))
      assert mod::Decimal('1.1',:precision=>10).eql?(mod::Decimal('1.1',:precision=>3)) if mod!=FPNum::BD
      assert !mod::Decimal('1.1').eql?(mod::Decimal('1.0'))
      assert !mod::Decimal('1.0').eql?(1.0)
      assert !mod::Decimal('1.0').eql?(1)
    end
  end

  def test_equality
    $implementations_to_test.each do |mod|
      assert mod::Decimal('1.1') == mod::Decimal('1.1')
      assert mod::Decimal('1.1') == (mod::Decimal('1.0')+mod::Decimal('0.1'))
      assert mod::Decimal('1.1',:precision=>10) == mod::Decimal('1.1',:precision=>3) if mod!=FPNum::BD
      assert !(mod::Decimal('1.1') == mod::Decimal('1.0'))
      #assert mod::Decimal('1.1') == 1.1
      #assert mod::Decimal('1.0') == 1.0
      #assert mod::Decimal('1.0') == BigDecimal.new('1.000')
      assert mod::Decimal('1.0') == 1
      assert mod::Decimal('0.1') == Rational(1)/Rational(10)

      assert !(mod::Decimal.nan == mod::Decimal.nan)
      assert !(mod::Decimal.nan == mod::Decimal('1'))
      assert !(mod::Decimal.nan == mod::Decimal('0'))
      assert !(mod::Decimal.nan == mod::Decimal.infinity)
      #assert !(mod::Decimal.nan == (0.0/0.0))

      assert !(mod::Decimal.infinity(+1) == mod::Decimal.infinity(-1))
      assert !(mod::Decimal.infinity(+1) == mod::Decimal('0'))
      assert mod::Decimal.infinity(+1) == mod::Decimal.infinity
      assert mod::Decimal.infinity(+1) == mod::Decimal('1')/mod::Decimal('0')
      assert mod::Decimal.infinity(-1) == mod::Decimal('-1')/mod::Decimal('0')

      # TODO: test <=> <= etc.
    end
  end


end
