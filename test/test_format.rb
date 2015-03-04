require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestFormat < Test::Unit::TestCase

  def setup
    initialize_context
  end

  def test_same_base_format
    value = DecNum('0.100', :free)
    assert_equal '0.100', value.to_s
    assert_equal '0.1', value.to_s(:simplified => true)
    assert_equal '0.1000', value.to_s(:all_digits => true)

    value = DecNum('1.00', :free)
    assert_equal '1.00', value.to_s
    assert_equal '1', value.to_s(:simplified => true)
    assert_equal '1.000', value.to_s(:all_digits => true)

    value = DecNum('0.101', :free)
    assert_equal '0.101', value.to_s
    assert_equal '0.101', value.to_s(:simplified => true)
    assert_equal '0.1010', value.to_s(:all_digits => true)

    value = DecNum('0.100', :free)
    assert_equal '0.100', value.to_s
    assert_equal '0.1', value.to_s(:simplified => true)
    assert_equal '0.1000', value.to_s(:all_digits => true)

    value = DecNum('0.100E-10', :free)
    assert_equal '1.00E-11', value.to_s
    assert_equal '1E-11', value.to_s(:simplified => true)
    assert_equal '1.000E-11', value.to_s(:all_digits => true)

    value = DecNum('0.100E+10', :free)
    assert_equal '1.00E+9', value.to_s
    assert_equal '1E+9', value.to_s(:simplified => true)
    assert_equal '1.000E+9', value.to_s(:all_digits => true)
  end

  def test_mixed_base_format
    value = BinNum.context(precision: 6){ BinNum('0.1', :fixed)}
    assert_equal '0.099609375', value.to_s(:exact => true)
    assert_equal '0.1', value.to_s
    assert_equal '0.100', value.to_s(:all_digits => true)
    assert_equal '0.099609375', value.to_s(:all_digits => true, :rounding => :down)
  end

end
