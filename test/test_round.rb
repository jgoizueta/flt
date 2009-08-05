require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))


class TestRound < Test::Unit::TestCase


  def setup
    initialize_context
  end


  def test_round

    assert_equal(101,  DecNum('100.5').round)
    assert DecNum('100.5').round.kind_of?(Integer)
    assert_equal 100, DecNum('100.4999999999').round
    assert_equal(-101, DecNum('-100.5').round)
    assert_equal(-100, DecNum('-100.4999999999').round)

    assert_equal 101, DecNum('100.5').round(:places=>0)
    assert DecNum('100.5').round(:places=>0).kind_of?(DecNum)
    assert_equal 101, DecNum('100.5').round(0)
    assert DecNum('100.5').round(0).kind_of?(DecNum)

    assert_equal DecNum('123.12'), DecNum('123.123').round(2)
    assert_equal DecNum('123'), DecNum('123.123').round(0)
    assert_equal DecNum('120'), DecNum('123.123').round(-1)
    assert_equal DecNum('120'), DecNum('123.123').round(:precision=>2)
    assert_equal DecNum('123.12'), DecNum('123.123').round(:precision=>5)

    assert_equal 100, DecNum('100.5').round(:rounding=>:half_even)
    assert_equal 101, DecNum('100.5000001').round(:rounding=>:half_even)
    assert_equal 102, DecNum('101.5').round(:rounding=>:half_even)
    assert_equal 101, DecNum('101.4999999999').round(:rounding=>:half_even)

    assert_equal 101, DecNum('100.0001').ceil
    assert_equal(-100, DecNum('-100.0001').ceil)
    assert_equal(-100, DecNum('-100.9999').ceil)
    assert_equal 100, DecNum('100.9999').floor
    assert_equal(-101, DecNum('-100.9999').floor)
    assert_equal(-101, DecNum('-100.0001').floor)

    assert_equal 100, DecNum('100.99999').truncate
    assert_equal(-100, DecNum('-100.99999').truncate)

    assert_equal(10,  DecNum('9.99999').round(:rounding=>:half_up))
    assert_equal(1,  DecNum('0.999999').round(:rounding=>:half_up))
    assert_equal(0,  DecNum('0.0999999').round(:rounding=>:half_up))
    assert_equal(1,  DecNum('0.0999999').round(:rounding=>:up))

  end

  def detect_rounding(type)
    x = type.new(1)*type.int_radix_power(type.context.precision+1)
    y = x + type.int_radix_power(2)
    h = type.radix/2
    b = h*type.radix
    z = type.new(type.int_radix_power(2) - 1)
    type.context do
      type.context.precision = 8 if type.context.exact?
      if x + 1 == y
        if (y + 1 == y) && type.radix==10
          :up05
        elsif -x - 1 == -y
          :up
        else
          :ceiling
        end
      else # x + 1 == x
        if x + z == x
          if -x - z == -x
            :down
          else
            :floor
          end
        else # x + z == y
          # round to nearest
          if x + b == x
            if y + b == y
              :half_down
            else
              :half_even
            end
          else # x + b == y
            :half_up
          end
        end
      end
    end
  end

  def test_round_detection
    [DecNum, BinNum].each do |type|
      [:half_even, :half_up, :half_down, :down, :up, :floor, :ceiling, :up05].each do |rounding|
        type.context(:rounding=>rounding) do
          next if type==BinNum && rounding==:up05
          assert_equal rounding, detect_rounding(type)
        end
      end
    end
  end


end
