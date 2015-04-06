require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))


class TestNormalized < Test::Unit::TestCase

  include Flt

  def setup
    initialize_context
  end

  def test_giac_floating_point
    BinNum.context.precision = 48
    BinNum.context.rounding = :down
    BinNum.context.normalized = true
    x = (BinNum(4)/3-1)*3 - 1
    assert_equal [-1, 140737488355328, -93], x.split

    x = BinNum(11)/15
    assert_equal [1, 206414982921147, -48], x.split
    x *= BinNum('1E308')
    assert_equal [1, 229644291251027, 975], x.split
  end

  def test_normalized_context
    refute DecNum.context.normalized?
    DecNum.context(normalized: true) do
      assert DecNum.context.normalized?
      assert_equal [1, 1, -1], DecNum('0.1').split
      assert_equal [1, 100000000, -9], (+DecNum('0.1')).split
      assert_equal [1, 100000000, -9], (DecNum('0.1')+0).split
      assert_equal [1, 100000000, -9], (DecNum('0.1')/1).split
    end
    refute DecNum.context.normalized?
    assert_equal [1, 1, -1], DecNum('0.1').split
    assert_equal [1, 1, -1], (+DecNum('0.1')).split
    assert_equal [1, 1, -1], (DecNum('0.1')+0).split
    assert_equal [1, 1, -1], (DecNum('0.1')/1).split
    context = DecNum.context(normalized: true)
    assert context.normalized?
    assert_equal [1, 100000000, -9], context.plus(DecNum('0.1')).split
    assert_equal [1, 100000000, -9], context.add(DecNum('0.1'), 0).split
    assert_equal [1, 100000000, -9], context.divide(DecNum('0.1'), 1).split
    refute DecNum.context.normalized?
    assert_equal [1, 1, -1], DecNum('0.1').split
    assert_equal [1, 1, -1], (+DecNum('0.1')).split
    assert_equal [1, 1, -1], (DecNum('0.1')+0).split
    assert_equal [1, 1, -1], (DecNum('0.1')/1).split
  end

  def test_precision
    x = (DecNum(4)/3 - 1)*3 - 1       # -1e-8
    assert_equal [-1, 1, -8], x.split

    DecNum.context.normalized = true
    x = (DecNum(4)/3 - 1)*3 - 1       # -1.00000000e-8
    assert_equal [-1, 100000000, -16], x.split

    x = (BinNum(4)/3 - 1)*3 - 1       # -0x1p-52
    assert_equal [-1, 1, -52], x.split

    BinNum.context.normalized = true
    x = (BinNum(4)/3 - 1)*3 - 1       # -0x1.0000000000000p-52
    assert_equal [-1, 4503599627370496, -104], x.split
  end

end
