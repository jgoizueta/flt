require File.dirname(__FILE__) + '/test_helper.rb'

def exp(x,c=nil)
  i, lasts, s, fact, num = 0, 0, 1, 1, 1
  Decimal.local_context(c) do |context|   
    # result context    
    Decimal.local_context do |context|    
      # working context      
      context.precision += 2
      context.rounding = Decimal::ROUND_HALF_EVEN
      while s != lasts
        lasts = s    
        i += 1
        fact *= i
        num *= x     
        s += num / fact   
      end
    end
    +s
  end
end

  def exp1(x, c=nil)
    return Decimal(BigDecimal("NaN")) if x.infinite? || x.nan?
    y = nil
    ext = 2
    Decimal.local_context(c) do |context|
      n = (context.precision += ext)
    
      one  = Decimal("1")
      x1 = one
      y  = one
      d  = y
      z  = one
      i  = 0
      while d.nonzero? && ((m = n - (y.fractional_exponent - d.fractional_exponent).abs) > 0)
        m = ext if m < ext
        x1  *= x
        i += 1
        z *= i
        
        #d  = x1.divide(z,Decimal::Context(:precision=>m))
        context.precision = m
        d = x1/z
        context.precision = n
        
        y += d
      end
    end
    return +y
  end
  


class TestBasic < Test::Unit::TestCase
  
  def test_basic
    Decimal.context.precision = 4
    assert_equal 4, Decimal.context.precision
    assert_equal Decimal("0.3333"), Decimal(1)/Decimal(3)
    Decimal.context.precision = 10
    assert_equal 10, Decimal.context.precision
    assert_equal Decimal("0.3333333333"), Decimal(1)/Decimal(3)
    Decimal.local_context {
      assert_equal 10, Decimal.context.precision
      Decimal.context.precision = 3
      assert_equal 3, Decimal.context.precision
      assert_equal Decimal("0.333"), Decimal(1)/Decimal(3)
    }
    assert_equal 10, Decimal.context.precision
    assert_equal "0.3333333333", (Decimal(1)/Decimal(3)).to_s
    assert_equal Decimal("0.3333333333"), Decimal(1)/Decimal(3)

    Decimal.local_context(:precision=>4) {
      assert_equal 4, Decimal.context.precision
    }
    assert_equal 10, Decimal.context.precision


    assert_equal Decimal("0."+"3"*100), Decimal(1)./(Decimal(3),Decimal.Context(:precision=>100))
    assert_equal 10, Decimal.context.precision
    assert_equal Decimal("0.33"), Decimal(1).divide(Decimal(3),Decimal.Context(:precision=>2))
    assert_equal Decimal("0.3333333333"), Decimal(1)/Decimal(3)

    assert_equal Decimal("11.0"), Decimal(11).abs
    assert_equal Decimal("11.0"), Decimal(-11).abs
    assert_equal Decimal("-11.0"), -Decimal(11)
    
    assert_equal [-11,0], Decimal("-11.0").to_int_scale
    assert_equal [-11,-1], Decimal("-1.1").to_int_scale
    assert_equal [-11,1], Decimal("-110").to_int_scale
    assert_equal [11,0], Decimal("11.0").to_int_scale
    assert_equal [11,-1], Decimal("1.1").to_int_scale
    assert_equal [11,1], Decimal("110").to_int_scale
    
    assert_equal Decimal('2.1'), Decimal('2.1').remainder(Decimal('3'))
    assert_equal Decimal('-2.1'), Decimal('-2.1').remainder(Decimal('3'))
    assert_equal Decimal('2.1'), Decimal('2.1').remainder(Decimal('-3'))
    assert_equal Decimal('-2.1'), Decimal('-2.1').remainder(Decimal('-3'))    
    assert_equal Decimal('1'), Decimal('10').remainder(Decimal('3'))
    assert_equal Decimal('-1'), Decimal('-10').remainder(Decimal('3'))
    assert_equal Decimal('1'), Decimal('10').remainder(Decimal('-3'))
    assert_equal Decimal('-1'), Decimal('-10').remainder(Decimal('-3'))    
    assert_equal Decimal('0.2'), Decimal('10.2').remainder(Decimal('1'))
    assert_equal Decimal('0.1'), Decimal('10').remainder(Decimal('0.3'))
    assert_equal Decimal('1.0'), Decimal('3.6').remainder(Decimal('1.3'))
    assert_equal Decimal('2'), Decimal('2').remainder(Decimal('3'))
    assert_equal Decimal('1'), Decimal('10').remainder(Decimal('3'))
    assert_equal Decimal('.1'), Decimal('1').remainder(Decimal('0.3'))
    
    assert_equal Decimal('0'), Decimal('2.1').divide_int(Decimal('3'))
    assert_equal Decimal('0'), Decimal('-2.1').divide_int(Decimal('3'))
    assert_equal Decimal('0'), Decimal('2.1').divide_int(Decimal('-3'))
    assert_equal Decimal('0'), Decimal('-2.1').divide_int(Decimal('-3'))    
    assert_equal Decimal('3'), Decimal('10').divide_int(Decimal('3'))
    assert_equal Decimal('-3'), Decimal('-10').divide_int(Decimal('3'))
    assert_equal Decimal('-3'), Decimal('10').divide_int(Decimal('-3'))
    assert_equal Decimal('3'), Decimal('-10').divide_int(Decimal('-3'))    
    assert_equal Decimal('10'), Decimal('10.2').divide_int(Decimal('1'))
    assert_equal Decimal('33'), Decimal('10').divide_int(Decimal('0.3'))
    assert_equal Decimal('2'), Decimal('3.6').divide_int(Decimal('1.3'))    
    assert_equal Decimal('0'), Decimal('2').divide_int(Decimal('3'))
    assert_equal Decimal('3'), Decimal('10').divide_int(Decimal('3'))
    assert_equal Decimal('3'), Decimal('1').divide_int(Decimal('0.3'))

    assert_equal Decimal('2.1'), Decimal('2.1').modulo(Decimal('3'))
    assert_equal Decimal('0.9'), Decimal('-2.1').modulo(Decimal('3'))
    assert_equal Decimal('-0.9'), Decimal('2.1').modulo(Decimal('-3'))
    assert_equal Decimal('-2.1'), Decimal('-2.1').modulo(Decimal('-3'))    
    assert_equal Decimal('1'), Decimal('10').modulo(Decimal('3'))
    assert_equal Decimal('2'), Decimal('-10').modulo(Decimal('3'))
    assert_equal Decimal('-2'), Decimal('10').modulo(Decimal('-3'))
    assert_equal Decimal('-1'), Decimal('-10').modulo(Decimal('-3'))    
    assert_equal Decimal('0.2'), Decimal('10.2').modulo(Decimal('1'))
    assert_equal Decimal('0.1'), Decimal('10').modulo(Decimal('0.3'))
    assert_equal Decimal('1.0'), Decimal('3.6').modulo(Decimal('1.3'))
    assert_equal Decimal('2'), Decimal('2').modulo(Decimal('3'))
    assert_equal Decimal('1'), Decimal('10').modulo(Decimal('3'))
    assert_equal Decimal('.1'), Decimal('1').modulo(Decimal('0.3'))
    
    assert_equal Decimal('0'), Decimal('2.1').div(Decimal('3'))
    assert_equal Decimal('-1'), Decimal('-2.1').div(Decimal('3'))
    assert_equal Decimal('-1'), Decimal('2.1').div(Decimal('-3'))
    assert_equal Decimal('0'), Decimal('-2.1').div(Decimal('-3'))    
    assert_equal Decimal('3'), Decimal('10').div(Decimal('3'))
    assert_equal Decimal('-4'), Decimal('-10').div(Decimal('3'))
    assert_equal Decimal('-4'), Decimal('10').div(Decimal('-3'))
    assert_equal Decimal('3'), Decimal('-10').div(Decimal('-3'))    
    assert_equal Decimal('10'), Decimal('10.2').div(Decimal('1'))
    assert_equal Decimal('33'), Decimal('10').div(Decimal('0.3'))
    assert_equal Decimal('2'), Decimal('3.6').div(Decimal('1.3'))    
    assert_equal Decimal('0'), Decimal('2').div(Decimal('3'))
    assert_equal Decimal('3'), Decimal('10').div(Decimal('3'))
    assert_equal Decimal('3'), Decimal('1').div(Decimal('0.3'))

    assert_equal Decimal('-0.9'), Decimal('2.1').remainder_near(Decimal('3'))
    assert_equal Decimal('-2'), Decimal('10').remainder_near(Decimal('6'))
    assert_equal Decimal('1'), Decimal('10').remainder_near(Decimal('3'))
    assert_equal Decimal('-1'), Decimal('-10').remainder_near(Decimal('3'))
    assert_equal Decimal('0.2'), Decimal('10.2').remainder_near(Decimal('1'))
    assert_equal Decimal('0.1'), Decimal('10').remainder_near(Decimal('0.3'))
    assert_equal Decimal('-0.3'), Decimal('3.6').remainder_near(Decimal('1.3'))


   assert_equal 2, Decimal('123.4567').adjusted_exponent
   assert_equal 2, Decimal('123.45670').adjusted_exponent
   assert_equal 2, Decimal.context.scaleb('1.2345670',2).adjusted_exponent
   assert_equal 2, Decimal.context.scaleb('1.2345670',Decimal('2')).adjusted_exponent   
   assert_equal Decimal(2), Decimal.context.logb(Decimal('123.4567'))   
   assert_equal Decimal(2), Decimal.context.logb(Decimal('123.45670'))   
   assert_equal 3, Decimal('123.4567').fractional_exponent
   assert_equal 3, Decimal('123.45670').fractional_exponent

   assert_equal(-7, Decimal.context.normalized_integral_exponent(Decimal('123.4567')))
   assert_equal(1234567000, Decimal.context.normalized_integral_significand(Decimal('123.4567')))
   
   assert_equal 7, Decimal('123.4567').number_of_digits
   # assert_equal 9, Decimal('123.45670').number_of_digits # not with BigDecimal
   assert_equal 7, Decimal('123.45670').reduce.number_of_digits
   
   assert_equal 1234567, Decimal('123.4567').integral_significand
   #assert_equal 12345670, Decimal('123.45670').integral_significand # not with BigDecimal
   assert_equal 1234567, Decimal('123.45670').reduce.integral_significand

   assert_equal 2, Decimal('-123.4567').adjusted_exponent
   assert_equal 2, Decimal('-123.45670').adjusted_exponent
   assert_equal 2, Decimal.context.scaleb('-1.2345670',2).adjusted_exponent
   assert_equal 2, Decimal.context.scaleb('-1.2345670',Decimal('2')).adjusted_exponent   
   assert_equal Decimal(2), Decimal.context.logb(Decimal('-123.4567'))   
   assert_equal Decimal(2), Decimal.context.logb(Decimal('-123.45670'))   
   assert_equal 3, Decimal('-123.4567').fractional_exponent
   assert_equal 3, Decimal('-123.45670').fractional_exponent

   assert_equal(-7, Decimal.context.normalized_integral_exponent(Decimal('-123.4567')))
   assert_equal(1234567000, Decimal.context.normalized_integral_significand(Decimal('-123.4567')))
   
   assert_equal 7, Decimal('-123.4567').number_of_digits
   # assert_equal 9, Decimal('123.45670').number_of_digits # not with BigDecimal
   assert_equal 7, Decimal('-123.45670').reduce.number_of_digits

   assert_equal(1234567, Decimal('-123.4567').integral_significand)
   #assert_equal(12345670, Decimal('-123.45670').integral_significand) # not with BigDecimal
   assert_equal(1234567, Decimal('-123.45670').reduce.integral_significand)
   
   x = Decimal('123.4567')
   assert_equal x, Decimal(x.integral_significand)*10**x.integral_exponent
   assert_equal x, Decimal(Decimal.context.normalized_integral_significand(x))*10**Decimal.context.normalized_integral_exponent(x)
   
   assert_equal x, Decimal.context.scaleb(x.integral_significand, x.integral_exponent)
   assert_equal x, Decimal.context.scaleb(Decimal.context.normalized_integral_significand(x),Decimal.context.normalized_integral_exponent(x))
   
   x = Decimal('-123.4567')
   assert_equal x.abs, Decimal(x.integral_significand)*10**x.integral_exponent
   assert_equal x.abs, Decimal(Decimal.context.normalized_integral_significand(x))*10**Decimal.context.normalized_integral_exponent(x)
   
   assert_equal x.abs, Decimal.context.scaleb(x.integral_significand, x.integral_exponent)
   assert_equal x.abs, Decimal.context.scaleb(Decimal.context.normalized_integral_significand(x),Decimal.context.normalized_integral_exponent(x))
   
   
  end
  
  def test_exp
    Decimal.context.precision = 100
    e_100 = "2.718281828459045235360287471352662497757247093699959574966967627724076630353547594571382178525166427"
    assert_equal e_100, exp(Decimal(1)).to_s
    assert_equal Decimal(e_100), exp(Decimal(1))
    assert_equal e_100, exp1(Decimal(1)).to_s
    assert_equal Decimal(e_100), exp1(Decimal(1))
  end
  
  def test_special
    nan = Decimal(0)/Decimal(0)
    inf_pos = Decimal(1)/Decimal(0)
    inf_neg = Decimal(-1)/Decimal(0)
    zero_pos = Decimal(0)
    zero_neg = Decimal('-0')
    pos = Decimal(1)
    neg = Decimal(-1)    
    
    assert nan.nan?
    assert nan.special?
    assert !nan.zero?
    assert !nan.finite?
    assert !nan.infinite?    
    assert inf_pos.infinite?
    assert !inf_pos.finite?
    assert !inf_pos.nan?
    assert inf_pos.special?
    assert inf_neg.infinite?
    assert !inf_neg.finite?
    assert !inf_neg.nan?
    assert inf_neg.special?
    assert zero_pos.finite?
    assert zero_neg.finite?
    assert zero_pos.zero?
    assert zero_neg.zero?
    assert !pos.zero?
    assert !neg.zero?
    assert pos.nonzero?
    assert neg.nonzero?
    
    assert nan.sign.nil?
    assert_equal(+1, inf_pos.sign)
    assert_equal(-1, inf_neg.sign)
    assert_equal(+1, zero_pos.sign)
    assert_equal(-1, zero_neg.sign)
    assert_equal(+1, pos.sign)
    assert_equal(-1, neg.sign)
  end
    
end
