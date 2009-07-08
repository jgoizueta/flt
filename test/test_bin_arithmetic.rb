require File.dirname(__FILE__) + '/helper.rb'

# These tests assume that Float arithmetic is correctly rounded
# Random tests using Float as a reference
class TestBinArithmetic < Test::Unit::TestCase

  def setup
    initialize_context
  end

  def test_addition
    float_emulation_context
    srand 93831
    1000.times do
      x = random_float
      y = random_float
      z = x + y
      assert_equal z, (BinNum(x)+BinNum(y)).to_f
    end
  end

  def test_subtraction
    float_emulation_context
    srand 93831
    1000.times do
      x = random_float
      y = random_float
      z = x - y
      assert_equal z, (BinNum(x)-BinNum(y)).to_f
    end
  end

  def test_multiplication
    float_emulation_context
    srand 93831
    1000.times do
      x = random_float
      y = random_float
      z = x * y
      assert_equal z, (BinNum(x)*BinNum(y)).to_f
    end
  end

  def test_division
    float_emulation_context
    srand 93831
    1000.times do
      x = random_float
      y = random_float
      # next if y.abs < Float::EPSILON*x.abs
      z = x / y
      if z != (BinNum(x)/BinNum(y)).to_f
        puts "x=#{float_split(x).inspect}"
        puts "y=#{float_split(y).inspect}"
        puts "z=#{float_split(z).inspect}"
        puts "->#{(BinNum(x)/BinNum(y)).split.inspect}"
      end
      assert_equal z, (BinNum(x)/BinNum(y)).to_f
    end
  end

  def test_sqrt
    float_emulation_context
    srand 93831
    1000.times do
      x = random_float.abs
      z = Math.sqrt(x)
      assert_equal z, BinNum(x).sqrt.to_f
    end
  end

end
