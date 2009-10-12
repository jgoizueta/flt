require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))
require File.dirname(__FILE__) + '/../lib/flt/math'

class TestTrig < Test::Unit::TestCase


  def setup
    @data12 = {}
    [:sin, :cos, :tan, :asin, :acos, :atan].each do |f|
      @data12[f] = File.read(File.join(File.dirname(__FILE__), "trigtest/#{f}12.txt")).to_a.map do |line|
        line.split.map{|x| Flt::DecNum(x)}
      end
    end
  end

  def check(f)
    DecNum.context(:precision=>12) do
      data = @data12[f]
      data.each do |x, result|
        assert_equal result, DecNum::Math.send(f, x), "#{f}(#{x})==#{result}"
      end
    end
  end

  def check_relaxed(f, ulps=2)
    DecNum.context(:precision=>12) do
      data = @data12[f]
      data.each do |x, result|
        y = DecNum::Math.send(f, x)
        err_ulps = (y-result).abs/result.ulp
        assert err_ulps<=ulps, "#{f}(#{x})==#{result} to within #{ulps} ulps; error: #{err_ulps} ulps (#{y})"
      end
    end
  end


  # def test_trig
  #   DecNum.context(:precision=>12) do
  #     @data12.keys.each do |f|
  #       data = @data12[f]
  #       data.each do |x, result|
  #         assert_equal result, DecNum::Math.send(f, x), "#{f}(#{x})==#{result}"
  #       end
  #     end
  #   end
  # end

  # separate tests per function

  def test_sin
    check_relaxed :sin
  end

  def test_cos
    check_relaxed :cos
  end

  def test_tan
    check_relaxed :tan
  end

  def test_asin
    check_relaxed :asin
  end

  def test_acos
    check_relaxed :acos
  end

  def test_atan
    check_relaxed :atan
  end

  def test_sin_strict
    check :sin
  end

  def test_cos_strict
    check :cos
  end

  def test_tan_strict
    check :tan
  end

  def test_asin_strict
    check :asin
  end

  def test_acos_strict
    check :acos
  end

  def test_atan_strict
    check :atan
  end



end
