require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestComparisons < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_hash
    assert_equal DecNum('1.1').hash, DecNum('1.1').hash
    assert_equal DecNum('1.1').hash, (DecNum('1.0')+DecNum('0.1')).hash
    assert_equal DecNum('1.1',:precision=>10).hash, DecNum('1.1',:precision=>3).hash
    assert_not_equal DecNum('1.0').hash, DecNum('1.1').hash
    assert_not_equal DecNum('1.0').hash, 1.0.hash
    assert_not_equal DecNum('1.0').hash, 1.hash

    assert DecNum('1.1').eql?(DecNum('1.1'))
    assert DecNum('1.1').eql?(DecNum('1.0')+DecNum('0.1'))
    assert DecNum('1.1',:precision=>10).eql?(DecNum('1.1',:precision=>3))
    assert !DecNum('1.1').eql?(DecNum('1.0'))
    assert !DecNum('1.0').eql?(1.0)
    assert !DecNum('1.0').eql?(1)
  end

  def test_equality
    assert DecNum('1.1') == DecNum('1.1')
    assert DecNum('1.1') == (DecNum('1.0')+DecNum('0.1'))
    assert DecNum('1.1',:precision=>10) == DecNum('1.1',:precision=>3)
    assert !(DecNum('1.1') == DecNum('1.0'))
    #assert DecNum('1.1') == 1.1
    #assert DecNum('1.0') == 1.0
    #assert DecNum('1.0') == BigDecimal.new('1.000')
    assert DecNum('1.0') == 1
    assert DecNum('0.1') == Rational(1)/Rational(10)

    assert !(DecNum.nan == DecNum.nan)
    assert !(DecNum.nan == DecNum('1'))
    assert !(DecNum.nan == DecNum('0'))
    assert !(DecNum.nan == DecNum.infinity)
    #assert !(DecNum.nan == (0.0/0.0))

    assert !(DecNum.infinity(+1) == DecNum.infinity(-1))
    assert !(DecNum.infinity(+1) == DecNum('0'))
    assert DecNum.infinity(+1) == DecNum.infinity
    assert DecNum.infinity(+1) == DecNum('1')/DecNum('0')
    assert DecNum.infinity(-1) == DecNum('-1')/DecNum('0')

    # TODO: test <=> <= etc.
  end


end
