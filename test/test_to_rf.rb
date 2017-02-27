require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestToRF < Minitest::Test


  def setup
    initialize_context
  end

  def test_to_r
    [
      [ '0', 0, 1 ],
      [ '1', 1, 1 ],
      [ '-1', -1, 1 ],
      [ '1234567.1234567', 12345671234567, 10000000 ],
      [ '-1234567.1234567', -12345671234567, 10000000 ],
      [ '0.200', 2, 10 ],
      [ '-0.200', -2, 10 ]
    ].each do |n, num, den|
      r = Rational(num,den)
      d = DecNum(n)
      assert d.to_r.is_a?(Rational)
      assert_equal r, d.to_r
    end
  end

  def test_to_f
    ['0.1', '-0.1', '0.0', '1234567.1234567', '-1234567.1234567', '1.234E7', '1.234E-7'].each do |n|
      f = Float(n)
      d = DecNum(n)
      assert d.to_f.is_a?(Float)
      assert_equal f, d.to_f
    end
    assert DecNum.nan.to_f.nan?
    assert DecNum.infinity.to_f.infinite?
    assert DecNum.infinity.to_f > 0
    assert DecNum.infinity(-1).to_f.infinite?
    assert DecNum.infinity(-1).to_f < 0
    assert 1.0/DecNum('-0').to_f < 0
    assert 1.0/DecNum('+0').to_f > 0

    data  = []
    [10, 100, 1000, 10000].each do |n_digits|
      data << DecNum('+0.'+'1'*n_digits)
      data << DecNum('-0.'+'1'*n_digits)
    end

    srand 1023022
    data = []
    DecNum.context(:precision=>15, :elimit=>90) do
      data += [DecNum('1.448997445238699'), DecNum('1E23'),DecNum('-6.22320623338259E+16'),
               DecNum('-3.83501075447972E-10'), DecNum('1.448997445238699')]
      data += %w{
        1E23
        1.448997445238699
        -6.22320623338259E+16
        -3.83501075447972E-10
        1.448997445238699
        1.23E-30
        1.23456789E-20
        1.23456789E-30
        1.234567890123456789
        0.9999999999999995559107901499
        0.9999999999999996114219413812
        0.9999999999999996669330926125
        0.9999999999999997224442438437
        0.9999999999999997779553950750
        0.9999999999999998334665463062
        0.9999999999999998889776975375
        0.9999999999999999444888487687
        1
        1.000000000000000111022302463
        1.000000000000000222044604925
        1.000000000000000333066907388
        1.000000000000000444089209850
        1.000000000000000555111512313
        1.000000000000000666133814775
        1.000000000000000777156117238
        1.000000000000000888178419700
      }.map{ |num| DecNum(num) }
      data += Array.new(10000){random_num(DecNum)}
    end

    assert_equal 2, Float::RADIX

    data.each do |x|
      expected = Flt::Num.convert_exact(x, 2, Flt::BinNum::FloatContext).to_f
      assert_equal expected, x.to_s.to_f

      relative_error_limit = Float::EPSILON
      # rel_err = (x.to_f - expected).abs/expected.abs
      assert  expected.abs*relative_error_limit > (x.to_f - expected).abs, "#{x.to_f} != #{expected} (#{x})"
    end
  end

  def test_to_f_bin
    BinNum.context(BinNum::FloatContext) do
      ['0.1', '-0.1', '0.0', '1234567.1234567', '-1234567.1234567', '1.234E7', '1.234E-7'].each do |n|
        f = Float(n)
        b = BinNum(n, :fixed)
        assert b.to_f.is_a?(Float)
        assert_equal f, b.to_f
      end
      assert BinNum.nan.to_f.nan?
      assert BinNum.infinity.to_f.infinite?
      assert BinNum.infinity.to_f > 0
      assert BinNum.infinity(-1).to_f.infinite?
      assert BinNum.infinity(-1).to_f < 0
      assert 1.0/BinNum('-0', :fixed).to_f < 0
      assert 1.0/BinNum('+0', :fixed).to_f > 0

      data  = []
      [10, 100, 1000, 10000].each do |n_digits|
        data << BinNum('+0.'+'1'*n_digits)
        data << BinNum('-0.'+'1'*n_digits)
      end

      srand 1023022
      data = []
        data += [BinNum('1.448997445238699', :fixed), BinNum('1E23', :fixed),BinNum('-6.22320623338259E+16', :fixed),
                BinNum('-3.83501075447972E-10', :fixed), BinNum('1.448997445238699', :fixed)]
        data += %w{
          1E23
          1.448997445238699
          -6.22320623338259E+16
          -3.83501075447972E-10
          1.448997445238699
          1.23E-30
          1.23456789E-20
          1.23456789E-30
          1.234567890123456789
          0.9999999999999995559107901499
          0.9999999999999996114219413812
          0.9999999999999996669330926125
          0.9999999999999997224442438437
          0.9999999999999997779553950750
          0.9999999999999998334665463062
          0.9999999999999998889776975375
          0.9999999999999999444888487687
          1
          1.000000000000000111022302463
          1.000000000000000222044604925
          1.000000000000000333066907388
          1.000000000000000444089209850
          1.000000000000000555111512313
          1.000000000000000666133814775
          1.000000000000000777156117238
          1.000000000000000888178419700
        }.map{ |num| BinNum(num, :fixed) }
        data += Array.new(10000){random_num(BinNum)}

      data.each do |x|
        expected = x.to_decimal_exact(exact: true).to_s.to_f
        assert_equal expected, x.to_f
      end
    end

  end


end