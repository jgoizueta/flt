require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

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
  'subtract'=>'subtract',
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
  'squareroot'=>'sqrt',
  'abs'=>'abs',
  'nextminus'=>'next_minus',
  'nextplus'=>'next_plus',
  'nexttoward'=>'next_toward',
  'tosci'=>'to_sci_string',
  'toeng'=>'to_eng_string',
  'class'=>'number_class',
  'power'=>'power',
  'log10'=>'log10',
  'exp'=>'exp',
  'ln'=>'ln'
}
# Functions not yet implemented
PENDING = %w{
  rotate
  shift
  trim

  and
  or
  xor
  invert

  max
  min
  maxmag
  minmag
  comparetotal
  comparetotmag
}
IGNORED = PENDING + %w{
  copy
  apply
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
  'division_impossible'=>:DivisionImpossible,
  'conversion_syntax'=>:ConversionSyntax
}

# Excluded tests that we don't currently pass
EXCEPTIONS = %w{
  powx1183 powx1184
  powx4001 powx4002 powx4003 powx4005
  powx4008 powx4010 powx4012 powx4014
  logx901  logx902  logx903  logx903  logx905
  expx901  expx902  expx903  expx905
  lnx901   lnx902   lnx903   lnx905
}


def unquote(txt)
  if txt[0,1]=="'" && txt[-1,1]=="'"
    txt = txt[1...-1].gsub("''","'")
  end
  if txt[0,1]=='"' && txt[-1,1]=='"'
    txt = txt[1...-1].gsub('""','"')
  end
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
            line = line.split('--').first.strip if line.include?('--')
            next if line.strip.empty?

            if line.include?(' -> ')
              # test
              # to do :remove inline comments --... on the right of ->
              sides = line.split('->')
              # now split by whitespace but avoid breaking quoted strings (and take care or repeated quotes!)
              lhs = sides.first.strip.scan(/"(?:[^"]|"")*"|'(?:[^']|'')*'|\S+/)
              id = lhs.first
              funct = lhs[1].downcase
              valstemp = lhs[2..-1]
              rhs = sides.last.strip.split
              ans = rhs.first
              flags = rhs[1..-1].map{|f| DecNum.class_eval(FLAG_NAMES[f.downcase].to_s)}.compact

              next unless valstemp.grep(/#/).empty?

              $test_id = id
              funct = FUNCTIONS[original_funct=funct]
              next if EXCEPTIONS.include?(id)
              if funct
                # do test
                msg = "  Test #{id}: #{funct}(#{valstemp.join(',')}) = #{ans}"
                #File.open('dectests.txt','a'){|f| f.puts msg}
                expected = result = result_flags = nil
                DecNum.local_context do |context|
                  context.flags.clear!
                  exact_input = !['apply','to_sci_string', 'to_eng_string'].include?(funct)
                  if exact_input
                    p = context.precision
                    context.exact = true
                  end
                  valstemp.map!{|v| DecNum(unquote(v))}
                  context.precision = p if exact_input
                  result = context.send(funct, *valstemp)
                  result_flags = context.flags.dup
                  expected = unquote(ans)
                  context.exact = true
                  expected = DecNum(expected) unless result.is_a?(String)
                end
                result = 1 if result==true
                result = 0 if result==false
                expected_flags = DecNum::Flags(*flags)
                if ans!='?'
                  assert_equal expected.to_s, result.to_s, msg
                end
                assert_equal expected_flags, result_flags, msg

              else
                missing << original_funct unless IGNORED.include?(original_funct) || missing.include?(original_funct)
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
                    DecNum.context.send "#{funct}=", value
                  when 'maxexponent'
                    DecNum.context.emax = value
                  when 'minexponent'
                    DecNum.context.emin = value
                  when 'clamp'
                    DecNum.context.clamp = (value==0 ? false : true)
                end
              end
            end
          end
        end
      end
    end

    # assert_empty missing
    # In Ruby 1.8 there's no assert_empty
    assert missing.empty?, "#{missing.inspect} is not empty"

  end

end
