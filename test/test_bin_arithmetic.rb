require File.dirname(__FILE__) + '/helper.rb'
require File.dirname(__FILE__) + '/../lib/flt/float'

# These tests assume that Float arithmetic is correctly rounded
# Random tests using Float as a reference
class TestBinArithmetic < Test::Unit::TestCase

  def setup
    initialize_context
    srand 93831
    @test_float_data ||= Array.new(1000){random_num(Float)} + singular_nums(Float) # + special_nums(Float)
  end

  def test_addition
    float_emulation_context
    each_pair(@test_float_data) do |x, y|
      z = x + y
      assert_equal z, (BinNum(x)+BinNum(y)).to_f
    end
  end

  def test_subtraction
    float_emulation_context
    each_pair(@test_float_data) do |x, y|
      z = x - y
      assert_equal z, (BinNum(x)-BinNum(y)).to_f
    end
  end

  def test_multiplication
    float_emulation_context
    each_pair(@test_float_data) do |x, y|
      z = x * y
      assert_equal z, (BinNum(x)*BinNum(y)).to_f
    end
  end

  def test_division
    float_emulation_context
    each_pair(@test_float_data) do |x, y|
      # next if y.abs < Float::EPSILON*x.abs
      next if y.zero?
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
    @test_float_data.each do |x|
      x = x.abs
      z = Math.sqrt(x)
      assert_equal z, BinNum(x).sqrt.to_f
    end
  end

end
