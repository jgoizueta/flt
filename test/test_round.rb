require File.dirname(__FILE__) + '/test_helper.rb'


class TestExact < Test::Unit::TestCase
  

  def setup
    $implementations_to_test.each do |mod|
      mod::Decimal.context = mod::Decimal::DefaultContext
    end
  end  
  
  
  def test_exact
    $implementations_to_test.each do |mod|
      
      next if mod==FPNum::BD
            

      assert_equal(101,  mod::Decimal('100.5').round)
      assert mod::Decimal('100.5').round.kind_of?(Integer)
      assert_equal 100, mod::Decimal('100.4999999999').round
      assert_equal(-101, mod::Decimal('-100.5').round)
      assert_equal(-100, mod::Decimal('-100.4999999999').round)

      assert_equal 101, mod::Decimal('100.5').round(:places=>0)
      assert mod::Decimal('100.5').round(:places=>0).kind_of?(mod::Decimal)

      assert_equal mod::Decimal('123.12'), mod::Decimal('123.123').round(2)
      assert_equal mod::Decimal('123'), mod::Decimal('123.123').round(0)
      assert_equal mod::Decimal('120'), mod::Decimal('123.123').round(-1)
      assert_equal mod::Decimal('120'), mod::Decimal('123.123').round(:precision=>2)
      assert_equal mod::Decimal('123.12'), mod::Decimal('123.123').round(:precision=>5)

      assert_equal 100, mod::Decimal('100.5').round(:rounding=>:half_even)
      assert_equal 101, mod::Decimal('100.5000001').round(:rounding=>:half_even)
      assert_equal 102, mod::Decimal('101.5').round(:rounding=>:half_even)
      assert_equal 101, mod::Decimal('101.4999999999').round(:rounding=>:half_even)

      assert_equal 101, mod::Decimal('100.0001').ceil
      assert_equal(-100, mod::Decimal('-100.0001').ceil)
      assert_equal(-100, mod::Decimal('-100.9999').ceil)
      assert_equal 100, mod::Decimal('100.9999').floor
      assert_equal(-101, mod::Decimal('-100.9999').floor)
      assert_equal(-101, mod::Decimal('-100.0001').floor)

      assert_equal 100, mod::Decimal('100.99999').truncate
      assert_equal(-100, mod::Decimal('-100.99999').truncate)

      

    end  
   
  end
  
    
end
