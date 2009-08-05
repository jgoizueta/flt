require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestCoercion < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_coerce
    assert_equal DecNum('7.1'), DecNum('0.1') + 7
    assert_equal DecNum('7.1'), 7 + DecNum('0.1')
    assert_equal DecNum('14'), DecNum(7) * 2
    assert_equal DecNum('14'), 2 * DecNum(7)

    assert_equal DecNum('7.1'), DecNum(7) + Rational(1,10)
    assert_equal DecNum('7.1'), Rational(1,10) + DecNum(7)
    assert_equal DecNum('1.4'), DecNum(7) * Rational(2,10)
    assert_equal DecNum('1.4'), Rational(2,10) * DecNum(7)
  end

end