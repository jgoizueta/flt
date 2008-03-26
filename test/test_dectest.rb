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
  '05up' => :up05
}
FUNCTIONS = {
  'add'=>'add',
  'divide'=>'divide',
  'multiply'=>'multiply',
  'substract'=>'substract',
  'compare'=>'compare',
  'copyabs'=>'copy_abs',
  'copynegate'=>'copy_negate',
  'copysign'=>'copy_sign',
  'divideint'=>'divide_int',
  'logb'=>'logb',
  'minus'=>'minus',
  'plus'=>'plus',
  'reduce'=>'reduce',
  'remainder'=>'remainder',
  'remaindernear'=>'remainder_near',
  'scaleb'=>'scaleb',
  'rescale'=>'rescale',
  'quantize'=>'quantize',
  'samequantum'=>'same_quantum?',
  'tointegral'=>'to_integral_value',
  'tointegralx'=>'to_integral_exact',
  'fma'=>'fma',
  'squareroot'=>'sqrt'
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
  'division_undefined'=>:InvalidOperation,
  'division_impossible'=>:DivisionImpossible
}



def unquote(txt)
  txt = txt[1...-1] if txt[0,1]=="'" && txt[-1,1]=="'"
  txt = txt[1...-1] if txt[0,1]=='"' && txt[-1,1]=='"'
  #txt = 'NaN' if txt=='#' || txt=='?'
  txt = 'sNaN' if txt=='#'
  txt = 'NaN' if txt=='?'
  txt    
end
  
class TestBasic < Test::Unit::TestCase
  
  def test_dec
    
    $implementations_to_test.each do |mod|
    
      skip_tests = []
      exceptions_fn = File.join(File.dirname(__FILE__), 'bd_exceptions')
      if mod==FPNum::BD && File.exists?(exceptions_fn)     
        skip_tests = File.read(exceptions_fn).split
      end
      
      dir = File.join(File.dirname(__FILE__), 'dectest')
      dir = nil unless File.exists?(dir)
      if dir
        Dir[File.join(dir, '*.decTest')].each do |fn|
                
          name = File.basename(fn,'.decTest').downcase
          next if %w{ds dd dq}.include?(name[0,2]) || 
                   %w{decsingle decdouble decquad testall}.include?(name)
                   
          initialize_context mod

                        
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
                
                next unless valstemp.grep(/#/).empty?
                
                $test_id = id
                
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
                  result = 1 if result==true
                  result = 0 if result==false
                  expected_flags = mod::Decimal::Flags(*flags)
                  if ans!='?'
                    if mod==FPNum::BD
                      expected = mod::Decimal(expected)
                      result = mod::Decimal(result)
                      if expected.nan? || result.nan?                        
                        assert_equal expected.to_s, result.to_s, msg
                      else
                        assert_equal expected, result, msg
                      end
                    else
                      assert_equal expected.to_s, result.to_s, msg
                    end
                  end
                  assert_equal expected_flags, result_flags, msg unless mod==FPNum::BD
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
                  #raise "error"
                  # to do: skip untill next valid value of same funct
                else  
                  case funct
                    when 'rounding','precision'              
                      mod::Decimal.context.send "#{funct}=", value
                    when 'maxexponent'
                      mod::Decimal.context.emax = value
                    when 'minexponent'
                      mod::Decimal.context.emin = value
                    when 'clamp'
                      mod::Decimal.context.clamp = (value==0 ? false : true)
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
