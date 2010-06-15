require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))
require File.dirname(__FILE__) + '/../lib/flt/math'

# TODO: Currently tests only with 12 digits of precision; test with more precision.

class TestTrig < Test::Unit::TestCase


  def setup
    @data = {}
    Dir[File.join(File.dirname(__FILE__), "trigtest/*.txt")].each do |fn|
      if File.basename(fn) =~ /\A([a-z]+)(\d+)_(\d+)_([a-z]+)\.txt\Z/
        method = $1.to_sym
        radix = $2.to_i
        prec = $3.to_i
        angle = $4.to_sym
        @data[radix] ||= {}
        @data[radix][angle] ||= {}
        @data[radix][angle][prec] ||= {}
        @data[radix][angle][prec][method] = File.read(fn).split("\n").map do |line|
          line.split.map{|x| Flt::DecNum(x)}
        end
      end
    end
  end

  def check(f, radix=10, angle=:rad)
    class_num = Num[radix]
    @data[radix][angle].keys.each do |prec|
      class_num.context(:precision=>prec, :angle=>angle) do
        class_num.context.traps[DecNum::DivisionByZero] = false
        data = @data[radix][angle][prec][f]
        data.each do |x, result|
          assert_equal result, class_num::Math.send(f, x), "#{f}(#{x})==#{result} [#{radix} #{angle} #{prec}]"
        end
      end
    end
  end

  def check_relaxed(f, radix=10, angle=:rad, ulps=1)
    class_num = Num[radix]
    @data[radix][angle].keys.each do |prec|
      class_num.context(:precision=>prec, :angle=>angle) do
        class_num.context.traps[DecNum::DivisionByZero] = false
        data = @data[radix][angle][prec][f]
        data.each do |x, result|
          y = class_num::Math.send(f, x)
          if result.special?
            assert_equal result, y, "#{f}(#{x})==#{result} [#{radix} #{angle} #{prec}]"
          else
            err_ulps = (y-result).abs/result.ulp
            assert err_ulps<=ulps, "#{f}(#{x})==#{result} to within #{ulps} ulps; error: #{err_ulps} ulps (#{y}) [#{radix} #{angle} #{prec}]"
          end
        end
      end
    end
  end

  def test_sin
    check :sin, 10, :rad
  end

  def test_cos
    check :cos, 10, :rad
  end

  def test_tan
    check_relaxed :tan, 10, :rad
  end

  def test_asin
    check_relaxed :asin, 10, :rad
  end

  def test_acos
    check_relaxed :acos, 10, :rad
  end

  def test_atan
    check_relaxed :atan, 10, :rad
  end

  def test_sin_deg
    check_relaxed :sin, 10, :deg
  end

  def test_cos_deg
    check_relaxed :cos, 10, :deg
  end

  def test_tan_deg
    check_relaxed :tan, 10, :deg
  end

  def test_asin_deg
    check_relaxed :asin, 10, :deg
  end

  def test_acos_deg
    check_relaxed :acos, 10, :deg
  end

  def test_atan_deg
    check_relaxed :atan, 10, :deg
  end

end
