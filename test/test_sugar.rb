require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))
require File.dirname(__FILE__) + '/../lib/flt/sugar'

class TestSugar < Test::Unit::TestCase

  def test_pseudo_literals
    assert_equal Flt::DecNum, 10._3223.class
    assert_equal Flt::DecNum('10.3223'), 10._3223
    assert_equal Flt::DecNum('3.01234567890123456789012345678901234567890123456789'),
                 3._01234567890123456789012345678901234567890123456789
    assert_equal Flt::DecNum('-3.01234567890123456789012345678901234567890123456789'),
                 -3._01234567890123456789012345678901234567890123456789
    assert_equal Flt::DecNum('123456789123.01234567890123456789012345678901234567890123456789'),
                 123456789123._01234567890123456789012345678901234567890123456789
    assert_equal Flt::DecNum('-123456789123.01234567890123456789012345678901234567890123456789'),
                 -123456789123._01234567890123456789012345678901234567890123456789
    assert_raise(NoMethodError){3._x}
    assert_raise(NoMethodError){3._3233x}
    assert_raise(NoMethodError){3._3233x34333}
    assert_raise(NoMethodError){3.__}
    assert_raise(NoMethodError){3._}
  end

end
