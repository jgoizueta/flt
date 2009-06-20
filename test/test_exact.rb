require File.dirname(__FILE__) + '/helper.rb'


class TestExact < Test::Unit::TestCase


  def setup
    initialize_context
  end


  def test_exact_no_traps

    Decimal.context.exact = true
    Decimal.context.traps[Decimal::Inexact] = false

    assert_equal Decimal("9"*100+"E-50"), Decimal('1E50')-Decimal('1E-50')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(2),Decimal(6)/Decimal(3)
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('1.5'),Decimal(6)/Decimal(4)
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('15241578780673678546105778281054720515622620750190521'), Decimal('123456789123456789123456789')*Decimal('123456789123456789123456789')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(2), Decimal('4').sqrt
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(4), Decimal('16').sqrt
    assert !Decimal.context.flags[Decimal::Inexact]

    assert_equal Decimal('42398.78077199232'), Decimal('1.23456')*Decimal('34343.232222')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('12.369885'), Decimal('210.288045')/Decimal('17')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('25'),Decimal('125')/Decimal('5')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('12345678900000000000.1234567890'),Decimal('1234567890E10')+Decimal('1234567890E-10')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('39304'),Decimal('34').power(Decimal(3))
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('39.304'),Decimal('3.4').power(Decimal(3))
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('4'),Decimal('16').power(Decimal('0.5'))
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('4'),Decimal('10000.0').log10
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('-5'),Decimal('0.00001').log10
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal.infinity, Decimal.infinity.exp
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal.zero, Decimal.infinity(-1).exp
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(1), Decimal(0).exp
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal.infinity(-1), Decimal(0).ln
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal.infinity, Decimal.infinity.ln
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(0), Decimal(1).ln
    assert !Decimal.context.flags[Decimal::Inexact]


    assert((Decimal(1)/Decimal(3)).nan?)
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false
    assert((Decimal(18).power(Decimal('0.5'))).nan?)
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false
    assert((Decimal(18).power(Decimal('1.5'))).nan?)
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false
    assert Decimal(18).log10.nan?
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false
    assert Decimal(1).exp.nan?
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false
    assert Decimal('-1.2').exp.nan?
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false
    assert Decimal('1.1').ln.nan?
    assert Decimal.context.flags[Decimal::Inexact]
    Decimal.context.flags[Decimal::Inexact] = false

  end

  def test_exact_traps

    Decimal.context.exact = true

    assert_nothing_raised(Decimal::Inexact){ Decimal(6)/Decimal(4) }

    assert_equal Decimal("9"*100+"E-50"), Decimal('1E50')-Decimal('1E-50')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(2),Decimal(6)/Decimal(3)
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('1.5'),Decimal(6)/Decimal(4)
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('15241578780673678546105778281054720515622620750190521'), Decimal('123456789123456789123456789')*Decimal('123456789123456789123456789')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(2), Decimal('4').sqrt
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(4), Decimal('16').sqrt
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal.infinity, Decimal.infinity.exp
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal.zero, Decimal.infinity(-1).exp
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(1), Decimal(0).exp
    assert !Decimal.context.flags[Decimal::Inexact]

    assert_equal Decimal('42398.78077199232'), Decimal('1.23456')*Decimal('34343.232222')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('12.369885'), Decimal('210.288045')/Decimal('17')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('25'),Decimal('125')/Decimal('5')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('12345678900000000000.1234567890'),Decimal('1234567890E10')+Decimal('1234567890E-10')
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('39304'),Decimal('34').power(Decimal(3))
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('39.304'),Decimal('3.4').power(Decimal(3))
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('4'),Decimal('16').power(Decimal('0.5'))
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('4'),Decimal('10000.0').log10
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal('-5'),Decimal('0.00001').log10
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal.infinity(-1), Decimal(0).ln
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal.infinity, Decimal.infinity.ln
    assert !Decimal.context.flags[Decimal::Inexact]
    assert_equal Decimal(0), Decimal(1).ln
    assert !Decimal.context.flags[Decimal::Inexact]

    assert_raise(Decimal::Inexact){ Decimal(2).sqrt }
    assert_raise(Decimal::Inexact){ Decimal(1)/Decimal(3) }
    assert_raise(Decimal::Inexact){ Decimal(18).power(Decimal('0.5')) }
    assert_raise(Decimal::Inexact){ Decimal(18).power(Decimal('1.5')) }
    assert_raise(Decimal::Inexact){ Decimal(18).log10 }
    assert_raise(Decimal::Inexact){ Decimal(1).exp }
    assert_raise(Decimal::Inexact){ Decimal('1.2').exp }
    assert_raise(Decimal::Inexact){ Decimal('1.2').ln }

  end

end
