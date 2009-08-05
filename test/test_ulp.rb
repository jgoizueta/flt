require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

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
    DecNum.context.precision = 4
    DecNum.context.emin = -99
    DecNum.context.emax =  99

    (NUMBERS+[DecNum.zero,DecNum.zero(-1),
             DecNum.context.minimum_nonzero, DecNum.context.maximum_subnormal, DecNum.context.minimum_normal,
             DecNum.context.maximum_finite]).each do |n|
        x = DecNum(n)
        if x >= 0
          assert_equal x-x.next_minus, x.ulp
        else
          assert_equal x.next_plus-x, x.ulp
        end
    end

    assert_equal DecNum.context.maximum_finite-DecNum.context.maximum_finite.next_minus, DecNum.infinity.ulp
    assert_equal DecNum('0.00001'), DecNum('0.1').ulp
    assert_equal DecNum('1E-7'), DecNum('0.001').ulp
    assert_equal DecNum('0.00001'), DecNum('0.100').ulp
    assert_equal DecNum('0.00001'), DecNum('0.1000').ulp
    assert_equal DecNum('0.0001'), DecNum('0.1001').ulp
    assert_equal DecNum('0.0001'), DecNum('0.9').ulp
    assert_equal DecNum('0.0001'), DecNum('0.99999').ulp
    assert_equal DecNum('0.0001'), DecNum('0.9000').ulp
    assert_equal DecNum('0.0001'), DecNum('0.990').ulp
    assert_equal DecNum('0.0001'), DecNum('0.23').ulp
    assert_equal DecNum('1E-101'), DecNum('1.001E-98').ulp
    assert_equal DecNum('1E-102'), DecNum('1.001E-99').ulp
    assert_equal DecNum('1E-102'), DecNum('1E-99').ulp
    assert_equal DecNum('1E-102'), DecNum('9.99E-100').ulp
    assert_equal DecNum('1E-102'), DecNum('1E-102').ulp
    assert_equal DecNum('1E-102'), DecNum('0').ulp
    assert_equal DecNum('1E-102'), DecNum('0').ulp

    DecNum.context.exact = true
    assert DecNum(1).ulp.nan?, "No ulps can be computed in exact contexts"
    DecNum.context.traps[DecNum::InvalidOperation] = true
    assert_raise(DecNum::InvalidOperation) { DecNum(1).ulp }

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
    BinNum.context.precision = 4
    BinNum.context.emin = -99
    BinNum.context.emax =  99

    numbers = []
    [0, -10, 10].each do |exp|
      numbers += BIN_NUMBERS.map{|n| BinNum(+1, n.to_i(2), exp)}
      numbers += BIN_NUMBERS.map{|n| BinNum(-1, n.to_i(2), exp)}
    end

    (numbers+[BinNum.zero,BinNum.zero(-1),
             BinNum.context.minimum_nonzero, BinNum.context.maximum_subnormal, BinNum.context.minimum_normal,
             BinNum.context.maximum_finite]).each do |x|
        if x >= 0
          assert_equal x-x.next_minus, x.ulp
        else
          assert_equal x.next_plus-x, x.ulp
        end
    end

    assert_equal BinNum.context.maximum_finite-BinNum.context.maximum_finite.next_minus, BinNum.infinity.ulp
    assert_equal BinNum(+1,1,-5), BinNum(+1,1,-1).ulp
    assert_equal BinNum(+1,1,-7), BinNum(+1,1,-3).ulp
    assert_equal BinNum(+1,1,-5), BinNum(+1,4,-3).ulp
    assert_equal BinNum(+1,1,-7), BinNum(+1,4,-5).ulp
    assert_equal BinNum(+1,1,-5), BinNum(+1,2**4-1,-5).ulp
    assert_equal BinNum(+1,1,-7), BinNum(+1,2**4-1,-7).ulp
    assert_equal BinNum(+1,1,-5), BinNum(+1,4*(2**4-1),-7).ulp
    assert_equal BinNum(+1,1,-7), BinNum(+1,4*(2**4-1),-9).ulp

    BinNum.context.exact = true
    assert BinNum(1).ulp.nan?, "No ulps can be computed in exact contexts"
    BinNum.context.traps[BinNum::InvalidOperation] = true
    assert_raise(BinNum::InvalidOperation) { BinNum(1).ulp }

  end


end