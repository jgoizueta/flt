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

  def test_sci_format
    assert_equal '1.23E-3', DecNum('0.00123').to_s(format: :sci)
    assert_equal '1.23E-6', DecNum('0.00000123').to_s(format: :sci)
    assert_equal '1.23E-9', DecNum('0.00000000123').to_s(format: :sci)
    assert_equal '1.23E-12', DecNum('0.00000000000123').to_s(format: :sci)
    n = 1000
    assert_equal "1.23E#{-n+2}", DecNum("123E-#{n}").to_s(format: :sci)
    assert_equal "1.23E+#{n+2}", DecNum("123E#{n}").to_s(format: :sci)
  end

  def test_fix_format
    assert_equal '0.00123', DecNum('0.00123').to_s(format: :fix)
    assert_equal '0.00000123', DecNum('0.00000123').to_s(format: :fix)
    assert_equal '0.00000000123', DecNum('0.00000000123').to_s(format: :fix)
    assert_equal '0.00000000000123', DecNum('0.00000000000123').to_s(format: :fix)
    n = 1000
    assert_equal '0.'+'0'*(n-3)+'123', DecNum("123E-#{n}").to_s(format: :fix)
    assert_equal '123'+'0'*n, DecNum("123E#{n}").to_s(format: :fix)
  end

  def test_auto_format
    assert_equal '0.00123', DecNum('0.00123').to_s(format: :auto)
    assert_equal '0.00000123', DecNum('0.00000123').to_s(format: :auto)
    assert_equal '1.23E-7', DecNum('0.000000123').to_s(format: :auto)
    assert_equal '1.23E-9', DecNum('0.00000000123').to_s(format: :auto)
    assert_equal '1.23E-12', DecNum('0.00000000000123').to_s(format: :auto)
    n = 1000
    assert_equal "1.23E#{-n+2}", DecNum("123E-#{n}").to_s(format: :auto)
    assert_equal "1.23E+#{n+2}", DecNum("123E#{n}").to_s(format: :auto)
  end

end
