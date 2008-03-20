require File.dirname(__FILE__) + '/test_helper.rb'


class TestExact < Test::Unit::TestCase
  

  def setup
    $implementations_to_test.each do |mod|
      mod::Decimal.context = mod::Decimal::DefaultContext
    end
  end  
  
  
  def test_exact
    $implementations_to_test.each do |mod|
      
      next if mod==FPNum::BD # not yet implemented
      
      mod::Decimal.context.exact = true
      
      assert_equal mod::Decimal("9"*100+"E-50"), mod::Decimal('1E50')-mod::Decimal('1E-50')
      assert_equal mod::Decimal(2),mod::Decimal(6)/mod::Decimal(3)
      assert_equal mod::Decimal('1.5'),mod::Decimal(6)/mod::Decimal(4)
      assert_equal mod::Decimal('15241578780673678546105778281054720515622620750190521'), mod::Decimal('123456789123456789123456789')*mod::Decimal('123456789123456789123456789')                    
      assert_nothing_raised(mod::Decimal::Inexact){ mod::Decimal(6)/mod::Decimal(4) }
      assert_raise(mod::Decimal::Inexact){ mod::Decimal(1)/mod::Decimal(3) }
      # assert_raise(mod::Decimal::Inexact){ mod::Decimal(2).sqrt }
      

    end  
   
  end
  
    
end
