require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestOddEven < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_even
    assert !DecNum.nan.even?
    assert !DecNum.infinity.even?
    assert !DecNum.infinity(-1).even?
    assert DecNum.zero.even?
    assert DecNum.zero(-1).even?
    assert !DecNum('0.1').even?
    assert !DecNum('-0.1').even?
    assert !DecNum(-7).even?
    assert DecNum(-6).even?
    assert !DecNum(-5).even?
    assert DecNum(-4).even?
    assert !DecNum(-3).even?
    assert DecNum(-2).even?
    assert !DecNum(-1).even?
    assert DecNum(0).even?
    assert !DecNum(1).even?
    assert DecNum(2).even?
    assert !DecNum(3).even?
    assert DecNum(4).even?
    assert !DecNum(5).even?
    assert DecNum(6).even?
    assert !DecNum(7).even?
    assert !DecNum('101').even?
    assert  DecNum('102').even?
    assert !DecNum('103').even?
    assert  DecNum('10100').even?
    assert  DecNum('10200').even?
    assert !DecNum('101.00').even?
    assert  DecNum('102.00').even?
    assert !DecNum('101.01').even?
    assert !DecNum('102.01').even?
  end

  def test_odd
    assert !DecNum.nan.odd?
    assert !DecNum.infinity.odd?
    assert !DecNum.infinity(-1).odd?
    assert !DecNum.zero.odd?
    assert !DecNum.zero(-1).odd?
    assert !DecNum('0.1').odd?
    assert !DecNum('-0.1').odd?
    assert DecNum(-7).odd?
    assert !DecNum(-6).odd?
    assert DecNum(-5).odd?
    assert !DecNum(-4).odd?
    assert DecNum(-3).odd?
    assert !DecNum(-2).odd?
    assert DecNum(-1).odd?
    assert !DecNum(0).odd?
    assert DecNum(1).odd?
    assert !DecNum(2).odd?
    assert DecNum(3).odd?
    assert !DecNum(4).odd?
    assert DecNum(5).odd?
    assert !DecNum(6).odd?
    assert  DecNum(7).odd?
    assert  DecNum(101).odd?
    assert !DecNum(102).odd?
    assert  DecNum(103).odd?
    assert !DecNum(10100).odd?
    assert !DecNum(10200).odd?
    assert  DecNum('101.00').odd?
    assert !DecNum('102.00').odd?
    assert !DecNum('101.01').odd?
    assert !DecNum('102.01').odd?
  end

end
