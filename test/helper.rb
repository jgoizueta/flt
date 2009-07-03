require 'test/unit'
require File.dirname(__FILE__) + '/../lib/bigfloat'
include BigFloat

def initialize_context
  Decimal.context = Decimal::ExtendedContext
  BinFloat.context = BinFloat::ExtendedContext
end

def float_emulation_context
  raise "BinFloat tests require that Float is binary" unless Float::RADIX==2
  BinFloat.context = BinFloat::FloatContext
  BinFloat.context.clamp = false
  BinFloat.context.traps.clear!
  BinFloat.context.flags.clear!
  #
  # BinFloat.context.precision = Float::MANT_DIG
  # BinFloat.context.emin = Float::MIN_EXP-1
  # BinFloat.context.emax = Float::MAX_EXP-1
  # BinFloat.context.rounding = :half_even
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
