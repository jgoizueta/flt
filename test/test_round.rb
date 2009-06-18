require File.dirname(__FILE__) + '/helper.rb'


class TestRound < Test::Unit::TestCase


  def setup
    initialize_context
  end


  def test_round

    assert_equal(101,  Decimal('100.5').round)
    assert Decimal('100.5').round.kind_of?(Integer)
    assert_equal 100, Decimal('100.4999999999').round
    assert_equal(-101, Decimal('-100.5').round)
    assert_equal(-100, Decimal('-100.4999999999').round)

    assert_equal 101, Decimal('100.5').round(:places=>0)
    assert Decimal('100.5').round(:places=>0).kind_of?(Decimal)
    assert_equal 101, Decimal('100.5').round(0)
    assert Decimal('100.5').round(0).kind_of?(Decimal)

    assert_equal Decimal('123.12'), Decimal('123.123').round(2)
    assert_equal Decimal('123'), Decimal('123.123').round(0)
    assert_equal Decimal('120'), Decimal('123.123').round(-1)
    assert_equal Decimal('120'), Decimal('123.123').round(:precision=>2)
    assert_equal Decimal('123.12'), Decimal('123.123').round(:precision=>5)

    assert_equal 100, Decimal('100.5').round(:rounding=>:half_even)
    assert_equal 101, Decimal('100.5000001').round(:rounding=>:half_even)
    assert_equal 102, Decimal('101.5').round(:rounding=>:half_even)
    assert_equal 101, Decimal('101.4999999999').round(:rounding=>:half_even)

    assert_equal 101, Decimal('100.0001').ceil
    assert_equal(-100, Decimal('-100.0001').ceil)
    assert_equal(-100, Decimal('-100.9999').ceil)
    assert_equal 100, Decimal('100.9999').floor
    assert_equal(-101, Decimal('-100.9999').floor)
    assert_equal(-101, Decimal('-100.0001').floor)

    assert_equal 100, Decimal('100.99999').truncate
    assert_equal(-100, Decimal('-100.99999').truncate)

  end


end
