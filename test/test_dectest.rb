require File.dirname(__FILE__) + '/../lib/decimal'

ROUNDINGS = {
  'ceiling' => Decimal::ROUND_CEILING,
  'down' => Decimal::ROUND_DOWN,
  'floor' => Decimal::ROUND_FLOOR,
  'half_down' => Decimal::ROUND_HALF_DOWN,
  'half_even' => Decimal::ROUND_HALF_EVEN,
  'half_up' => Decimal::ROUND_HALF_UP,
  'up' => Decimal::ROUND_UP,
  '05up' => nil
}
FUNCTIONS = {
  'add'=>'add',
  'divide'=>'divide',
  'multiply'=>'multiply',
  'substract'=>'substract',
  
}

FLAG_NAMES = {
  'inexact'=>nil,
  'rounded'=>nil,
  'clamped'=>nil,
  'subnormal'=>nil,
  'invalid_operation'=>:invalid_operation,
  'underflow'=>:underflow,
  'overflow'=>:overflow,
  'division_by_zero'=>:division_by_zero,
  'division_undefined'=>:invalid_operation
}

# tests not passed by BigDecimal
SKIP = %w{
  add242 add303 add307 add642 add643 add644 add651 add652 add653 add662 add663 add664
  add671 add672 add673 add682 add683 add684 add691 add692 add693 add702 add703 add704
  add711 add712 add713 add330 add331 add332 add333 add334 add335 add336 add337 add338 add339
  div270 div271 div272 div273 div280 div281 div282 div283 div284 div285 div286 div287 div288
  div330 div331 div332 div333 div335 div336 div337 div338 div360
}

def unquote(txt)
  txt = txt[1...-1] if txt[0,1]=="'" && txt[-1,1]=="'"
  txt = 'NaN' if txt=='#' || txt=='?'
  txt    
end
  
class TestBasic < Test::Unit::TestCase
  
  def test_dec
    
    dir = File.join(File.dirname(__FILE__), 'dectest')
    unless File.exists?(dir)
      dir = File.join(File.dirname(__FILE__), 'dectest0')
      dir = nil unless File.exists?(dir)
    end
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
              flags = rhs[1..-1].map{|f| FLAG_NAMES[f.downcase]}.compact
              
              funct = FUNCTIONS[funct]
              if funct && !SKIP.include?(id)
                # do test
                msg = "Test #{id}: #{funct}(#{valstemp.join(',')}) = #{ans}"
                valstemp.map!{|v| Decimal(unquote(v))}
                expected = result = result_flags = nil
                Decimal.local_context do |context|
                  context.flags.clear!
                  result = context.send(funct, *valstemp)
                  expected = Decimal(unquote(ans))              
                  result_flags = context.flags
                end
                expected_flags = Decimal::Context::Flags(*flags)
                assert_equal expected.to_s, result.to_s, msg if ans!='?'
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
                    Decimal.context.send "#{funct}=", value
                  when 'maxexponent'
                    Decimal.context.emax = value
                  when 'minexponent'
                    Decimal.context.emin = value
                end
              end            
            end        
          end
        end  
      end
    end
  end

end
