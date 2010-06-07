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
    assert_raise(NoMethodError,NameError){3._x}
    assert_raise(NoMethodError,NameError){3._3233x}
    assert_raise(NoMethodError,NameError){3._3233x34333}
    assert_raise(NoMethodError,NameError){3.__}
    assert_raise(NoMethodError,NameError){3._}
    assert_equal Flt::DecNum, 10._32_23.class
    assert_equal Flt::DecNum('10.3223'), 10._32_23
    assert_equal Flt::DecNum('3.01234567890123456789012345678901234567890123456789'),
                 3._012345_678901_234567_890123_456789_012345_678901_234567_89
    assert_equal Flt::DecNum('-3.01234567890123456789012345678901234567890123456789'),
                 -3._012_345_678_901_234_567_890_123_456_789_012_345_678_901_234_567_89
    assert_equal Flt::DecNum('123456789123.01234567890123456789012345678901234567890123456789'),
                 123456789123._0123456789_0123456789_0123456789_0123456789_0123456789
    assert_equal Flt::DecNum('-123456789123.01234567890123456789012345678901234567890123456789'),
                 -123456789123._0123456789_0123456789_0123456789_0123456789_0123456789
    assert_equal Flt::DecNum('10.0'), 10._0
    assert_equal Flt::DecNum('10.000'), 10._000
    assert_equal Flt::DecNum('10.000000'), 10._000000
    assert_equal Flt::DecNum('10.000000'), 10._000_000
    assert_equal Flt::DecNum('100000.000001'), 100_000._000_001
  end

end
