#require File.dirname(__FILE__) + '/../lib/decimal'
require File.dirname(__FILE__) + '/test_helper.rb'

ROUNDINGS = {
  'ceiling' => :ceiling,
  'down' => :down,
  'floor' => :floor,
  'half_down' => :half_down,
  'half_even' => :half_even,
  'half_up' => :half_up,
  'up' => :up,
  '05up' => nil
}
FUNCTIONS = {
  'add'=>'add',
  'divide'=>'divide',
  'multiply'=>'multiply',
  'substract'=>'substract',
  
}

FLAG_NAMES = {
  'inexact'=>:Inexact,
  'rounded'=>:Rounded,
  'clamped'=>:Clamped,
  'subnormal'=>:Subnormal,
  'invalid_operation'=>:InvalidOperation,
  'underflow'=>:Underflow,
  'overflow'=>:Overflow,
  'division_by_zero'=>:DivisionByZero,
  'division_undefined'=>:InvalidOperation
}



SKIP = {
  FPNum::RB => [],
  FPNum::BD => %w{
    add242 add303 add307 add642 add643 add644 add651 add652 add653 add662 add663 add664
    add671 add672 add673 add682 add683 add684 add691 add692 add693 add702 add703 add704
    add711 add712 add713 add330 add331 add332 add333 add334 add335 add336 add337 add338 add339
    div270 div271 div272 div273 div280 div281 div282 div283 div284 div285 div286 div287 div288
    div330 div331 div332 div333 div335 div336 div337 div338 div360
  }
}

def unquote(txt)
  txt = txt[1...-1] if txt[0,1]=="'" && txt[-1,1]=="'"
  txt = 'NaN' if txt=='#' || txt=='?'
  txt    
end
  
class TestBasic < Test::Unit::TestCase
  
  def test_dec
    
    $implementations_to_test.each do |mod|
    
      skip_tests = SKIP[mod]
      
      dir = File.join(File.dirname(__FILE__), 'dectest')
      dir = nil unless File.exists?(dir)
      if dir
        Dir[File.join(dir, '*.decTest')].each do |fn|
                
          name = File.basename(fn,'.decTest').downcase
          next if %w{ds dd dq}.include?(fn[0,2]) || 
                   %w{decsingle decdouble decquad testall}.include?(fn)
        
          File.open(fn,'r') do |file|
            file.each_line do |line|
              next if line[0,2]=='--' || line.strip.empty?
              
              if line.include?(' -> ')
                # test
                # to do :remove inline comments --... on the right of ->
                sides = line.split('->')
                lhs = sides.first.strip.split
                id = lhs.first
                funct = lhs[1].downcase
                valstemp = lhs[2..-1]
                rhs = sides.last.strip.split
                ans = rhs.first
                flags = rhs[1..-1].map{|f| mod::Decimal.class_eval(FLAG_NAMES[f.downcase].to_s)}.compact
                
                funct = FUNCTIONS[funct]
                if funct && !skip_tests.include?(id)
                  # do test
                  msg = "Test #{id}: #{funct}(#{valstemp.join(',')}) = #{ans}"
                  valstemp.map!{|v| mod::Decimal(unquote(v))}
                  expected = result = result_flags = nil
                  mod::Decimal.local_context do |context|
                    context.flags.clear!
                    result = context.send(funct, *valstemp)
                    expected = mod::Decimal(unquote(ans))              
                    result_flags = context.flags
                  end
                  expected_flags = mod::Decimal::Flags(*flags)
                  assert_equal expected.to_s, result.to_s, msg if ans!='?'
                  #assert_equal expected, result, msg if ans!='?'
                  assert_equal expected_flags, result_flags, msg
                end          
                
              elsif line.include?(':')
                # directive
                funct,value = line.split(':').map{|x| x.strip.downcase}
                case funct
                  when 'rounding'
                    value = ROUNDINGS[value]                                     
                  else
                    value = value.to_i
                end
                if value.nil?
                  raise "error"
                  # to do: skip untill next valid value of same funct
                else  
                  case funct
                    when 'rounding','precision'              
                      mod::Decimal.context.send "#{funct}=", value
                    when 'maxexponent'
                      mod::Decimal.context.emax = value
                    when 'minexponent'
                      mod::Decimal.context.emin = value
                  end
                end            
              end        
            end
          end  
        end
      end
    end
  end

end
