require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))
require File.dirname(__FILE__) + '/../lib/flt/math'

class TestTrig < Test::Unit::TestCase


  def setup
    @data = {}
    Dir[File.join(File.dirname(__FILE__), "trigtest/*.txt")].each do |fn|
      if File.basename(fn) =~ /\A([a-z]+)(\d+)_(\d+)_([a-z]+)\.txt\Z/
        method = $1.to_sym
        radix = $2.to_i
        prec = $3.to_i
        angle = $4.to_sym
        num_class = Flt::Num[radix]
        @data[radix] ||= {}
        @data[radix][angle] ||= {}
        @data[radix][angle][prec] ||= {}
        @data[radix][angle][prec][method] = File.read(fn).split("\n").map do |line|
          line.split.map{|x| num_class.Num(x, :base=>radix)}
        end
      end
    end
    BinNum.context = BinNum::IEEEDoubleContext
  end

  def check(f, radix=10, angle=:rad)
    class_num = Num[radix]
    @data[radix][angle].keys.each do |prec|
      class_num.context(:precision=>prec, :angle=>angle) do
        class_num.context.traps[DecNum::DivisionByZero] = false
        data = @data[radix][angle][prec][f]
        data.each do |x, result|
          assert_equal result, class_num::Math.send(f, x), "#{f}(#{x})==#{result}\ninput: #{x.to_int_scale.inspect} [#{radix} #{angle} #{prec}]"
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
        unless data.nil?
          data.each do |x, result|
            y = class_num::Math.send(f, x)
            if result.special?
              assert_equal result, y, "#{f}(#{x})==#{result} [#{radix} #{angle} #{prec}]"
            else
              err_ulps = (y-result).abs/result.ulp
              assert err_ulps<=ulps, "#{f}(#{x})==#{result} to within #{ulps} ulps; error: #{err_ulps} ulps (#{y})\ninput: #{x.to_int_scale.inspect} [#{radix} #{angle} #{prec}]"
            end
          end
        else
          STDERR.puts "Missing data for radix #{radix.inspect} angle #{angle.inspect} prec #{prec.inspect} #{f.inspect}"
        end
      end
    end
  end

  def check_bin(f)
    class_num = BinNum
    @data[2][:rad].keys.each do |prec|
      class_num.context do
        #class_num.context.traps[DecNum::DivisionByZero] = false
        data = @data[2][:rad][53][f]
        data.each do |x, result|
          x = class_num.Num(x)
          result = ::Math.send(f, x.to_f)
          assert_equal result, class_num::Math.send(f, x), "#{f}(#{x})==#{result} [bin]"
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

  def test_sin_bin
    check_relaxed :sin, 2, :rad
  end

  def test_cos_bin
    check_relaxed :cos, 2, :rad
  end

  def test_tan_bin
    check_relaxed :tan, 2, :rad
  end

  def test_asin_bin
    check_relaxed :asin, 2, :rad
  end

  def test_acos_bin
    check_relaxed :acos, 2, :rad
  end

  def test_atan_bin
    check_relaxed :atan, 2, :rad
  end

  # def test_bin
  #   check_bin :sin
  # end

end
