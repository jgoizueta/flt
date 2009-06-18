require File.dirname(__FILE__) + '/helper.rb'

class TestComparisons < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_hash
    assert_equal Decimal('1.1').hash, Decimal('1.1').hash
    assert_equal Decimal('1.1').hash, (Decimal('1.0')+Decimal('0.1')).hash
    assert_equal Decimal('1.1',:precision=>10).hash, Decimal('1.1',:precision=>3).hash
    assert_not_equal Decimal('1.0').hash, Decimal('1.1').hash
    assert_not_equal Decimal('1.0').hash, 1.0.hash
    assert_not_equal Decimal('1.0').hash, 1.hash

    assert Decimal('1.1').eql?(Decimal('1.1'))
    assert Decimal('1.1').eql?(Decimal('1.0')+Decimal('0.1'))
    assert Decimal('1.1',:precision=>10).eql?(Decimal('1.1',:precision=>3))
    assert !Decimal('1.1').eql?(Decimal('1.0'))
    assert !Decimal('1.0').eql?(1.0)
    assert !Decimal('1.0').eql?(1)
  end

  def test_equality
    assert Decimal('1.1') == Decimal('1.1')
    assert Decimal('1.1') == (Decimal('1.0')+Decimal('0.1'))
    assert Decimal('1.1',:precision=>10) == Decimal('1.1',:precision=>3)
    assert !(Decimal('1.1') == Decimal('1.0'))
    #assert Decimal('1.1') == 1.1
    #assert Decimal('1.0') == 1.0
    #assert Decimal('1.0') == BigDecimal.new('1.000')
    assert Decimal('1.0') == 1
    assert Decimal('0.1') == Rational(1)/Rational(10)

    assert !(Decimal.nan == Decimal.nan)
    assert !(Decimal.nan == Decimal('1'))
    assert !(Decimal.nan == Decimal('0'))
    assert !(Decimal.nan == Decimal.infinity)
    #assert !(Decimal.nan == (0.0/0.0))

    assert !(Decimal.infinity(+1) == Decimal.infinity(-1))
    assert !(Decimal.infinity(+1) == Decimal('0'))
    assert Decimal.infinity(+1) == Decimal.infinity
    assert Decimal.infinity(+1) == Decimal('1')/Decimal('0')
    assert Decimal.infinity(-1) == Decimal('-1')/Decimal('0')

    # TODO: test <=> <= etc.
  end


end
