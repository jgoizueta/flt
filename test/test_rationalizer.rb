require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

require 'flt/math'
require 'bigdecimal/math'

if RUBY_VERSION>="1.9.2"
  BgMth = BigMath
else
  module BgMth
    extend BigMath
  end
end

class TestRationalizer < Test::Unit::TestCase

  def setup
    initialize_context
    Flt::DecNum.context = Flt::DecNum::DefaultContext
    @data = float_data
  end

  R = Flt::Support::Rationalizer

  def test_basic_rationalizer
    # basic Rationalizer tests
    r = R.new
    assert_equal [13,10], r.rationalize(1.3)
    assert_equal [13,10], R.max_denominator(1.3,10)
    assert_equal [13,10], R.max_denominator(BigDecimal('1.3'),10)
    assert_equal [1,3], R.max_denominator(1.0/3,10)
    assert_equal [1,3], R.max_denominator(BigDecimal('1')/3,10)
    assert_equal [13,10], R.max_denominator(Flt.DecNum('1.3'),10)
    assert_equal [1,3], R.max_denominator(Flt.DecNum('1')/3,10)

    # basic tests of Float.context.rationalize
    assert_equal Rational(1,3), Float.context.rationalize(1.0/3.0)
    assert_equal Rational(2,3), Float.context.rationalize(2.0/3.0)
    assert_equal Rational(1237,1234), Float.context.rationalize(1237.0/1234.0)
    assert_equal Rational(89,217), Float.context.rationalize(89.0/217.0)

    # rationalization of Floats using a tolerance
    t = Flt.Tolerance(1e-15/2,:floating)
    assert_equal Rational(540429, 12500), Float.context.rationalize(43.23432, t, :strict)
    assert_equal Rational(6636649, 206596193), Float.context.rationalize(0.032123772, t, :strict)
    assert_equal Rational(280943, 2500000), Float.context.rationalize(0.1123772, t, :strict)
    assert_equal Rational(39152929, 12500), Float.context.rationalize(3132.23432, t, :strict)
    assert_equal Rational(24166771439, 104063), Float.context.rationalize(232232.123223432, t, :strict)
    assert_equal Rational(792766404965, 637), Float.context.rationalize(1244531247.98273123, t, :strict)

    # @data.each do |x|
    #  assert t.eq?(x, Float.context.rationalize(x,t).to_f), "out of tolerance: #{x.inspect}"
    # end

    # rationalization with maximum denominator
    assert_equal Rational(9441014047197, 7586), Float.context.rationalize(1244531247.98273123, 10000)
    assert_equal Rational(11747130449709, 9439), BigDecimal.context.rationalize(BigDecimal('1244531247.982731230'), 10000)

    assert_equal Rational(11747130449709, 9439), Flt::DecNum.context.rationalize(Flt::DecNum('1244531247.982731230'), 10000)

    # approximate a value in [0.671,0.672];
    #  Float
    assert_equal [43,64], R[Flt.Tolerance(0.0005)].rationalize(0.6715)
    assert_equal [43,64], R[Rational(5,10000)].rationalize(0.6715)
    # BinNum
    assert_equal [43,64], R[Flt.Tolerance(Flt.BinNum('0.0005'))].rationalize(Flt::BinNum('0.6715'))
    assert_equal [43,64], R[Flt.Tolerance(Rational(5,10000))].rationalize(Flt::BinNum('0.6715'))
    #  BigDecimal
    assert_equal [43,64], R[Flt.Tolerance('0.0005')].rationalize(BigDecimal('0.6715'))
    assert_equal [43,64], R[Rational(5,10000)].rationalize(BigDecimal('0.6715'))
    # DecNum
    assert_equal [43,64], R[Flt.Tolerance(Flt.DecNum('0.0005'))].rationalize(Flt::DecNum('0.6715'))
    assert_equal [43,64], R[Flt.Tolerance(Rational(5,10000))].rationalize(Flt::DecNum('0.6715'))
    #
    assert_equal Rational(43,64), Float.context.rationalize(0.6715, 0.0005)
    assert_equal Rational(43,64), Float.context.rationalize(0.6715, Rational(5,10000))
    assert_equal Rational(47,70), Float.context.rationalize(0.6715, 70)
    assert_equal Rational(45,67), Float.context.rationalize(0.6715, 69)
    assert_equal Rational(2,3), Float.context.rationalize(0.6715, 10)

    # some PI tests
    assert_equal Rational(899125804609,286200632530), BigDecimal.context.rationalize(BgMth.PI(64), Flt.Tolerance(Flt.DecNum('261E-24')))
    assert_equal Rational(899125804609,286200632530), BigDecimal.context.rationalize(BgMth.PI(64), Flt.Tolerance(Flt.DecNum('261E-24')))
    assert_equal Rational(899125804609,286200632530), BigDecimal.context.rationalize(BgMth.PI(64), Flt.DecNum('261E-24'))
    assert_equal Rational(899125804609,286200632530), BigDecimal.context.rationalize(BgMth.PI(64), 261E-24)

    assert_equal Rational(899125804609,286200632530), Flt::DecNum.context.rationalize(Flt::DecNum::Math.pi(64), Flt.Tolerance(Flt.DecNum('261E-24')))
    assert_equal Rational(899125804609,286200632530), Flt::DecNum.context.rationalize(Flt::DecNum::Math.pi(64), Flt.Tolerance(Flt.DecNum('261E-24')))
    assert_equal Rational(899125804609,286200632530), Flt::DecNum.context.rationalize(Flt::DecNum::Math.pi(64), Flt.DecNum('261E-24'))
    assert_equal Rational(899125804609,286200632530), Flt::DecNum.context.rationalize(Flt::DecNum::Math.pi(64), 261E-24)

    # DecNum tests
    #t = Flt.Tolerance(Flt.DecNum('1e-15'),:floating)
    t = Flt.Tolerance(20, :sig_decimals)
    @data.each do |x|
      x = Flt.BinNum(x).to_decimal_exact
      next if x.special?
      q = x.rationalize(t)
      assert t.eq?(x, Flt.DecNum(q)), "out of tolerance: #{x.inspect} #{Flt.DecNum(q)}"
    end

    # Flt tests
    #t = Flt.Tolerance(Flt.DecNum('1e-15'),:floating)
    t = Flt.Tolerance(20,:sig_decimals)
    @data.each do |x|
      x = Flt.BinNum(x)
      next if x.special?
      q = x.rationalize(t)
      assert t.eq?(x, Flt.BinNum(q)), "out of tolerance: #{x.inspect} #{Flt.BinNum(q)}"
    end
  end

  def test_compare_algorithms
    r = R[Flt.Tolerance(1e-5,:floating)]
    @data.each do |x|
      q1 = r.rationalize_Knuth(x)
      q2 = r.rationalize_Horn(x)
      q3 = r.rationalize_HornHutchins(x)
      #q4 = r.rationalize_KnuthB(x)
      q1 = [-q1[0],-q1[1]] if q1[1] < 0
      q2 = [-q2[0],-q2[1]] if q2[1] < 0
      q3 = [-q3[0],-q3[1]] if q3[1] < 0
      assert_equal q1, q2
      assert_equal q1, q3
      #assert_equal q1, q4
    end
    r = R[Flt.Tolerance(:epsilon)]
    @data.each do |x|
      q1 = r.rationalize_Knuth(x)
      q2 = r.rationalize_Horn(x)
      q3 = r.rationalize_HornHutchins(x)
      q1 = [-q1[0],-q1[1]] if q1[1] < 0
      q2 = [-q2[0],-q2[1]] if q2[1] < 0
      q3 = [-q3[0],-q3[1]] if q3[1] < 0
      #q4 = r.rationalize_KnuthB(x)
      assert_equal q1, q2
      assert_equal q1, q3
      #assert_equal q1, q4
    end
  end

end
