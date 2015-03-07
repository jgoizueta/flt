require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestBigDecimal < Test::Unit::TestCase

  def setup
    initialize_context
  end

  def test_sign
    assert_equal -1, BigDecimal.context.sign(BigDecimal('-1.0'))
    assert_equal -1, BigDecimal.context.sign(BigDecimal('-10.0'))
    assert_equal -1, BigDecimal.context.sign(BigDecimal('-10E50'))
    assert_equal -1, BigDecimal.context.sign(BigDecimal('-10E-50'))
    assert_equal -1, BigDecimal.context.sign(BigDecimal('-723'))
    assert_equal -1, BigDecimal.context.sign(BigDecimal('-0.0'))

    assert_equal +1, BigDecimal.context.sign(BigDecimal('+1.0'))
    assert_equal +1, BigDecimal.context.sign(BigDecimal('+10.0'))
    assert_equal +1, BigDecimal.context.sign(BigDecimal('+10E50'))
    assert_equal +1, BigDecimal.context.sign(BigDecimal('+10E-50'))
    assert_equal +1, BigDecimal.context.sign(BigDecimal('+723'))
    assert_equal +1, BigDecimal.context.sign(BigDecimal('0.0'))

    assert_nil BigDecimal.context.sign(BigDecimal.context.nan)
  end

  def copy_sign
    assert_equal -BigDecimal('1.23'), BigDecimal.context.copy_sign(BigDecimal('1.23'), -1)
    assert_equal -BigDecimal('1.23'), BigDecimal.context.copy_sign(BigDecimal('1.23'), BigDecimal('-10'))
    assert_equal -BigDecimal('1.23'), BigDecimal.context.copy_sign(BigDecimal('-1.23'), -1)
    assert_equal -BigDecimal('1.23'), BigDecimal.context.copy_sign(BigDecimal('-1.23'), BigDecimal('-10'))
    assert_equal BigDecimal('1.23'), BigDecimal.context.copy_sign(BigDecimal('-1.23'), +1)
    assert_equal BigDecimal('1.23'), BigDecimal.context.copy_sign(BigDecimal('-1.23'), BigDecimal('+10'))
    assert_equal BigDecimal('1.23'), BigDecimal.context.copy_sign(BigDecimal('1.23'), +1)
    assert_equal BigDecimal('1.23'), BigDecimal.context.copy_sign(BigDecimal('1.23'), BigDecimal('+10'))
  end

end
