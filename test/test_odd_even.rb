require File.dirname(__FILE__) + '/helper.rb'

class TestOddEven < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_even
    assert !Decimal.nan.even?
    assert !Decimal.infinity.even?
    assert !Decimal.infinity(-1).even?
    assert Decimal.zero.even?
    assert Decimal.zero(-1).even?
    assert !Decimal('0.1').even?
    assert !Decimal('-0.1').even?
    assert !Decimal(-7).even?
    assert Decimal(-6).even?
    assert !Decimal(-5).even?
    assert Decimal(-4).even?
    assert !Decimal(-3).even?
    assert Decimal(-2).even?
    assert !Decimal(-1).even?
    assert Decimal(0).even?
    assert !Decimal(1).even?
    assert Decimal(2).even?
    assert !Decimal(3).even?
    assert Decimal(4).even?
    assert !Decimal(5).even?
    assert Decimal(6).even?
    assert !Decimal(7).even?
    assert !Decimal('101').even?
    assert  Decimal('102').even?
    assert !Decimal('103').even?
    assert  Decimal('10100').even?
    assert  Decimal('10200').even?
    assert !Decimal('101.00').even?
    assert  Decimal('102.00').even?
    assert !Decimal('101.01').even?
    assert !Decimal('102.01').even?
  end

  def test_odd
    assert !Decimal.nan.odd?
    assert !Decimal.infinity.odd?
    assert !Decimal.infinity(-1).odd?
    assert !Decimal.zero.odd?
    assert !Decimal.zero(-1).odd?
    assert !Decimal('0.1').odd?
    assert !Decimal('-0.1').odd?
    assert Decimal(-7).odd?
    assert !Decimal(-6).odd?
    assert Decimal(-5).odd?
    assert !Decimal(-4).odd?
    assert Decimal(-3).odd?
    assert !Decimal(-2).odd?
    assert Decimal(-1).odd?
    assert !Decimal(0).odd?
    assert Decimal(1).odd?
    assert !Decimal(2).odd?
    assert Decimal(3).odd?
    assert !Decimal(4).odd?
    assert Decimal(5).odd?
    assert !Decimal(6).odd?
    assert  Decimal(7).odd?
    assert  Decimal(101).odd?
    assert !Decimal(102).odd?
    assert  Decimal(103).odd?
    assert !Decimal(10100).odd?
    assert !Decimal(10200).odd?
    assert  Decimal('101.00').odd?
    assert !Decimal('102.00').odd?
    assert !Decimal('101.01').odd?
    assert !Decimal('102.01').odd?
  end

end
