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
  'add'=>'add'
}

def unquote(txt)
  txt = txt[1...-1] if txt[0,1]=="'" && txt[-1,1]=="'"
  txt    
end

def test_dec
    fn = File.join(File.dirname(__FILE__), 'decimaltestdata' , 'add.decTest')
    
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
            #assert Decimal.context.send(funct, *valstemp)==Decimal(unquote(ans)), msg
            ok = (result==Decimal(unquote(ans)))
            if ok
              # puts "#{msg} : #{ok}"
            else
              puts "#{msg} --> #{result}"
            end
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

test_dec
