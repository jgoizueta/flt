require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

module TestFunctions

  module_function

  def exp(x,c=nil)

    i, lasts, s, fact, num = 0, 0, 1, 1, 1
    DecNum.local_context(c) do
      # result context
      DecNum.local_context do |context|
        # working context
        context.precision += 2
        context.rounding = DecNum::ROUND_HALF_EVEN
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
    return DecNum(BigDecimal("NaN")) if x.infinite? || x.nan?
    y = nil
    ext = 2
    DecNum.local_context(c) do |context|
      n = (context.precision += ext)

      one  = DecNum("1")
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

        #d  = x1.divide(z,:precision=>m)
        context.precision = m
        d = x1/z
        context.precision = n

        y += d
      end
    end
    return +y
  end
end

def return_from_local_context
  DecNum.context do |local_context|
    local_context.precision += 2
    return
  end
end

class TestBasic < Test::Unit::TestCase


  def setup
    initialize_context
  end


  def test_basic

    DecNum.context.precision = 4
    assert_equal 4, DecNum.context.precision
    return_from_local_context
    assert_equal 4, DecNum.context.precision
    assert_equal DecNum("0.3333"), DecNum(1)/DecNum(3)
    DecNum.context.precision = 10
    assert_equal 10, DecNum.context.precision
    assert_equal DecNum("0.3333333333"), DecNum(1)/DecNum(3)
    DecNum.local_context {
      assert_equal 10, DecNum.context.precision
      DecNum.context.precision = 3
      assert_equal 3, DecNum.context.precision
      assert_equal DecNum("0.333"), DecNum(1)/DecNum(3)
    }
    assert_equal 10, DecNum.context.precision
    assert_equal "0.3333333333", (DecNum(1)/DecNum(3)).to_s
    assert_equal DecNum("0.3333333333"), DecNum(1)/DecNum(3)

    DecNum.local_context(:precision=>4) {
      assert_equal 4, DecNum.context.precision
    }
    assert_equal 10, DecNum.context.precision

    DecNum.context(:precision=>4) {
      assert_equal 4, DecNum.context.precision
    }
    assert_equal 10, DecNum.context.precision

    DecNum.context(:extra_precision=>4) {
      assert_equal 14, DecNum.context.precision
    }
    assert_equal 10, DecNum.context.precision

    DecNum.local_context(DecNum::BasicContext) {
      assert_equal :half_up, DecNum.context.rounding
      assert_equal 9, DecNum.context.precision
    }
    assert_equal :half_even, DecNum.context.rounding
    assert_equal 10, DecNum.context.precision

    DecNum.context(DecNum::BasicContext) {
      assert_equal :half_up, DecNum.context.rounding
      assert_equal 9, DecNum.context.precision
    }
    assert_equal :half_even, DecNum.context.rounding
    assert_equal 10, DecNum.context.precision

    DecNum.local_context(DecNum::BasicContext, :precision=>4) {
      assert_equal :half_up, DecNum.context.rounding
      assert_equal 4, DecNum.context.precision
    }
    assert_equal :half_even, DecNum.context.rounding
    assert_equal 10, DecNum.context.precision

    DecNum.context(DecNum::BasicContext, :precision=>4) {
      assert_equal :half_up, DecNum.context.rounding
      assert_equal 4, DecNum.context.precision
    }
    assert_equal :half_even, DecNum.context.rounding
    assert_equal 10, DecNum.context.precision


    assert_equal DecNum("0."+"3"*100), DecNum(1)./(DecNum(3),DecNum.Context(:precision=>100))
    assert_equal 10, DecNum.context.precision
    assert_equal DecNum("0.33"), DecNum(1).divide(DecNum(3),DecNum.Context(:precision=>2))
    assert_equal DecNum("0.3333333333"), DecNum(1)/DecNum(3)

    assert_equal DecNum("11.0"), DecNum(11).abs
    assert_equal DecNum("11.0"), DecNum(-11).abs
    assert_equal DecNum("-11.0"), -DecNum(11)

    assert_equal [-11,0], DecNum("-11").to_int_scale

    assert_equal [-110,-1], DecNum("-11.0").to_int_scale
    assert_equal [-11,-1], DecNum("-1.1").to_int_scale
    assert_equal [-110,0], DecNum("-110").to_int_scale
    assert_equal [110,-1], DecNum("11.0").to_int_scale
    assert_equal [11,-1], DecNum("1.1").to_int_scale
    assert_equal [110,0], DecNum("110").to_int_scale

    assert_equal [-11,0], DecNum("-11.0").reduce.to_int_scale
    assert_equal [-11,-1], DecNum("-1.1").reduce.to_int_scale
    assert_equal [-11,1], DecNum("-110").reduce.to_int_scale
    assert_equal [11,0], DecNum("11.0").reduce.to_int_scale
    assert_equal [11,-1], DecNum("1.1").reduce.to_int_scale
    assert_equal [11,1], DecNum("110").reduce.to_int_scale


    assert_equal DecNum('2.1'), DecNum('2.1').remainder(DecNum('3'))
    assert_equal DecNum('-2.1'), DecNum('-2.1').remainder(DecNum('3'))
    assert_equal DecNum('2.1'), DecNum('2.1').remainder(DecNum('-3'))
    assert_equal DecNum('-2.1'), DecNum('-2.1').remainder(DecNum('-3'))
    assert_equal DecNum('1'), DecNum('10').remainder(DecNum('3'))
    assert_equal DecNum('-1'), DecNum('-10').remainder(DecNum('3'))
    assert_equal DecNum('1'), DecNum('10').remainder(DecNum('-3'))
    assert_equal DecNum('-1'), DecNum('-10').remainder(DecNum('-3'))
    assert_equal DecNum('0.2'), DecNum('10.2').remainder(DecNum('1'))
    assert_equal DecNum('0.1'), DecNum('10').remainder(DecNum('0.3'))
    assert_equal DecNum('1.0'), DecNum('3.6').remainder(DecNum('1.3'))
    assert_equal DecNum('2'), DecNum('2').remainder(DecNum('3'))
    assert_equal DecNum('1'), DecNum('10').remainder(DecNum('3'))
    assert_equal DecNum('.1'), DecNum('1').remainder(DecNum('0.3'))

    assert_equal DecNum('0'), DecNum('2.1').divide_int(DecNum('3'))
    assert_equal DecNum('0'), DecNum('-2.1').divide_int(DecNum('3'))
    assert_equal DecNum('0'), DecNum('2.1').divide_int(DecNum('-3'))
    assert_equal DecNum('0'), DecNum('-2.1').divide_int(DecNum('-3'))
    assert_equal DecNum('3'), DecNum('10').divide_int(DecNum('3'))
    assert_equal DecNum('-3'), DecNum('-10').divide_int(DecNum('3'))
    assert_equal DecNum('-3'), DecNum('10').divide_int(DecNum('-3'))
    assert_equal DecNum('3'), DecNum('-10').divide_int(DecNum('-3'))
    assert_equal DecNum('10'), DecNum('10.2').divide_int(DecNum('1'))
    assert_equal DecNum('33'), DecNum('10').divide_int(DecNum('0.3'))
    assert_equal DecNum('2'), DecNum('3.6').divide_int(DecNum('1.3'))
    assert_equal DecNum('0'), DecNum('2').divide_int(DecNum('3'))
    assert_equal DecNum('3'), DecNum('10').divide_int(DecNum('3'))
    assert_equal DecNum('3'), DecNum('1').divide_int(DecNum('0.3'))

    assert_equal DecNum('2.1'), DecNum('2.1').modulo(DecNum('3'))
    assert_equal DecNum('0.9'), DecNum('-2.1').modulo(DecNum('3'))
    assert_equal DecNum('-0.9'), DecNum('2.1').modulo(DecNum('-3'))
    assert_equal DecNum('-2.1'), DecNum('-2.1').modulo(DecNum('-3'))
    assert_equal DecNum('1'), DecNum('10').modulo(DecNum('3'))
    assert_equal DecNum('2'), DecNum('-10').modulo(DecNum('3'))
    assert_equal DecNum('-2'), DecNum('10').modulo(DecNum('-3'))
    assert_equal DecNum('-1'), DecNum('-10').modulo(DecNum('-3'))
    assert_equal DecNum('0.2'), DecNum('10.2').modulo(DecNum('1'))
    assert_equal DecNum('0.1'), DecNum('10').modulo(DecNum('0.3'))
    assert_equal DecNum('1.0'), DecNum('3.6').modulo(DecNum('1.3'))
    assert_equal DecNum('2'), DecNum('2').modulo(DecNum('3'))
    assert_equal DecNum('1'), DecNum('10').modulo(DecNum('3'))
    assert_equal DecNum('.1'), DecNum('1').modulo(DecNum('0.3'))

    assert_equal DecNum('0'), DecNum('2.1').div(DecNum('3'))
    assert_equal DecNum('-1'), DecNum('-2.1').div(DecNum('3'))
    assert_equal DecNum('-1'), DecNum('2.1').div(DecNum('-3'))
    assert_equal DecNum('0'), DecNum('-2.1').div(DecNum('-3'))
    assert_equal DecNum('3'), DecNum('10').div(DecNum('3'))
    assert_equal DecNum('-4'), DecNum('-10').div(DecNum('3'))
    assert_equal DecNum('-4'), DecNum('10').div(DecNum('-3'))
    assert_equal DecNum('3'), DecNum('-10').div(DecNum('-3'))
    assert_equal DecNum('10'), DecNum('10.2').div(DecNum('1'))
    assert_equal DecNum('33'), DecNum('10').div(DecNum('0.3'))
    assert_equal DecNum('2'), DecNum('3.6').div(DecNum('1.3'))
    assert_equal DecNum('0'), DecNum('2').div(DecNum('3'))
    assert_equal DecNum('3'), DecNum('10').div(DecNum('3'))
    assert_equal DecNum('3'), DecNum('1').div(DecNum('0.3'))

    assert_equal DecNum('-0.9'), DecNum('2.1').remainder_near(DecNum('3'))
    assert_equal DecNum('-2'), DecNum('10').remainder_near(DecNum('6'))
    assert_equal DecNum('1'), DecNum('10').remainder_near(DecNum('3'))
    assert_equal DecNum('-1'), DecNum('-10').remainder_near(DecNum('3'))
    assert_equal DecNum('0.2'), DecNum('10.2').remainder_near(DecNum('1'))
    assert_equal DecNum('0.1'), DecNum('10').remainder_near(DecNum('0.3'))
    assert_equal DecNum('-0.3'), DecNum('3.6').remainder_near(DecNum('1.3'))


   assert_equal 2, DecNum('123.4567').adjusted_exponent
   assert_equal 2, DecNum('123.45670').adjusted_exponent
   assert_equal 2, DecNum.context.scaleb(DecNum('1.2345670'),2).adjusted_exponent
   assert_equal 2, DecNum.context.scaleb(DecNum('1.2345670'),DecNum('2')).adjusted_exponent
   assert_equal DecNum(2), DecNum.context.logb(DecNum('123.4567'))
   assert_equal DecNum(2), DecNum.context.logb(DecNum('123.45670'))
   assert_equal 3, DecNum('123.4567').fractional_exponent
   assert_equal 3, DecNum('123.45670').fractional_exponent

   assert_equal(-7, DecNum.context.normalized_integral_exponent(DecNum('123.4567')))
   assert_equal(1234567000, DecNum.context.normalized_integral_significand(DecNum('123.4567')))

   assert_equal 7, DecNum('123.4567').number_of_digits
   assert_equal 8, DecNum('123.45670').number_of_digits
   assert_equal 7, DecNum('123.45670').reduce.number_of_digits

   assert_equal 1234567, DecNum('123.4567').integral_significand
   assert_equal 12345670, DecNum('123.45670').integral_significand
   assert_equal 1234567, DecNum('123.45670').reduce.integral_significand

   assert_equal 2, DecNum('-123.4567').adjusted_exponent
   assert_equal 2, DecNum('-123.45670').adjusted_exponent
   assert_equal 2, DecNum.context.scaleb(DecNum('-1.2345670'),2).adjusted_exponent
   assert_equal 2, DecNum.context.scaleb(DecNum('-1.2345670'),DecNum('2')).adjusted_exponent
   assert_equal DecNum(2), DecNum.context.logb(DecNum('-123.4567'))
   assert_equal DecNum(2), DecNum.context.logb(DecNum('-123.45670'))
   assert_equal 3, DecNum('-123.4567').fractional_exponent
   assert_equal 3, DecNum('-123.45670').fractional_exponent

   assert_equal(-7, DecNum.context.normalized_integral_exponent(DecNum('-123.4567')))
   assert_equal(1234567000, DecNum.context.normalized_integral_significand(DecNum('-123.4567')))

   assert_equal 7, DecNum('-123.4567').number_of_digits
   # assert_equal 9, DecNum('123.45670').number_of_digits # not with BigDecimal
   assert_equal 7, DecNum('-123.45670').reduce.number_of_digits

   assert_equal(1234567, DecNum('-123.4567').integral_significand)
   #assert_equal(12345670, DecNum('-123.45670').integral_significand) # not with BigDecimal
   assert_equal(1234567, DecNum('-123.45670').reduce.integral_significand)

   x = DecNum('123.4567')
   assert_equal x, DecNum(x.integral_significand)*10**x.integral_exponent
   assert_equal x, DecNum(DecNum.context.normalized_integral_significand(x))*10**DecNum.context.normalized_integral_exponent(x)

   assert_equal x, DecNum.context.scaleb(x.integral_significand, x.integral_exponent)
   assert_equal x, DecNum.context.scaleb(DecNum.context.normalized_integral_significand(x),DecNum.context.normalized_integral_exponent(x))

   x = DecNum('-123.4567')
   assert_equal x.abs, DecNum(x.integral_significand)*10**x.integral_exponent
   assert_equal x.abs, DecNum(DecNum.context.normalized_integral_significand(x))*10**DecNum.context.normalized_integral_exponent(x)

   assert_equal x.abs, DecNum.context.scaleb(x.integral_significand, x.integral_exponent)
   assert_equal x.abs, DecNum.context.scaleb(DecNum.context.normalized_integral_significand(x),DecNum.context.normalized_integral_exponent(x))

   DecNum.context.precision = 3
   DecNum.context.rounding = :half_up
   assert_equal DecNum("100"), (+DecNum('100.4'))
   assert_equal DecNum("101"), (+DecNum('101.4'))
   assert_equal DecNum("101"), (+DecNum('100.5'))
   assert_equal DecNum("102"), (+DecNum('101.5'))
   assert_equal DecNum("-101"), (+DecNum('-100.5'))
   assert_equal DecNum("-102"), (+DecNum('-101.5'))
   assert_equal DecNum("-100"), (+DecNum('-100.4'))
   assert_equal DecNum("-101"), (+DecNum('-101.4'))
   DecNum.context.rounding = :half_even
   assert_equal DecNum("100"), (+DecNum('100.5'))
   assert_equal DecNum("101"), (+DecNum('100.51'))
   assert_equal DecNum("101"), (+DecNum('100.6'))
   assert_equal DecNum("102"), (+DecNum('101.5'))
   assert_equal DecNum("101"), (+DecNum('101.4'))
   assert_equal DecNum("-100"), (+DecNum('-100.5'))
   assert_equal DecNum("-102"), (+DecNum('-101.5'))
   assert_equal DecNum("-101"), (+DecNum('-101.4'))
   DecNum.context.rounding = :half_down
   assert_equal DecNum("100"), (+DecNum('100.5'))
   assert_equal DecNum("101"), (+DecNum('101.5'))
   assert_equal DecNum("-100"), (+DecNum('-100.5'))
   assert_equal DecNum("-101"), (+DecNum('-101.5'))
   DecNum.context.rounding = :down
   assert_equal DecNum("100"), (+DecNum('100.9'))
   assert_equal DecNum("101"), (+DecNum('101.9'))
   assert_equal DecNum("-100"), (+DecNum('-100.9'))
   assert_equal DecNum("-101"), (+DecNum('-101.9'))
   DecNum.context.rounding = :up
   assert_equal DecNum("101"), (+DecNum('100.1'))
   assert_equal DecNum("102"), (+DecNum('101.1'))
   assert_equal DecNum("-101"), (+DecNum('-100.1'))
   assert_equal DecNum("-102"), (+DecNum('-101.1'))
   DecNum.context.rounding = :floor
   assert_equal DecNum("100"), (+DecNum('100.9'))
   assert_equal DecNum("101"), (+DecNum('101.9'))
   assert_equal DecNum("-101"), (+DecNum('-100.9'))
   assert_equal DecNum("-102"), (+DecNum('-101.9'))
   DecNum.context.rounding = :ceiling
   assert_equal DecNum("101"), (+DecNum('100.1'))
   assert_equal DecNum("102"), (+DecNum('101.1'))
   assert_equal DecNum("-100"), (+DecNum('-100.1'))
   assert_equal DecNum("-101"), (+DecNum('-101.1'))

  end

  def test_exp
    DecNum.context.precision = 100
    DecNum.context.rounding = :half_even
    e_100 = "2.718281828459045235360287471352662497757247093699959574966967627724076630353547594571382178525166427"
    assert_equal e_100, TestFunctions.exp(DecNum(1)).to_s
    assert_equal DecNum(e_100), TestFunctions.exp(DecNum(1))
    assert_equal e_100, TestFunctions.exp1(DecNum(1)).to_s
    assert_equal DecNum(e_100), TestFunctions.exp1(DecNum(1))
  end

  def test_special
    nan = DecNum(0)/DecNum(0)
    inf_pos = DecNum(1)/DecNum(0)
    inf_neg = DecNum(-1)/DecNum(0)
    zero_pos = DecNum(0)
    zero_neg = DecNum('-0')
    pos = DecNum(1)
    neg = DecNum(-1)

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

    #assert nan.sign.nil?
    assert_equal(+1, inf_pos.sign)
    assert_equal(-1, inf_neg.sign)
    assert_equal(+1, zero_pos.sign)
    assert_equal(-1, zero_neg.sign)
    assert_equal(+1, pos.sign)
    assert_equal(-1, neg.sign)
  end

  def test_context_parameters
    #DecNum.context = DecNum.Context
    DecNum.context.precision = 3
    DecNum.context.rounding = :half_even
    x = DecNum(1)
    y = DecNum(3)
    assert_equal DecNum('0.333'), x.divide(y)
    assert_equal DecNum('0.3333'), x.divide(y, DecNum.Context(:precision=>4))
    assert_equal DecNum('0.333'), x.divide(y)
    assert_equal DecNum('0.33333'), x.divide(y, :precision=>5)
  end

  def test_integer

    %w{ 0 0E10 0E-10 12.0 12 120E-1 12.1E10 }.each do |x|
      assert DecNum(x).integral?, "DecNum('#{x}').integral?"
    end

    [12, Rational(6,2)].each do |x|
      assert DecNum(x).integral?, "DecNum(#{x}).integral?"
    end

    %w{ NaN Inf 12.1 121E-1 }.each do |x|
      assert !DecNum(x).integral?, "!DecNum('#{x}').integral?"
    end

    [ Rational(121,10) ].each do |x|
      assert !DecNum(x).integral?, "!DecNum(#{x}).integral?"
    end

  end

end
