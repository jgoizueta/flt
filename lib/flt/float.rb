# Support classes for homogeneous treatment of Float and Num values by defining Float.context
#
# The set of constants with Float metadata is also augmented.

require 'flt/num'
require 'singleton'


# Float constants.
#
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
#               In JRuby this is the mininimum denormal number!
#
# Float::ROUNDS : Addition rounds to 0: zero, 1: nearest, 2: +inf, 3: -inf, -1: unknown.
#
# Note: Ruby 1.9.2 Adds Float::INFINITY and Float::NAN
#
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
# Float::MIN_N : Minimum normalized number == MAX_D.next == MIN (not in JRuby)
#
# Float::MAX_D : Maximum denormal number == MIN_N.prev
#
# Float::MIN_D : Minimum non zero positive denormal number == 0.0.next (== MIN in JRuby)
#
# Float::MAX_F : Maximum significand
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

# Context class with some of the Flt::Num context functionality, to allow the use of Float numbers
# similarly to other Num values; this eases the implementation of functions compatible with either
# Num or Float values.
class Flt::FloatContext

  include Singleton

  def num_class
    Float
  end

  def Num(*args)
    args.flatten!
    case args.size
    when 1
      Float(*args)
    when 2
      Math.ldexp(args[0],args[1])
    when 3
      Math.ldexp(args[0]*args[1],args[2])
    end
  end

  def radix
    Float::RADIX
  end

  # NaN (not a number value)
  def nan
    0.0/0.0 # Ruby 1.9.2: Float::NAN
  end

  # zero value with specified sign
  def zero(sign=+1)
    (sign < 0) ? -0.0 : 0.0
  end

  # infinity value with specified sign
  def infinity(sign=+1)
    (sign < 0) ? -1.0/0.0 : 1.0/0.0 # Ruby 1.9.2: (sing < 0) ? -Float::INFINITY : Float::INFINITY
  end

  def one_half
    0.5
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
    (sign < 0) ? -Float::EPSILON : Float::EPSILON
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
    eps
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
    Math.ldexp(f, e-Float::MANT_DIG)
  end

  # minimum normal Float value (with specified sign)
  def minimum_normal(sign=+1)
    (sign < 0) ? -Float::MIN_N : Float::MIN_N
  end

  # maximum subnormal (denormalized) Float value (with specified sign)
  def maximum_subnormal(sign=+1)
    (sign < 0) ? -Float::MAX_D : Float::MAX_D
  end

  # minimum (subnormal) nonzero Float value, with specified sign
  def minimum_nonzero(sign=+1)
    (sign < 0) ? -Float::MIN_D : Float::MIN_D
  end

  # maximum finite Float value, with specified sign
  def maximum_finite(sign=+1)
    (sign < 0) ? -Float::MAX : Float::MAX
  end

  def precision
    Float::MANT_DIG
  end

  def maximum_coefficient
    int_radix_power(precision)-1
  end

  def minimum_normalized_coefficient
    num_class.int_radix_power(precision-1)
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

  def next_plus(x)
    Flt::FloatContext.neighbours(x).last
  end

  def next_minus(x)
    Flt::FloatContext.neighbours(x).first
  end

  def next_toward(x, y)
    x, y = x.to_f, y.to_f
    comparison = x <=> y
    return x.copy_sign(y) if comparison == 0
    if comparison == -1
      result = x.next_plus(context)
    else # comparison == 1
      result = x.next_minus(context)
    end
  end

  # Sign: -1 for minus, +1 for plus, nil for nan (note that Float zero is signed)
  def sign(x)
    x = x.to_f
    if x.nan?
      nil
    elsif x.zero?
      # Note that (x.to_s[0,1] == "-" ? -1 : +1) fails under mswin32
      # because in that platform (-0.0).to_s == '0.0'
      (1/x < 0) ? -1 : +1
    else
      x < 0 ? -1 : +1
    end
  end

  # Return copy of x with the sign of y
  def copy_sign(x, y)
    self_sign = sign(x)
    other_sign = y.is_a?(Integer) ? (y < 0 ? -1 : +1) : sign(y)
    if self_sign && other_sign
      if self_sign == other_sign
        x.to_f
      else
        -x.to_f
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
  def split(x)
    x = x.to_f
    sign = sign(x)
    if x.nan?
      exp = :nan
    elsif x.infinite?
      exp = :inf
    else
      coeff,exp = Math.frexp(x)
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
  def to_int_scale(x)
    x = x.to_f
    if special?(x)
      nil
    else
      coeff,exp = Math.frexp(x)
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
  def ulp(x, mode=:low)
    x = x.to_f
    return x if x.nan?
    x = x.abs
    if x < Math.ldexp(1,Float::MIN_EXP) # x < Float::RADIX*Float::MIN_N
      x = Math.ldexp(1,Float::MIN_EXP-Float::MANT_DIG) # res = Float::MIN_D
    elsif x > Float::MAX # x > Math.ldexp(1-Math.ldexp(1,-Float::MANT_DIG),Float::MAX_EXP)
      x = Math.ldexp(1,Float::MAX_EXP-Float::MANT_DIG) # res = Float::MAX - Float::MAX.prev
    else
      f,e = Math.frexp(x.to_f)
      e -= 1 if f==Math.ldexp(1,-1) if mode==:low # assign the smaller ulp to radix powers
      x = Math.ldexp(1,e-Float::MANT_DIG)
    end
    x
  end

  def special?(x)
    x.nan? || x.infinite?
  end

  def normal?(x)
    if x.special? || x.zero?
      false
    else
      x.abs >= Float::MIN_N
    end
  end

  def subnormal?
    if x.special? || x.zero?
      false
    else
      x.abs < Float::MIN_N
    end
  end

  def plus(x)
    x.to_f
  end

  def minus(x)
    -x.to_f
  end

  def to_r(x)
    Support::Rationalizer.to_r(x)
  end

  def rationalize(x, tol = Flt.Tolerance(:epsilon), strict=false)
    if !strict && x.respond_to?(:rationalize) && !(Integer === tol)
      # Float#rationalize was introduced in Ruby 1.9.1
      tol = Tolerance(tol)
      x.rationalize(tol[x])
    else
      case tol
      when Integer
        Rational(*Support::Rationalizer.max_denominator(x, tol, Float))
      else
        Rational(*Support::Rationalizer[tol].rationalize(x))
      end
    end
  end

  class << self
    # Compute the adjacent floating point values: largest value not larger than
    # this and smallest not smaller.
    def neighbours(x)
      f,e = Math.frexp(x.to_f)
      e = Float::MIN_EXP if f==0
      e = [Float::MIN_EXP,e].max
      dx = Math.ldexp(1,e-Float::MANT_DIG) #Math.ldexp(Math.ldexp(1.0,-Float::MANT_DIG),e)

      min_f = 0.5 #0.5==Math.ldexp(2**(bits-1),-Float::MANT_DIG)
      max_f = 1.0 - Math.ldexp(1,-Float::MANT_DIG)

      if f==max_f
        high = x + dx*2
      elsif f==-min_f && e!=Float::MIN_EXP
        high = x + dx/2
      else
        high = x + dx
      end
      if e==Float::MIN_EXP || f!=min_f
        low = x - dx
      elsif f==-max_f
        high = x - dx*2
      else
        low = x - dx/2
      end
      [low, high]
    end

    def float_method(*methods) #:nodoc:
      methods.each do |method|
        if method.is_a?(Array)
          float_method, context_method = method
        else
          float_method = context_method = method
        end
        define_method(context_method) do |x|
          x.to_f.send float_method
        end
      end
    end

    def float_binary_operator(method, op) #:nodoc:
      define_method(method) do |x,y|
        x.to_f.send(op,y)
      end
    end

    def math_function(*methods) #:nodoc:
      methods.each do |method|
        define_method(method) do |*args|
          x = args.shift.to_f
          Math.send(method, x, *args)
        end
        # TODO: consider injecting the math methods into Float
        # Float.send(:define_method, method) do |*args|
        #   Math.send(method, self, *args)
        # end
      end
    end

  end

  float_method :nan?, :infinite?, :zero?, :abs
  float_binary_operator :add, :+
  float_binary_operator :subtract, :-
  float_binary_operator :multiply, :*
  float_binary_operator :divide, :/
  float_binary_operator :power, :**

  math_function :log, :log10, :exp, :sqrt,
                :sin, :cos, :tan, :asin, :acos, :atan, :atan2,
                :sinh, :cosh, :tanh, :asinh, :acosh, :atanh, :hypot

  def ln(x)
    log(x)
  end

  def pi
    Math::PI
  end

  def eval
    yield self
  end

  def math(*parameters, &blk)
    if parameters.empty?
      self.instance_eval &blk
    else
      # needs instance_exe (available in Ruby 1.9, ActiveRecord; TODO: include implementation here)
      self.instance_exec *parameters, &blk
    end
  end

  def representable_digits(b)
    if b == 10
      Float::DIG
    elsif b == radix
      precision
    else
     ((precision-1)*log(radix, b)).floor
    end
  end

  def necessary_digits(b)
    if b == 10
      Float::DECIMAL_DIG
    elsif b == radix
      precision
    else
     (precision*log(radix, b)).ceil + 1
    end
  end

end

# Return a (limited) context object for Float.
# This eases the implementation of functions compatible with either Num or Float values.
def Float.context
  Flt::FloatContext.instance
end

# Is Float('...') correctly rounded, even for subnormal numbers?
def Flt.float_correctly_rounded?
  # That doesn't seem to be the case for mswin32
  @float_correctly_rounded ||= RUBY_PLATFORM.match(/mswin32/).nil?
end
