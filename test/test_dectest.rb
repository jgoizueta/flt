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
  'divide'=>'multiply',
  'substract'=>'substract',
  
}

def unquote(txt)
  txt = txt[1...-1] if txt[0,1]=="'" && txt[-1,1]=="'"
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
              exceptions = rhs[1..-1]
              
              funct = FUNCTIONS[funct]
              if funct
                # do test
                msg = "Test #{id}: #{funct}(#{valstemp.join(',')}) = #{ans}"
                valstemp.map!{|v| Decimal(unquote(v))}
                result = Decimal.context.send(funct, *valstemp)
                expected = Decimal(unquote(ans))              
                assert_equal expected, result, msg                
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
                end
              end            
            end        
          end
        end  
      end
    end
  end

end
