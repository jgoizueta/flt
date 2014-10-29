require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))


class TestBaseDigits < Test::Unit::TestCase


  def test_number_of_digits_in_other_base

    assert_equal Float::DIG, Float.context.representable_digits(10)
    assert_equal Float::DECIMAL_DIG, Float.context.necessary_digits(10)

    if defined?(BinNum::FloatContext)
      assert_equal Float::DIG, BinNum::FloatContext.representable_digits(10)
      assert_equal Float::DECIMAL_DIG, BinNum::FloatContext.necessary_digits(10)
    end

    assert_equal  6, BinNum::IEEESingleContext.representable_digits(10)
    assert_equal  9, BinNum::IEEESingleContext.necessary_digits(10)

    assert_equal 15, BinNum::IEEEDoubleContext.representable_digits(10)
    assert_equal 17, BinNum::IEEEDoubleContext.necessary_digits(10)

    assert_equal 18, BinNum::IEEEExtendedContext.representable_digits(10)
    assert_equal 21, BinNum::IEEEExtendedContext.necessary_digits(10)


    [10,15,20,100].each do |precision|
      DecNum.context(:precision => precision) do
        assert_equal precision, DecNum.context.representable_digits(10)
        assert_equal precision, DecNum.context.necessary_digits(10)
      end

      BinNum.context(:precision => precision) do
        assert_equal precision, BinNum.context.representable_digits(2)
        assert_equal precision, BinNum.context.necessary_digits(2)
      end
    end

    DecNum.context(:exact => true) do
      assert_nil DecNum.context.representable_digits(10)
      assert_nil DecNum.context.necessary_digits(10)
      assert_nil DecNum.context.representable_digits(2)
      assert_nil DecNum.context.necessary_digits(2)
    end

    BinNum.context(:exact => true) do
      assert_nil BinNum.context.representable_digits(10)
      assert_nil BinNum.context.necessary_digits(10)
      assert_nil BinNum.context.representable_digits(2)
      assert_nil BinNum.context.necessary_digits(2)
    end

  end

end
