require 'test/unit'
$: << "." unless $:.include?(".") # for Ruby 1.9.2
require File.expand_path(File.join(File.dirname(__FILE__),'/../lib/flt'))
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
  context = num_class.context
  if rand(20)==0
    # generate 5% of subnormals
    f = rand(context.radix**(context.precision-1))
    e = context.etiny
  elsif rand(20)==0
    # and some singular values too
    if rand(1) == 0
      f = context.radix**context.precision - 1
      f -= rand(3)
    else
      f = context.radix**(context.precision - 1)
      f += rand(3)
    end
    e = random_integer(context.etiny, context.etop)
  else
    f = rand(context.radix**context.precision)
    e = random_integer(context.etiny, context.etop)
  end
  f = -f if rand(1)==0
  context.Num(f, e)
end

def special_nums(num_class)
  context = num_class.context
  [context.nan, context.infinity, -context.infinity]
end

def singular_nums(num_class)
  context = num_class.context
  nums = [context.zero(-1), context.zero(+1), context.minimum_nonzero, -context.minimum_nonzero,
    context.next_plus(context.minimum_nonzero), -context.next_plus(context.minimum_nonzero),
    context.next_minus(context.maximum_subnormal), -context.next_minus(context.maximum_subnormal),
    context.maximum_subnormal, -context.maximum_subnormal,
    context.minimum_normal, -context.minimum_normal,
    context.next_plus(context.minimum_normal), -context.next_plus(context.minimum_normal),
    context.next_minus(context.maximum_finite), -context.next_minus(context.maximum_finite),
    context.maximum_finite, -context.maximum_finite]
  xs = [1,3,5]
  xs += [context.radix, context.radix**2, context.radix**5, context.radix**10]
  xs += [10,100,100000,10000000000] if context.radix!=10
  xs += [2,4,32,1024] if context.radix!=2
  nums += xs.map{|x| n = context.Num(x); [n,-n,context.next_minus(n),-context.next_minus(n),
                                          context.next_plus(n),-context.next_plus(n)] }.flatten
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
