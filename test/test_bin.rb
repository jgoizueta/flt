require File.dirname(__FILE__) + '/helper.rb'

class TestBin < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_binfloat
    BinFloat.context.precision = Float::MANT_DIG
    BinFloat.context.rounding = :half_even
    BinFloat.context.emin = Float::MIN_EXP-1
    BinFloat.context.emax = Float::MAX_EXP-1

    assert_equal 2, Float::RADIX

    assert_equal 23.0, (BinFloat(20) + BinFloat(3)).to_f
    assert_equal 1.0/3, (BinFloat(1) / BinFloat(3)).to_f
    assert_equal Math.sqrt(2), BinFloat(2).sqrt.to_f
    assert_equal 9, BinFloat(345).number_of_digits
    assert_equal 0.1, BinFloat('0.1').to_f

    assert_equal 23.0, (BinFloat(20) + BinFloat(3))
    assert_equal 1.0/3, (BinFloat(1) / BinFloat(3))
    assert_equal Math.sqrt(2), BinFloat(2).sqrt
    assert_equal 0.1, BinFloat('0.1')

    assert_equal Float::MAX, BinFloat.context.maximum_finite
    assert_equal Float::MIN, BinFloat.context.minimum_normal

    %w{
      0.12343749827397239423432
      0.123437
      0.123437E57
      0.1
      0.1111111111111111111111111
      0.1E56
      0.5 0.125 7333 0.126
      3423322.345
      1069756.78125
      106975678125E-5
      2.1E6
      3E20
    }.each do |n|
      assert_equal Float(n), BinFloat(n).to_f
    end

  end

  def test_text_to_float_rounding

    BinFloat.context.precision = 8
    BinFloat.context.rounding = :down
    assert_equal "11001100", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :floor
    assert_equal "11001100", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :ceiling
    assert_equal "11001100", BinFloat('-0.1').split[1].to_s(2)
    BinFloat.context.rounding = :down
    assert_equal "11001100", BinFloat('-0.1').split[1].to_s(2)

    BinFloat.context.rounding = :up
    assert_equal "11001101", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :ceiling
    assert_equal "11001101", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :floor
    assert_equal "11001101", BinFloat('-0.1').split[1].to_s(2)
    BinFloat.context.rounding = :up
    assert_equal "11001101", BinFloat('-0.1').split[1].to_s(2)

    BinFloat.context.rounding = :half_up
    assert_equal "11001101", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_down
    assert_equal "11001101", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_even
    assert_equal "11001101", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_up
    assert_equal "11001101", BinFloat('-0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_down
    assert_equal "11001101", BinFloat('-0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_even
    assert_equal "11001101", BinFloat('-0.1').split[1].to_s(2)

    BinFloat.context.rounding = :half_up
    assert_equal "10000001", BinFloat('128.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_down
    assert_equal "10000000", BinFloat('128.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_even
    assert_equal "10000000", BinFloat('128.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_up
    assert_equal "10000010", BinFloat('129.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_down
    assert_equal "10000001", BinFloat('129.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_even
    assert_equal "10000010", BinFloat('129.5').split[1].to_s(2)

    BinFloat.context.rounding = :half_up
    assert_equal "10000001", BinFloat('-128.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_down
    assert_equal "10000000", BinFloat('-128.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_even
    assert_equal "10000000", BinFloat('-128.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_up
    assert_equal "10000010", BinFloat('-129.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_down
    assert_equal "10000001", BinFloat('-129.5').split[1].to_s(2)
    BinFloat.context.rounding = :half_even
    assert_equal "10000010", BinFloat('-129.5').split[1].to_s(2)

    BinFloat.context.rounding = :up
    assert_equal "10000001", BinFloat('128.5').split[1].to_s(2)
    BinFloat.context.rounding = :down
    assert_equal "10000000", BinFloat('128.5').split[1].to_s(2)
    BinFloat.context.rounding = :ceiling
    assert_equal "10000001", BinFloat('128.5').split[1].to_s(2)
    BinFloat.context.rounding = :floor
    assert_equal "10000000", BinFloat('128.5').split[1].to_s(2)

    BinFloat.context.rounding = :up
    assert_equal "10000001", BinFloat('-128.5').split[1].to_s(2)
    BinFloat.context.rounding = :down
    assert_equal "10000000", BinFloat('-128.5').split[1].to_s(2)
    BinFloat.context.rounding = :ceiling
    assert_equal "10000000", BinFloat('-128.5').split[1].to_s(2)
    BinFloat.context.rounding = :floor
    assert_equal "10000001", BinFloat('-128.5').split[1].to_s(2)

    BinFloat.context.rounding = :up
    assert_equal "10000010", BinFloat('129.5').split[1].to_s(2)
    BinFloat.context.rounding = :down
    assert_equal "10000001", BinFloat('129.5').split[1].to_s(2)
    BinFloat.context.rounding = :ceiling
    assert_equal "10000010", BinFloat('129.5').split[1].to_s(2)
    BinFloat.context.rounding = :floor
    assert_equal "10000001", BinFloat('129.5').split[1].to_s(2)

    BinFloat.context.rounding = :up
    assert_equal "10000010", BinFloat('-129.5').split[1].to_s(2)
    BinFloat.context.rounding = :down
    assert_equal "10000001", BinFloat('-129.5').split[1].to_s(2)
    BinFloat.context.rounding = :ceiling
    assert_equal "10000001", BinFloat('-129.5').split[1].to_s(2)
    BinFloat.context.rounding = :floor
    assert_equal "10000010", BinFloat('-129.5').split[1].to_s(2)

    BinFloat.context.precision = 9
    BinFloat.context.rounding = :down
    assert_equal "110011001", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :floor
    assert_equal "110011001", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :ceiling
    assert_equal "110011001", BinFloat('-0.1').split[1].to_s(2)
    BinFloat.context.rounding = :down
    assert_equal "110011001", BinFloat('-0.1').split[1].to_s(2)

    BinFloat.context.rounding = :up
    assert_equal "110011010", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :ceiling
    assert_equal "110011010", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :floor
    assert_equal "110011010", BinFloat('-0.1').split[1].to_s(2)
    BinFloat.context.rounding = :up
    assert_equal "110011010", BinFloat('-0.1').split[1].to_s(2)

    BinFloat.context.rounding = :half_up
    assert_equal "110011010", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_down
    assert_equal "110011010", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_even
    assert_equal "110011010", BinFloat('0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_up
    assert_equal "110011010", BinFloat('-0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_down
    assert_equal "110011010", BinFloat('-0.1').split[1].to_s(2)
    BinFloat.context.rounding = :half_even
    assert_equal "110011010", BinFloat('-0.1').split[1].to_s(2)

  end

  def test_text_to_float_exact
    BinFloat.context.exact = :quiet
    %w{
      0.1
      0.12343749827397239423432
      0.123437
      0.1111111111111111111111111
      0.126
      3423322.345
    }.each do |n|
      BinFloat.context.flags[Num::Inexact] = false
      b = BinFloat(n)
      assert b.nan?, "BinFloat('#{n}') is NaN in exact precision mode"
      assert BinFloat.context.flags[Num::Inexact], "BinFloat('#{n}') sets Inexact flag"
    end
    %w{
      0.123437E57
      0.1E56
      0.5 0.125 7333
      1069756.78125
      106975678125E-5
      2.1E6
      3E20
    }.each do |n|
      BinFloat.context.flags[Num::Inexact] = false
      b = BinFloat(n)
      assert_equal Float(n), BinFloat(n)
      assert !b.nan?, "BinFloat('#{n}') is not NaN in exact precision mode"
      assert !BinFloat.context.flags[Num::Inexact], "BinFloat('#{n}') does not set Inexact flag"
    end
  end

end
