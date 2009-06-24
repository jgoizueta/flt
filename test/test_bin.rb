require File.dirname(__FILE__) + '/helper.rb'

class TestBin < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_binfloat
    assert_equal 23.0, (BinFloat(20) + BinFloat(3)).to_f
    assert_equal 1.0/3, (BinFloat(1) / BinFloat(3)).to_f
    assert_equal Math.sqrt(2), BinFloat(2).sqrt.to_f
    assert_equal 9, BinFloat(345).number_of_digits
    assert_equal 0.1, BinFloat('0.1').to_f

    assert_equal 23.0, (BinFloat(20) + BinFloat(3))
    assert_equal 1.0/3, (BinFloat(1) / BinFloat(3))
    assert_equal Math.sqrt(2), BinFloat(2).sqrt
    assert_equal 0.1, BinFloat('0.1')
  end

end
