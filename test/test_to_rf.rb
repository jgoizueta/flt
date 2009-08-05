require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestToRF < Test::Unit::TestCase


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
  end

end