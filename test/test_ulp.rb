require File.dirname(__FILE__) + '/helper.rb'

class TestUlp < Test::Unit::TestCase


  def setup
    initialize_context
  end


  NUMBERS = %w{
    0.0000
    0.0001
    0.0002
    0.0003
    0.0999
    0.1000
    0.1001
    0.1999
    0.2000
    0.2001
    0.8999
    0.9000
    0.9001
    0.9999
    1.0000
    1.0001
    1E27
    1.0001E27
  }

  def test_ulp_4dig
    Decimal.context.precision = 4
    Decimal.context.emin = -99
    Decimal.context.emax =  99

    (NUMBERS+[Decimal.zero,Decimal.zero(-1),
             Decimal.context.minimum_nonzero, Decimal.context.maximum_subnormal, Decimal.context.minimum_normal,
             Decimal.context.maximum_finite]).each do |n|
        x = Decimal(n)
        if x >= 0
          assert_equal x-x.next_minus, x.ulp
        else
          assert_equal x.next_plus-x, x.ulp
        end
    end

    assert_equal Decimal.context.maximum_finite-Decimal.context.maximum_finite.next_minus, Decimal.infinity.ulp
    assert_equal Decimal('0.00001'), Decimal('0.1').ulp
    assert_equal Decimal('1E-7'), Decimal('0.001').ulp
    assert_equal Decimal('0.00001'), Decimal('0.100').ulp
    assert_equal Decimal('0.00001'), Decimal('0.1000').ulp
    assert_equal Decimal('0.0001'), Decimal('0.1001').ulp
    assert_equal Decimal('0.0001'), Decimal('0.9').ulp
    assert_equal Decimal('0.0001'), Decimal('0.99999').ulp
    assert_equal Decimal('0.0001'), Decimal('0.9000').ulp
    assert_equal Decimal('0.0001'), Decimal('0.990').ulp
    assert_equal Decimal('0.0001'), Decimal('0.23').ulp
    assert_equal Decimal('1E-101'), Decimal('1.001E-98').ulp
    assert_equal Decimal('1E-102'), Decimal('1.001E-99').ulp
    assert_equal Decimal('1E-102'), Decimal('1E-99').ulp
    assert_equal Decimal('1E-102'), Decimal('9.99E-100').ulp
    assert_equal Decimal('1E-102'), Decimal('1E-102').ulp
    assert_equal Decimal('1E-102'), Decimal('0').ulp
    assert_equal Decimal('1E-102'), Decimal('0').ulp

    Decimal.context.exact = true
    assert Decimal(1).ulp.nan?, "No ulps can be computed in exact contexts"
    Decimal.context.traps[Decimal::InvalidOperation] = true
    assert_raise(Decimal::InvalidOperation) { Decimal(1).ulp }

  end

  BIN_NUMBERS = %w{
    00000
    00001
    00010
    00011
    00111
    01000
    01001
    01111
    10000
    10001
  }


  def test_ulp_bin
    BinFloat.context.precision = 4
    BinFloat.context.emin = -99
    BinFloat.context.emax =  99

    numbers = []
    [0, -10, 10].each do |exp|
      numbers += BIN_NUMBERS.map{|n| BinFloat(+1, n.to_i(2), exp)}
      numbers += BIN_NUMBERS.map{|n| BinFloat(-1, n.to_i(2), exp)}
    end

    (numbers+[BinFloat.zero,BinFloat.zero(-1),
             BinFloat.context.minimum_nonzero, BinFloat.context.maximum_subnormal, BinFloat.context.minimum_normal,
             BinFloat.context.maximum_finite]).each do |x|
        if x >= 0
          assert_equal x-x.next_minus, x.ulp
        else
          assert_equal x.next_plus-x, x.ulp
        end
    end

    assert_equal BinFloat.context.maximum_finite-BinFloat.context.maximum_finite.next_minus, BinFloat.infinity.ulp
    assert_equal BinFloat(+1,1,-5), BinFloat(+1,1,-1).ulp
    assert_equal BinFloat(+1,1,-7), BinFloat(+1,1,-3).ulp
    assert_equal BinFloat(+1,1,-5), BinFloat(+1,4,-3).ulp
    assert_equal BinFloat(+1,1,-7), BinFloat(+1,4,-5).ulp
    assert_equal BinFloat(+1,1,-5), BinFloat(+1,2**4-1,-5).ulp
    assert_equal BinFloat(+1,1,-7), BinFloat(+1,2**4-1,-7).ulp
    assert_equal BinFloat(+1,1,-5), BinFloat(+1,4*(2**4-1),-7).ulp
    assert_equal BinFloat(+1,1,-7), BinFloat(+1,4*(2**4-1),-9).ulp

    BinFloat.context.exact = true
    assert BinFloat(1).ulp.nan?, "No ulps can be computed in exact contexts"
    BinFloat.context.traps[BinFloat::InvalidOperation] = true
    assert_raise(BinFloat::InvalidOperation) { BinFloat(1).ulp }

  end


end