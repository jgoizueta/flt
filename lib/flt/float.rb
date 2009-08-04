# Native Ruby Float extemsions
# Here we add some of the methods available in BinNum to Float.
#
# The set of constants with Float metadata is also augmented.
# The built-in contantas are:
# Note that this uses the "fractional significand" interpretation,
# i.e. the significand has the radix point before its first digit.
#
# Float::RADIX : b = Radix of exponent representation,2
#
# Float::MANT_DIG : p = bits (base-RADIX digits) in the significand
#
# Float::DIG : q = Number of decimal digits such that any floating-point number with q
#              decimal digits can be rounded into a floating-point number with p radix b
#              digits and back again without change to the q decimal digits,
#                 q = p * log10(b)			if b is a power of 10
#               	q = floor((p - 1) * log10(b))	otherwise
#              ((Float::MANT_DIG-1)*Math.log(FLoat::RADIX)/Math.log(10)).floor
#
# Float::MIN_EXP : emin = Minimum int x such that Float::RADIX**(x-1) is a normalized float
#
# Float::MIN_10_EXP : Minimum negative integer such that 10 raised to that power is in the
#                    range of normalized floating-point numbers,
#                      ceil(log10(b) * (emin - 1))
#
# Float::MAX_EXP : emax = Maximum int x such that Float::RADIX**(x-1) is a representable float
#
# Float::MAX_10_EXP : Maximum integer such that 10 raised to that power is in the range of
#                     representable finite floating-point numbers,
#                       floor(log10((1 - b**-p) * b**emax))
#
# Float::MAX : Maximum representable finite floating-point number
#                (1 - b**-p) * b**emax
#
# Float::EPSILON : The difference between 1 and the least value greater than 1 that is
#                  representable in the given floating point type
#                    b**(1-p)
#                  Math.ldexp(*Math.frexp(1).collect{|e| e.kind_of?(Integer) ? e-(Float::MANT_DIG-1) : e})
#
# Float::MIN  : Minimum normalized positive floating-point number
#                  b**(emin - 1).
#
# Float::ROUNDS : Addition rounds to 0: zero, 1: nearest, 2: +inf, 3: -inf, -1: unknown.
#
# Additional contants defined here:
#
# Float::DECIMAL_DIG :  Number of decimal digits, n, such that any floating-point number can be rounded
#                       to a floating-point number with n decimal digits and back again without
#                       change to the value,
#                         pmax * log10(b)			if b is a power of 10
#                         ceil(1 + pmax * log10(b))	otherwise
#                       DECIMAL_DIG = (MANT_DIG*Math.log(RADIX)/Math.log(10)).ceil+1
#
# Float::MIN_N : Minimum normalized number == MAX_D.next == MIN
#
# Float::MAX_D : Maximum denormal number == MIN_N.prev
#
# Float::MIN_D : Minimum non zero positive denormal number == 0.0.next
#
# Float::MAX_F : Maximum significand
#

class Float

  DECIMAL_DIG = (MANT_DIG*Math.log(RADIX)/Math.log(10)).ceil+1

  # Minimum normalized number == MAX_D.next
  MIN_N = Math.ldexp(0.5,Float::MIN_EXP) # == nxt(MAX_D) == Float::MIN

  # Maximum denormal number == MIN_N.prev
  MAX_D = Math.ldexp(Math.ldexp(1,Float::MANT_DIG-1)-1,Float::MIN_EXP-Float::MANT_DIG)

  # Minimum non zero positive denormal number == 0.0.next
  MIN_D = Math.ldexp(1,Float::MIN_EXP-Float::MANT_DIG);

  # Maximum significand  == Math.ldexp(Math.ldexp(1,Float::MANT_DIG)-1,-Float::MANT_DIG)
  MAX_F = Math.frexp(Float::MAX)[0]   == Math.ldexp(Math.ldexp(1,Float::MANT_DIG)-1,-Float::MANT_DIG)

end

require 'delegate'


