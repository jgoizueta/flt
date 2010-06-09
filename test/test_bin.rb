require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestBin < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_binfloat
    assert_equal 2, Float::RADIX

    BinNum.context = BinNum::FloatContext
    assert_equal 23.0, (BinNum(20) + BinNum(3)).to_f
    assert_equal 1.0/3, (BinNum(1) / BinNum(3)).to_f
    assert_equal Math.sqrt(2), BinNum(2).sqrt.to_f
    assert_equal 9, BinNum(345).number_of_digits
    assert_equal 0.1, BinNum('0.1', :fixed).to_f

    assert_equal 23.0, (BinNum(20) + BinNum(3))
    assert_equal 1.0/3, (BinNum(1) / BinNum(3))
    assert_equal Math.sqrt(2), BinNum(2).sqrt
    assert_equal 0.1, BinNum('0.1', :fixed)

    assert_equal Float::MAX, BinNum.context.maximum_finite
    assert_equal Float::MIN_N, BinNum.context.minimum_normal

    numbers = %w{
      0.123437
      0.123437E57
      0.1
      0.1111111111111111111111111
      0.1E56
      0.5 0.125 7333 0.126
      1069756.78125
      106975678125E-5
      2.1E6
      3E20
    }
    numbers += %w{0.12343749827397239423432 3423322.345} if Flt.float_correctly_rounded?

    numbers.each do |n|
      assert_equal Float(n), BinNum(n, :fixed).to_f
    end

  end

  def test_text_to_float_rounding

    BinNum.context.precision = 8
    BinNum.context.rounding = :down
    assert_equal "11001100", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :floor
    assert_equal "11001100", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :ceiling
    assert_equal "11001100", BinNum('-0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :down
    assert_equal "11001100", BinNum('-0.1', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :up
    assert_equal "11001101", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :ceiling
    assert_equal "11001101", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :floor
    assert_equal "11001101", BinNum('-0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :up
    assert_equal "11001101", BinNum('-0.1', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :half_up
    assert_equal "11001101", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_down
    assert_equal "11001101", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_even
    assert_equal "11001101", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_up
    assert_equal "11001101", BinNum('-0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_down
    assert_equal "11001101", BinNum('-0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_even
    assert_equal "11001101", BinNum('-0.1', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :half_up
    assert_equal "10000001", BinNum('128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_down
    assert_equal "10000000", BinNum('128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_even
    assert_equal "10000000", BinNum('128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_up
    assert_equal "10000010", BinNum('129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_down
    assert_equal "10000001", BinNum('129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_even
    assert_equal "10000010", BinNum('129.5', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :half_up
    assert_equal "10000001", BinNum('-128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_down
    assert_equal "10000000", BinNum('-128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_even
    assert_equal "10000000", BinNum('-128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_up
    assert_equal "10000010", BinNum('-129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_down
    assert_equal "10000001", BinNum('-129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_even
    assert_equal "10000010", BinNum('-129.5', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :up
    assert_equal "10000001", BinNum('128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :down
    assert_equal "10000000", BinNum('128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :ceiling
    assert_equal "10000001", BinNum('128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :floor
    assert_equal "10000000", BinNum('128.5', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :up
    assert_equal "10000001", BinNum('-128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :down
    assert_equal "10000000", BinNum('-128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :ceiling
    assert_equal "10000000", BinNum('-128.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :floor
    assert_equal "10000001", BinNum('-128.5', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :up
    assert_equal "10000010", BinNum('129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :down
    assert_equal "10000001", BinNum('129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :ceiling
    assert_equal "10000010", BinNum('129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :floor
    assert_equal "10000001", BinNum('129.5', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :up
    assert_equal "10000010", BinNum('-129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :down
    assert_equal "10000001", BinNum('-129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :ceiling
    assert_equal "10000001", BinNum('-129.5', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :floor
    assert_equal "10000010", BinNum('-129.5', :fixed).split[1].to_s(2)

    BinNum.context.precision = 9
    BinNum.context.rounding = :down
    assert_equal "110011001", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :floor
    assert_equal "110011001", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :ceiling
    assert_equal "110011001", BinNum('-0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :down
    assert_equal "110011001", BinNum('-0.1', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :up
    assert_equal "110011010", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :ceiling
    assert_equal "110011010", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :floor
    assert_equal "110011010", BinNum('-0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :up
    assert_equal "110011010", BinNum('-0.1', :fixed).split[1].to_s(2)

    BinNum.context.rounding = :half_up
    assert_equal "110011010", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_down
    assert_equal "110011010", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_even
    assert_equal "110011010", BinNum('0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_up
    assert_equal "110011010", BinNum('-0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_down
    assert_equal "110011010", BinNum('-0.1', :fixed).split[1].to_s(2)
    BinNum.context.rounding = :half_even
    assert_equal "110011010", BinNum('-0.1', :fixed).split[1].to_s(2)

  end

  def test_text_to_float_exact
    BinNum.context.exact = :quiet
    %w{
      0.1
      0.12343749827397239423432
      0.123437
      0.1111111111111111111111111
      0.126
      3423322.345
    }.each do |n|
      BinNum.context.flags[Num::Inexact] = false
      b = BinNum(n, :fixed)
      assert b.nan?, "BinNum('#{n}') is NaN in exact precision mode"
      assert BinNum.context.flags[Num::Inexact], "BinNum('#{n}') sets Inexact flag"
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
      BinNum.context.flags[Num::Inexact] = false
      b = BinNum(n, :fixed)
      assert_equal Float(n), BinNum(n, :fixed).to_f
      assert !b.nan?, "BinNum('#{n}') is not NaN in exact precision mode"
      assert !BinNum.context.flags[Num::Inexact], "BinNum('#{n}') does not set Inexact flag"
    end
  end

  def test_float_to_bin_float
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
      1.1
      1.1E31
      -1.1E31
      0.0
      -0.0
    }.each do |n|
      f = Float(n)
      assert_equal f, BinNum(f).to_f
    end
    nan = 0.0/0.0
    inf = 1.0/0.0
    minf = -1.0/0.0
    assert_equal(-1, BinNum(-0.0).sign)
    assert_equal(-1, BinNum(minf).sign)
    assert_equal(+1, BinNum(0.0).sign)
    assert_equal(+1, BinNum(inf).sign)
    assert BinNum(nan).nan?, "Float NaN to BinNum produces NaN"
    assert BinNum(inf).infinite?, "Float +Infinity to BinNum produces Infinite"
    assert BinNum(minf).infinite?, "Float -Infinity to BinNum produces Infinite"
  end

end
