require File.dirname(__FILE__) + '/helper.rb'


class TestExact < Test::Unit::TestCase


  def setup
    initialize_context
  end


  def test_exact

    Decimal.context.exact = true

    assert_equal Decimal("9"*100+"E-50"), Decimal('1E50')-Decimal('1E-50')
    assert_equal Decimal(2),Decimal(6)/Decimal(3)
    assert_equal Decimal('1.5'),Decimal(6)/Decimal(4)
    assert_equal Decimal('15241578780673678546105778281054720515622620750190521'), Decimal('123456789123456789123456789')*Decimal('123456789123456789123456789')
    assert_nothing_raised(Decimal::Inexact){ Decimal(6)/Decimal(4) }
    assert_raise(Decimal::Inexact){ Decimal(1)/Decimal(3) }
    # assert_raise(Decimal::Inexact){ Decimal(2).sqrt }

    assert_equal Decimal(2), Decimal('4').sqrt
    assert_equal Decimal(4), Decimal('16').sqrt
    assert_raise(Decimal::Inexact){ Decimal(2).sqrt }


  end


end