module Flt::FloatExtensions

  def self.included(base)
    base.extend(ClassMethods)
    base.math_functions :log, :log10, :exp, :sqrt,
                   :sin, :cos, :tan, :asin, :acos, :atan,
                   :sinh, :cosh, :tanh, :asinh, :acosh, :atanh
  end

  def num_class
    self.class
  end

  # Compute the adjacent floating point values: largest value not larger than
  # this and smallest not smaller.
  def neighbours
    f,e = Math.frexp(self.to_f)
    e = Float::MIN_EXP if f==0
    e = [Float::MIN_EXP,e].max
    dx = Math.ldexp(1,e-Float::MANT_DIG) #Math.ldexp(Math.ldexp(1.0,-Float::MANT_DIG),e)

    min_f = 0.5 #0.5==Math.ldexp(2**(bits-1),-Float::MANT_DIG)
    max_f = 1.0 - Math.ldexp(1,-Float::MANT_DIG)

    if f==max_f
      high = self + dx*2
    elsif f==-min_f && e!=Float::MIN_EXP
      high = self + dx/2
    else
      high = self + dx
    end
    if e==Float::MIN_EXP || f!=min_f
      low = self - dx
    elsif f==-max_f
      high = self - dx*2
    else
      low = self - dx/2
    end
    [Flt.FloatNum(low), Flt.FloatNum(high)]
  end

  # Previous floating point value
  def prev
     neighbours[0]
  end

  # Next floating point value; e.g. 1.0.next == 1.0+Float::EPSILON
  def next
     neighbours[1]
  end

  # Synonym of next, named in the style of DecNum (GDA)
  #
  # The context parameters, which is not used, is for compatibility with Flt classes
  def next_plus(context=nil)
    Flt.FloatNum(self.next)
  end

  # Synonym of prev, named in the style of DecNum (GDA)
  #
  # The context parameters, which is not used, is for compatibility with Flt classes
  def next_minus(context=nil)
    Flt.FloatNum(self.prev)
  end

  def next_toward(other)
    comparison = self <=> other
    return self.copy_sign(other) if comparison == 0
    if comparison == -1
      result = self.next_plus(context)
    else # comparison == 1
      result = self.next_minus(context)
    end
  end

  # Sign: -1 for minus, +1 for plus, nil for nan (note that Float zero is signed)
  def sign
    if nan?
      nil
    elsif self==0
      self.to_s[0,1] == "-" ? -1 : +1 # (1/self < 0) ? -1 : +1
    else
      self < 0 ? -1 : +1
    end
  end

  # Return copy of self with the sign of other
  def copy_sign(other)
    self_sign = self.sign
    other_sign = other.is_a?(Integer) ? (other < 0 ? -1 : +1) : other.sign
    if self_sign && other_sign
      if self_sign == other_sign
        Flt.FloatNum(self)
      else
        Flt.FloatNum(-self)
      end
    else
      nan
    end
  end

  # Returns the internal representation of the number, composed of:
  # * a sign which is +1 for plus and -1 for minus
  # * a coefficient (significand) which is a nonnegative integer
  # * an exponent (an integer) or :inf, :nan or :snan for special values
  # The value of non-special numbers is sign*coefficient*10^exponent
  def split
    sign = self.sign
    if nan?
      exp = :nan
    elsif infinite?
      exp = :inf
    else
      coeff,exp = Math.frexp(self.to_f)
      coeff = coeff.abs
      if exp < Float::MIN_EXP
        # denormalized number
        coeff = Math.ldexp(coeff, exp-Float::MIN_EXP+Float::MANT_DIG).to_i
        exp = Float::MIN_EXP-Float::MANT_DIG
      else
        # normalized number
        coeff = Math.ldexp(coeff, Float::MANT_DIG).to_i
        exp -= Float::MANT_DIG
      end
    end
    [sign, coeff, exp]
  end

  # Return the value of the number as an signed integer and a scale.
  def to_int_scale
    if special?
      nil
    else
      coeff,exp = Math.frexp(self.to_f)
      coeff = coeff
      if exp < Float::MIN_EXP
        # denormalized number
        coeff = Math.ldexp(coeff, exp-Float::MIN_EXP+Float::MANT_DIG).to_i
        exp = Float::MIN_EXP-Float::MANT_DIG
      else
        # normalized number
        coeff = Math.ldexp(coeff, Float::MANT_DIG).to_i
        exp -= Float::MANT_DIG
      end
      [coeff, exp]
    end
  end


  # ulp (unit in the last place) according to the definition proposed by J.M. Muller in
  # "On the definition of ulp(x)" INRIA No. 5504
  def ulp(mode=:low)
    return self if nan?
    x = abs
    if x < Math.ldexp(1,Float::MIN_EXP) # x < Float::RADIX*Float::MIN_N
      x = Math.ldexp(1,Float::MIN_EXP-Float::MANT_DIG) # res = Float::MIN_D
    elsif x > Float::MAX # x > Math.ldexp(1-Math.ldexp(1,-Float::MANT_DIG),Float::MAX_EXP)
      x = Math.ldexp(1,Float::MAX_EXP-Float::MANT_DIG) # res = Float::MAX - Float::MAX.prev
    else
      f,e = Math.frexp(x.to_f)
      e -= 1 if f==Math.ldexp(1,-1) if mode==:low # assign the smaller ulp to radix powers
      x = Math.ldexp(1,e-Float::MANT_DIG)
    end
    Flt.FloatNum(x)
  end

  def special?
    nan? || infinite?
  end

  def normal?
    if special? || zero?
      false
    else
      self.abs >= Float::MIN_N
    end
  end

  def subnormal?
    if special? || zero?
      false
    else
      self.abs < Float::MIN_N
    end
  end

  module ClassMethods

    def radix
      Float::RADIX
    end

    # NaN (not a number value)
    def nan
      Flt.FloatNum(0.0/0.0)
    end

    # zero value with specified sign
    def zero(sign=+1)
      Flt.FloatNum((sign < 0) ? -0.0 : 0.0)
    end

    # infinity value with specified sign
    def infinity(sign=+1)
      Flt.FloatNum((sign < 0) ? -1.0/0.0 : 1.0/0.0)
    end

    # This provides an common interface (with Flt classes) to precision, rounding, etc.
    def context
      self
    end

    # This is for further compatibility with Flt classes; it allows Float.context to act
    # more like a context.
    def num_class
      self
    end

    def int_radix_power(n)
      1 << n
    end

    # This is the difference between 1.0 and the smallest floating-point
    # value greater than 1.0, radix_power(1-significand_precision)
    #
    # We have:
    #   Float.epsilon == (1.0.next-1.0)
    def epsilon(sign=+1)
      Flt.FloatNum((sign < 0) ? -Float::EPSILON : Float::EPSILON)
    end

    # The strict epsilon is the smallest value that produces something different from 1.0
    # wehen added to 1.0. It may be smaller than the general epsilon, because
    # of the particular rounding rules used with the floating point format.
    # This is only meaningful when well-defined rules are used for rounding the result
    # of floating-point addition.
    #
    # We have:
    #   (Float.strict_epsilon+1.0) == 1.0.next
    #   (Float.strict_epsilon.prev+1.0) == 1.0
    def strict_epsilon(sign=+1, round=nil)
      # We don't rely on Float::ROUNDS
      eps = minimum_nonzero
      unless (1.0+eps) > 1.0
        f,e = Math.frexp(1)
        eps = Math.ldexp(f.next,e-Float::MANT_DIG)
        if (1.0+eps) > 1.0
          eps
        else
          eps = Math.ldexp(f,e-Float::MANT_DIG)
          unless (1.0+eps) > 1.0
          else
            eps = Math.ldexp(f,e-Float::MANT_DIG+1)
          end
        end
      end
      Flt.FloatNum(eps)
    end

    # This is the maximum relative error corresponding to 1/2 ulp:
    #  (radix/2)*radix_power(-significand_precision) == epsilon/2
    # This is called "machine epsilon" in [Goldberg]
    # We have:
    #
    #  Float.half_epsilon == 0.5*Float.epsilon
    def half_epsilon(sign=+1)
      # 0.5*epsilon(sign)
      f,e = Math.frexp(1)
      Flt.FloatNum(Math.ldexp(f, e-Float::MANT_DIG))
    end

    # minimum normal Float value (with specified sign)
    def minimum_normal(sign=+1)
      Flt.FloatNum((sign < 0) ? -Float::MIN_N : Float::MIN_N)
    end

    # maximum subnormal (denormalized) Float value (with specified sign)
    def maximum_subnormal(sign=+1)
      Flt.FloatNum((sign < 0) ? -Float::MAX_D : Float::MAX_D)
    end

    # minimum (subnormal) nonzero Float value, with specified sign
    def minimum_nonzero(sign=+1)
      Flt.FloatNum((sign < 0) ? -Float::MIN_D : Float::MIN_D)
    end

    # maximum finite Float value, with specified sign
    def maximum_finite(sign=+1)
      Flt.FloatNum((sign < 0) ? -Float::MAX : Float::MAX)
    end

    def Num(*args)
      Flt.FloatNum(*args)
    end

    def precision
      Float::MANT_DIG
    end

    def exact?
      false
    end

    # detect actual rounding mode
    def rounding
      Flt::Support::AuxiliarFunctions.detect_float_rounding
    end

    def emin
      Float::MIN_EXP-1
    end

    def emax
      Float::MAX_EXP-1
    end

    def etiny
      Float::MIN_EXP - Float::MANT_DIG
    end

    def etop
      Float::MAX_EXP - Float::MANT_DIG
    end

    def math_functions(*methods)
      methods.each do |method|
        define_method(method) do
          Math.send(method, self.to_f)
        end
      end
    end

  end

