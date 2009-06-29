require 'test/unit'
require File.dirname(__FILE__) + '/../lib/bigfloat'
include BigFloat

def initialize_context
  Decimal.context = Decimal::ExtendedContext
  BinFloat.context = BinFloat::ExtendedContext
end

def detect_float_rounding
  x = x = Math::ldexp(1, Float::MANT_DIG+1) # 10000...00*Float::RADIX**2 == Float::RADIX**(Float::MANT_DIG+1)
  y = x + Math::ldexp(1, 2)                 # 00000...01*Float::RADIX**2 == Float::RADIX**2
  h = Float::RADIX/2
  b = h*Float::RADIX
  z = Float::RADIX**2 - 1
  if x + 1 == y
    if (y + 1 == y) && Float::RADIX==10
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

def float_emulation_context
  raise "BinFloat tests require that Float is binary" unless Float::RADIX==2
  BinFloat.context.precision = Float::MANT_DIG
  BinFloat.context.emin = Float::MIN_EXP-1
  BinFloat.context.emax = Float::MAX_EXP-1
  BinFloat.context.rounding = detect_float_rounding
end

def random_integer(min, max)
  n = max - min + 1
  rand(n) + min
end

def random_float
  f = rand(2**Float::MANT_DIG)
  f = -f if rand(1)==0
  e = random_integer(Float::MIN_EXP-Float::MANT_DIG, Float::MAX_EXP-Float::MANT_DIG)
  Math.ldexp(f, e)
end

# this may be handy for problem reporting
def float_split(x)
  s,e = Math.frexp(x)
  [Math.ldexp(s,Float::MANT_DIG).to_i,e-Float::MANT_DIG]
end
