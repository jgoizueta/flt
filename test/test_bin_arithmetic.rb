require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

# These tests assume that Float arithmetic is correctly rounded
# Random tests using Float as a reference
class TestBinArithmetic < Test::Unit::TestCase

  def setup
    initialize_context
    srand 93831
    @test_float_data ||= Array.new(1000){random_num(Float)} + singular_nums(Float) # + special_nums(Float)
  end

  # TODO: some of these tests may fail under some OSs due to the rounding of subnormal results.
  #       On OSX, linux, etc. the rounding of subnormal Float results seems to be as performed by BinNum:
  #       as if the exact result is rounded to the number of bits of the subnormal result.
  #       But on Windows OSs (even under Cygwin) subnormal results seem to be rounded first to the
  #       full Float precision (53 bits).
  #       Consider avoid testing with subnormal results, at least on Winddows, or preparing test data,
  #       including results, in a reliable machine.

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
      # if z != (BinNum(x)/BinNum(y)).to_f
      #   puts "x=#{float_split(x).inspect}"
      #   puts "y=#{float_split(y).inspect}"
      #   puts "z=#{float_split(z).inspect}"
      #   puts "->#{(BinNum(x)/BinNum(y)).split.inspect}"
      # end
      assert_equal z, (BinNum(x)/BinNum(y)).to_f
    end
  end

  def test_power
    float_emulation_context
    each_pair(@test_float_data) do |x, y|
      next if x.zero? && y.zero?
      x = x.abs
      xx = BinNum(x)
      yy = BinNum(y)
      z = x**y
      zz = nil
      begin
        zz = xx**yy
      rescue=>err
        if err.is_a?(Num::Overflow)
          zz = BinNum.infinity
        else
          zz = err.to_s
        end
      end
      ok = true
      zzz = nil
      if zz != z
        # Math.power may not be accurate enough
        zzz = +BinNum.context(:precision=>512) { xx**yy }
        if zzz != zz
          ok = false
        end
      end
      assert ok, "#{x}**#{y} (#{Float.context.split(x).inspect}**#{Float.context.split(y).inspect}) Incorrect: #{zz.split.inspect} instead of #{zzz && zzz.split.inspect}"
    end
  end

  def test_sqrt
    float_emulation_context
    @test_float_data.each do |x|
      context = x.class.context
      x = context.abs(x)
      z = context.sqrt(x)
      assert_equal z, BinNum(x).sqrt.to_f
    end
  end

end