end

class Flt::FloatNum  < DelegateClass(Float)

  include Flt::FloatExtensions

  def initialize(*args)
    super Float(*args)
  end

  class <<self
    def returns_num(*methods)
      methods.each do |method|
        original_method = self.instance_method(method)
        undef_method method # avoid warning
        define_method(method) do |*args|
          Flt::FloatNum.Num(original_method.bind(self).call(*args))
        end
      end
    end

    def math_functions(*methods)
      methods.each do |method|
        define_method(method) do
          Flt::FloatNum.Num(Math.send(method, self.to_f))
        end
      end
    end
  end

  returns_num :abs, :+, :-, :*, :/, :**, :-@
  returns_num :log, :log10, :exp, :sqrt,
                 :sin, :cos, :tan, :asin, :acos, :atan,
                 :sinh, :cosh, :tanh, :asinh, :acosh, :atanh

end

# Load extensions into Float class (otherwise a proxy FloatNum is used that acts like a Num and delegates to Float)
def Flt.extend_float
  Float.send :include, Flt::FloatExtensions unless Float < Flt::FloatExtensions
end

def Flt.FloatNum(*args)
  args = *args if args.size==1 && args.first.is_a?(Array)
  if args.size==3
    x = Math.ldexp(args[0]*args[1],args[2])
  elsif args.size==2
    x = Math.ldexp(args[0],args[1])
  elsif args.size==1
    x = Float(*args)
  end
  Float < Flt::FloatExtensions ? x : Flt::FloatNum.new(x)
end

def Flt.FloatNumClass
  Float < Flt::FloatExtensions ? Float : Flt::FloatNum
end
