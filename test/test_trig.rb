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
    check :sin
  end

  def test_cos
    check :cos
  end

  def test_tan
    check :tan
  end

  def test_asin
    check :asin
  end

  def test_acos
    check :acos
  end

  def test_atan
    check :atan
  end




end
