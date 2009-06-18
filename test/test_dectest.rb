require File.dirname(__FILE__) + '/helper.rb'

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
# Known functions not yet implemented
PENDING = %w{
  abs
  subtract
  apply
  and
  tosci
  toeng
  class
  comparetotal
  comparetotmag
  copy
  exp
  power
  invert
  ln
  log10
  max
  maxmag
  min
  minmag
  nextminus
  nextplus
  nexttoward
  or
  rotate
  shift
  trim
  xor
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
   missing = []
    dir = File.join(File.dirname(__FILE__), 'dectest')
    dir = nil unless File.exists?(dir)
    if dir
      Dir[File.join(dir, '*.decTest')].each do |fn|

        name = File.basename(fn,'.decTest').downcase
        next if %w{ds dd dq}.include?(name[0,2]) ||
                 %w{decsingle decdouble decquad testall}.include?(name)

        initialize_context


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
              flags = rhs[1..-1].map{|f| Decimal.class_eval(FLAG_NAMES[f.downcase].to_s)}.compact

              next unless valstemp.grep(/#/).empty?

              $test_id = id
              funct = FUNCTIONS[original_funct=funct]
              if funct
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
                result = 1 if result==true
                result = 0 if result==false
                expected_flags = Decimal::Flags(*flags)
                if ans!='?'
                  assert_equal expected.to_s, result.to_s, msg
                end
                assert_equal expected_flags, result_flags, msg

              else
                missing << original_funct unless PENDING.include?(original_funct) || missing.include?(original_funct)
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
                    Decimal.context.send "#{funct}=", value
                  when 'maxexponent'
                    Decimal.context.emax = value
                  when 'minexponent'
                    Decimal.context.emin = value
                  when 'clamp'
                    Decimal.context.clamp = (value==0 ? false : true)
                end
              end
            end
          end
        end
      end
    end

    assert_empty missing

  end

end
