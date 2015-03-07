require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestFloat < Test::Unit::TestCase

  def setup
    initialize_context
  end

  def test_sign
    assert_equal -1, Float.context.sign(-1.0)
    assert_equal -1, Float.context.sign(-100.0)
    assert_equal -1, Float.context.sign(-0.0)
    assert_equal -1, Float.context.sign(-Float::MIN)
    assert_equal -1, Float.context.sign(-Float::MAX)
    assert_equal -1, Float.context.sign(-Float::EPSILON)
    assert_equal -1, Float.context.sign(-Float::INFINITY)

    assert_equal +1, Float.context.sign(+1.0)
    assert_equal +1, Float.context.sign(+100.0)
    assert_equal +1, Float.context.sign(+0.0)
    assert_equal +1, Float.context.sign(Float::MIN)
    assert_equal +1, Float.context.sign(Float::MAX)
    assert_equal +1, Float.context.sign(Float::EPSILON)
    assert_equal +1, Float.context.sign(Float::INFINITY)

    assert_nil Float.context.sign(Float.context.nan)
  end

  def copy_sign
    assert_equal -1.23, BigDecimal.context.copy_sign(1.23, -1)
    assert_equal -1.23, BigDecimal.context.copy_sign(1.23, -10.0)
    assert_equal -1.23, BigDecimal.context.copy_sign(-1.23, -1)
    assert_equal -1.23, BigDecimal.context.copy_sign(-1.23, -10.0)
    assert_equal 1.23, BigDecimal.context.copy_sign(-1.23, +1)
    assert_equal 1.23, BigDecimal.context.copy_sign(-1.23, 10.0)
    assert_equal 1.23, BigDecimal.context.copy_sign(1.23, +1)
    assert_equal 1.23, BigDecimal.context.copy_sign(1.23, 10.0)
  end

end
