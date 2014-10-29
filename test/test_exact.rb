require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))


class TestExact < Test::Unit::TestCase


  def setup
    initialize_context
  end


  def test_exact_no_traps

    DecNum.context.exact = true
    DecNum.context.traps[DecNum::Inexact] = false

    assert_equal DecNum("9"*100+"E-50"), DecNum('1E50')-DecNum('1E-50')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(2),DecNum(6)/DecNum(3)
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('1.5'),DecNum(6)/DecNum(4)
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('15241578780673678546105778281054720515622620750190521'), DecNum('123456789123456789123456789')*DecNum('123456789123456789123456789')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(2), DecNum('4').sqrt
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(4), DecNum('16').sqrt
    assert !DecNum.context.flags[DecNum::Inexact]

    assert_equal DecNum('42398.78077199232'), DecNum('1.23456')*DecNum('34343.232222')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('12.369885'), DecNum('210.288045')/DecNum('17')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('25'),DecNum('125')/DecNum('5')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('12345678900000000000.1234567890'),DecNum('1234567890E10')+DecNum('1234567890E-10')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('39304'),DecNum('34').power(DecNum(3))
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('39.304'),DecNum('3.4').power(DecNum(3))
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('4'),DecNum('16').power(DecNum('0.5'))
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('4'),DecNum('10000.0').log10
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('-5'),DecNum('0.00001').log10
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum.infinity, DecNum.infinity.exp
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum.zero, DecNum.infinity(-1).exp
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(1), DecNum(0).exp
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum.infinity(-1), DecNum(0).ln
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum.infinity, DecNum.infinity.ln
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(0), DecNum(1).ln
    assert !DecNum.context.flags[DecNum::Inexact]


    assert((DecNum(1)/DecNum(3)).nan?)
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false
    assert((DecNum(18).power(DecNum('0.5'))).nan?)
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false
    assert((DecNum(18).power(DecNum('1.5'))).nan?)
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false
    assert DecNum(18).log10.nan?
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false
    assert DecNum(1).exp.nan?
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false
    assert DecNum('-1.2').exp.nan?
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false
    assert DecNum('1.1').ln.nan?
    assert DecNum.context.flags[DecNum::Inexact]
    DecNum.context.flags[DecNum::Inexact] = false

  end

  def test_exact_traps

    DecNum.context.exact = true

    assert_nothing_raised(DecNum::Inexact){ DecNum(6)/DecNum(4) }

    assert_equal DecNum("9"*100+"E-50"), DecNum('1E50')-DecNum('1E-50')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(2),DecNum(6)/DecNum(3)
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('1.5'),DecNum(6)/DecNum(4)
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('15241578780673678546105778281054720515622620750190521'), DecNum('123456789123456789123456789')*DecNum('123456789123456789123456789')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(2), DecNum('4').sqrt
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(4), DecNum('16').sqrt
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum.infinity, DecNum.infinity.exp
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum.zero, DecNum.infinity(-1).exp
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(1), DecNum(0).exp
    assert !DecNum.context.flags[DecNum::Inexact]

    assert_equal DecNum('42398.78077199232'), DecNum('1.23456')*DecNum('34343.232222')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('12.369885'), DecNum('210.288045')/DecNum('17')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('25'),DecNum('125')/DecNum('5')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('12345678900000000000.1234567890'),DecNum('1234567890E10')+DecNum('1234567890E-10')
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('39304'),DecNum('34').power(DecNum(3))
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('39.304'),DecNum('3.4').power(DecNum(3))
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('4'),DecNum('16').power(DecNum('0.5'))
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('4'),DecNum('10000.0').log10
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum('-5'),DecNum('0.00001').log10
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum.infinity(-1), DecNum(0).ln
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum.infinity, DecNum.infinity.ln
    assert !DecNum.context.flags[DecNum::Inexact]
    assert_equal DecNum(0), DecNum(1).ln
    assert !DecNum.context.flags[DecNum::Inexact]

    assert_raise(DecNum::Inexact){ DecNum(2).sqrt }
    assert_raise(DecNum::Inexact){ DecNum(1)/DecNum(3) }
    assert_raise(DecNum::Inexact){ DecNum(18).power(DecNum('0.5')) }
    assert_raise(DecNum::Inexact){ DecNum(18).power(DecNum('1.5')) }
    assert_raise(DecNum::Inexact){ DecNum(18).log10 }
    assert_raise(DecNum::Inexact){ DecNum(1).exp }
    assert_raise(DecNum::Inexact){ DecNum('1.2').exp }
    assert_raise(DecNum::Inexact){ DecNum('1.2').ln }

  end

  def test_exact_precision
    DecNum.context.precision = 10
    refute DecNum.context.exact?
    assert_equal 10, DecNum.context.precision
    DecNum.context(:exact => true) do
      assert DecNum.context.exact?
      assert_equal 0, DecNum.context.precision
    end
    refute DecNum.context.exact?
    assert_equal 10, DecNum.context.precision
    DecNum.context(:precision => :exact) do
      assert DecNum.context.exact?
      assert_equal 0, DecNum.context.precision
    end
    refute DecNum.context.exact?
    assert_equal 10, DecNum.context.precision
  end

end
