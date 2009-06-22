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



end