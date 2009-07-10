require 'test/unit'
require File.dirname(__FILE__) + '/../lib/flt'
require 'enumerator'
include Flt

def initialize_context
  DecNum.context = DecNum::ExtendedContext
  BinNum.context = BinNum::ExtendedContext
end

def float_emulation_context
  raise "BinNum tests require that Float is binary" unless Float::RADIX==2
  BinNum.context = BinNum::FloatContext
  BinNum.context.clamp = false
  BinNum.context.traps.clear!
  BinNum.context.flags.clear!
  #
  # BinNum.context.precision = Float::MANT_DIG
  # BinNum.context.emin = Float::MIN_EXP-1
  # BinNum.context.emax = Float::MAX_EXP-1
  # BinNum.context.rounding = :half_even
end

def random_integer(min, max)
  n = max - min + 1
  rand(n) + min
end

def random_float
  random_num Float
end

def random_bin_num
  random_num BinNum
end

def random_dec_num
  random_num DecNum
end

def random_num(num_class)
  if rand(20)==0
    # generate 5% of subnormals
    f = rand(num_class.radix**(num_class.context.precision-1))
    e = num_class.context.etiny
  elsif rand(20)==0
    # and some singular values too
    if rand(1) == 0
      f = num_class.radix**num_class.context.precision - 1
      f -= rand(3)
    else
      f = num_class.radix**(num_class.context.precision - 1)
      f += rand(3)
    end
    e = random_integer(num_class.context.etiny, num_class.context.etop)
  else
    f = rand(num_class.radix**num_class.context.precision)
    e = random_integer(num_class.context.etiny, num_class.context.etop)
  end
  f = -f if rand(1)==0
  num_class.Num(f, e)
end

def special_nums(num_class)
  [num_class.nan, num_class.infinity, -num_class.infinity]
end

def singular_nums(num_class)
  nums = [num_class.zero(-1), num_class.zero(+1), num_class.minimum_nonzero, -num_class.minimum_nonzero,
    num_class.minimum_nonzero.next_plus, -num_class.minimum_nonzero.next_plus,
    num_class.maximum_subnormal.next_minus, -num_class.maximum_subnormal.next_minus,
    num_class.maximum_subnormal, -num_class.maximum_subnormal,
    num_class.minimum_normal, -num_class.minimum_normal,
    num_class.minimum_normal.next_plus, -num_class.minimum_normal.next_plus,
    num_class.maximum_finite.next_minus, -num_class.maximum_finite.next_minus,
    num_class.maximum_finite, -num_class.maximum_finite]
  xs = [1,3,5]
  xs += [num_class.radix, num_class.radix**2, num_class.radix**5, num_class.radix**10]
  xs += [10,100,100000,10000000000] if num_class.radix!=10
  xs += [2,4,32,1024] if num_class.radix!=2
  nums += xs.map{|x| n = num_class.Num(x); [n,-n,n.next_minus,-n.next_minus,n.next_plus,-n.next_plus] }.flatten
  nums
end

# this may be handy for problem reporting
def float_split(x)
  s,e = Math.frexp(x)
  [Math.ldexp(s,Float::MANT_DIG).to_i,e-Float::MANT_DIG]
end

def each_pair(array, &blk)
  if RUBY_VERSION>="1.9"
    array.each_slice(2,&blk)
  else
    array.enum_slice(2,&blk)
  end
end
