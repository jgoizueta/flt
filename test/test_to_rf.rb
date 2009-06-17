require File.dirname(__FILE__) + '/test_helper.rb'

class TestToRF < Test::Unit::TestCase


  def setup
    $implementations_to_test.each do |mod|
      initialize_context mod
    end
  end

  def test_to_r
    $implementations_to_test.each do |mod|
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
        d = mod::Decimal(n)
        assert d.to_r.is_a?(Rational)
        assert_equal r, d.to_r
      end
    end
  end

  def test_to_f
    $implementations_to_test.each do |mod|
      ['0.1', '-0.1', '0.0', '1234567.1234567', '-1234567.1234567', '1.234E7', '1.234E-7'].each do |n|
        f = Float(n)
        d = mod::Decimal(n)
        assert d.to_f.is_a?(Float)
        assert_equal f, d.to_f
      end
    end
  end

end