# Tolerance for floating-point types (Float, Flt::BinNum, Flt::DecNum)
#
# Tolerance can be used to allow for a tolerance in floating-point comparisons.
#
# A Tolerance can be defined independently of the type (floating-point numeric class)
# it will be used with; The actual tolerance value will be compute for a particular reference value, and
# for some kinds of tolerance (e.g. epsilon) a value is not available without a reference:
#
#   tol = Tolerance(3, :decimals)
#   puts tol.value(DecNum('10.0')).inspect        # -> DecNum('0.0005')
#   puts tol.value(10.0).inspect                  # ->  0.0005
#   puts tol.value.inspect                        # -> Rational(1, 2000)
#
#   tol = Tolerance(:epsilon)
#   puts tol.value(DecNum('10.0')).inspect        # -> DecNum('1.00E-26')
#   puts tol.value(10.0).inspect                  # -> 2.22044604925031e-15
#   puts tol.value.inspect                        # -> nil
#
# Tolerances can be:
# * Absolute: the tolerance value is a fixed value independent of the values to be compared.
# * Relative: the tolerance value is adjusted (scaled) to the magnitude of the numbers to be compared,
#   so that it specifies admisible relative error values.
#   Particular cases of relative tolerance are Percent and Permille tolerance.
# * Floating: tolerance is scaled along with the floating-point values. Floating tolerances can be
#   :native (the scaling is done with the same base as the floating point radix), or have a specific base.
#   Currently floating tolerances use the :low convention at the powers of the radix (as ulps). Floating
#   tolerances should be computed at the correct or exact value to be compared, not at an approximation, but
#   note that binary tolerance operations (equals?, less_than?, ...) consider both arguments as approximations.
#   A special case of a floating tolerance are tolerances specified in ULPs.
#
# Tolerances can be specified as:
# * A specific value (valid for any type of tolerance: absolute, relative & floating)
# * A number of digits, or, for specific bases, decimals or bits, available for absolute and floating (significant).
# * Epsilon (or Big epsilon), optionally multiplied by a factor, available for all types of tolerances
# * A number of ULPs, which implies a floating tolerance.
# * A percent or permille value, only for relative tolerances.
#
# There exists a Tolerance-derived class for each valid combination of type of tolerance and specification mode,
# but they all can be defined with the Tolerance() constructor.
# The first parameter to the constructor is the tolerance value, and in some kinds of tolerance it can be
# omitted. Next, the kind of tolerance is passed as a symbol; valid values are:
# * :absolute
# * :relative
# * :floating Generic floating decimal; another parameter can be passed for a specific base
# * :percent a particular kind of relative tolerance
# * :permille a particular kind of relative tolerance
# * :ulps a particular kind of floating tolerance
# * :sig_decimals (significative rounded decimals) a particular kind of floating tolerance; another parameter specifies if rounded
# * :decimals a particular kind of absolute tolerance
# * :sig_bits (significative bits) a particular kind of floating tolerance; another parameter specifies if rouded
# * :epsilon relative tolerance given as a multiple of epsilon (1 by default)
# * :abs_epsilon absolute tolerance given as a multiple of epsilon (1 by default)
# * :flt_epsilon floating tolerance given as a multiple of epsilon (1 by default)
# * :big_epsilon relative tolerance given as a multiple of big-epsilon (1 by default)
# * :abs_big_epsilon absolute tolerance given as a multiple of big-epsilon (1 by default)
# * :flt_big_epsilon floating tolerance given as a multiple of big-epsilon (1 by default)
#
# Examples:
#
#   tol = Tolerance(100, :absolute)
#   puts tol.value(1.0)                                   # -> 100.0
#   puts tol.value(1.5)                                   # -> 100.0
#   puts tol.value(1.0E10)                                # -> 100.0
#   puts tol.eq?(11234.0, 11280.0)                        # -> true
#
#   tol = Tolerance(100, :relative)
#   puts tol.value(1.0)                                   # -> 100.0
#   puts tol.value(1.5)                                   # -> 150.0
#   puts tol.value(1.0E10)                                # -> 1000000000000.0
#   puts tol.eq?(11234.0, 11280.0)                        # -> true
#
#   tol = Tolerance(100, :floating)
#   puts tol.value(1.0)                                   # -> 100.0
#   puts tol.value(1.5)                                   # -> 200.0
#   puts tol.value(1.0E10)                                # -> 1717986918400.0
#   puts tol.eq?(11234.0, 11280.0)                        # -> true
#
#   tol = Tolerance(3, :sig_decimals)
#   puts tol.eq?(1.234,1.23)                              # -> true
#
#   tol = Tolerance(1, :ulps)
#   puts tol.eq?(3.3433, 3.3433.next_plus)                # -> true
#   puts tol.eq?(DecNum('1.1'), DecNum('1.1').next_plus)  # -> true
#
#   tol = Tolerance(1, :percent)
#   puts tol.equal_to?(3.14159, Math::PI)                 # -> true#

require 'flt/num'
require 'flt/float'
require 'flt/bigdecimal'

module Flt

  # The Tolerance class is a base class for all tolerances.
  #
  # Particular tolerance *kinds* (defined by a type of tolerance and the way to specify its value) are
  # implemented in separate classes derived from Tolerance.
  #
  # Derived classes must implement at least one of the methods relative_to() or relative_to_many()
  # and may also redefine cast_value() and descr_value()
  class Tolerance

    def initialize(value)
      @value = value
    end

    # Value of the tolerance for a given (floating-point) quantity
    def value(x=nil)
      if x
        relative_to(x)
      else
        @value
      end
    end

    # Shorthand for value()
    def [](x)
      value(x)
    end

    # Description of the tolerance
    def to_s
      descr_value
    end

    # Is x nearly zero? (zero within tolerance); if a second argument y is specified:
    # is x nearly zero? compared to y?
    def zero?(x, y=nil)
      x.zero? || x.abs < value(y || x)
    end

    # Returns true if the argument is approximately an integer
    def integer?(x)
      # Computing the tolerance at x seems the best option here
      (x-x.round).abs <= relative_to(x)
    end

    # If the argument is close to an integer it rounds it
    def integer(x)
      # return integer?(x) ? x.round : nil
      r = x.round
      ((x-r).abs <= relative_to(x)) ? r : nil
    end

    # Binary comparison operations that treat both arguments equally;

    # less-than: x < y within tolerance
    def lt?(x,y)
      y-x > relative_to_many(:max, x, y)
    end

    # greater_than: x > y within tolerance
    def gt?(x,y)
      x-y > relative_to_many(:max, x, y)
    end

    # equals: x == y within tolerance (relaxed)
    def eq?(x, y)
      (x-y).abs <= relative_to_many(:max, x, y)
    end

    # strongly equals: x == y within tolerance (strict)
    def seq?(x, y)
      (x-y).abs <= relative_to_many(:min, x, y)
    end

    # Binary operations that consider the second value the correct or exact value

    # x < correct value y within tolerance
    def less_than?(x,y)
      y-x > relative_to(y)
    end

    # x > correct value y within tolerance
    def greater_than?(x,y)
      x-y > relative_to(y)
    end

    # x == correct value y within tolerance
    def equal_to?(x, y)
      (x-y).abs <= relative_to(y)
    end

    # This method is redefined in derived classes to compute the tolerance value in relation to the value x;
    #
    # If not redefined, relative_to_many will be used.
    def relative_to(x)
      relative_to_many(:max, x)
    end

    # This method is redefined in derived classes to compute the tolerance value in relation to the values xs;
    # mode must be either :max or :min, and determines if the largerst (relaxed condition) or smallest
    #(strict condition) of the relative tolerances is returned.
    #
    # If not redefined, relative_to will be used, but redefining this method can be used to optimize the
    # performance
    def relative_to_many(mode, *xs)
      xs.map{|x| relative_to(x)}.send(mode)
    end

    # Returns the tolerance reference value for a numeric class; in derived classes this
    # can be redefined to allow for values which change in value or precision depending
    # on the numeric class or context.
    def cast_value(num_class)
      num_class.context.Num(@value)
    end

    # Description of the reference value (can be specialized in derived classes)
    def descr_value
      @value.to_s
    end

    # Class methods
    class <<self

      # Define a tolerance magnitude as a number of digits of the given base. If rounded is true
      # it is assumed that results are rounded to n digits; otherwise truncation or directed rounding
      # may occur and the tolerance will be larger.
      def digits(base, n, rounded=true)
        v = base**(-n)
        v /= 2 if rounded
        v
      end

      # Define a tolerance magnitude as a number of decimal digits. If rounded is true
      # it is assumed that results are rounded to n digits; otherwise truncation or directed rounding
      # may occur and the tolerance will be larger.
      def decimals(n, rounded=true)
        digits 10, n, rounded
      end

      # Define a tolerance magnitude as a number of binary digits. If rounded is true
      # it is assumed that results are rounded to n digits; otherwise truncation or directed rounding
      # may occur and the tolerance will be larger.
      def bits(n, rounded=true)
        digits 10, n, rounded
      end

      # Define a tolerance magnitude in relation to the 'epsilon' of the floating-point type and context.
      # A multiplier may be specified to scale the epsilon.
      def epsilon(num_class, mult=1)
        num_class.context.epsilon*mult
      end

      # Define a tolerance magnitude in relation to the 'big epsilon' of the floating-point type and context.
      # A multiplier may be specified to scale the big epsilon.
      #
      # This is a tolerance that makes multiplication associative when used with FloatingTolerance.
      def big_epsilon(num_class, mult=1)
        context = num_class.context
        e0 = context.epsilon
        # we could compute with round-up instead of using next_plus, but we can't do that with Float
        den = (context.Num(1)-e0/2)
        big_eps = context.next_plus(e0*2/(den*den))
        big_eps*mult
      end

    end

  end

  # Implementation of absolute tolerances
  class AbsoluteTolerance < Tolerance
    def initialize(value)
      super
    end
    def relative_to(x)
      cast_value(x.class)
    end
    def relative_to_many(mode, *xs)
      cast_value(xs.first.class)
    end
  end

  # Implementation of relative tolerances
  class RelativeTolerance < Tolerance
    def initialize(value)
      super
    end
    def relative_to(x)
      x.abs*cast_value(x.class)
    end
    def to_s
      "#{descr_value}/1"
    end
  end

  # Implementation of percent (relative) tolerances
  class PercentTolerance < RelativeTolerance
    def initialize(value)
      super
    end
    def to_s
      "#{descr_value}%"
    end
    def cast_value(num_class)
      num_class.Num(@value)/num_class.Num(100)
    end
  end

  # Implementation of permille (relative) tolerances
  class PermilleTolerance < RelativeTolerance
    def initialize(value)
      super
    end
    def to_s
      "#{descr_value}/1000"
    end
    def cast_value(num_class)
      num_class.Num(@value)/num_class.Num(1000)
    end
  end

  # Implementation of floating tolerances
  class FloatingTolerance < Tolerance
    def initialize(value, radix=:native)
      super(value)
      @radix = radix
    end

    def to_s
      if @radix==:native
        "#{descr_value} flt."
      else
        "#{descr_value} flt.(#{radix})"
      end
    end

    @float_minimum_normalized_fraction = Math.ldexp(1,-1)
    def self.float_minimum_normalized_fraction
      @float_minimum_normalized_fraction
    end

    def self.ref_adjusted_exp
      -1
    end

    def relative_to_many(mode, *xs)
      exp = nil

      num_class = xs.first.class
      context = num_class.context
      xs = xs.map{|x| x = context.Num(x); x.zero? ? context.minimum_normal(context.sign(x)) : x}
      v = cast_value(num_class)

      # TODO: simplify using context
      case xs.first
      when Flt::Num
        # TODO: handle special values
        if @radix == :native || @radix == num_class.radix
          exp = xs.map do |x|
            x = x.normalize
            exp = x.adjusted_exponent
            exp -= 1 if x.coefficient == x.num_class.context.minimum_normalized_coefficient # if :low mode
            exp -= FloatingTolerance.ref_adjusted_exp
            exp
          end.send(mode)
          r = num_class.Num(+1, v.coefficient, v.exponent+exp)
          r = r.normalize if num_class.radix == 2
          r
        elsif @radix==10
          # assert x.class==BinNum
          # TODO: optimize (implement log10 for BinNum)
          exp = xs.map do |x|
            x = x.to_decimal_exact(:exact=>true).normalize
            exp = x.adjusted_exponent
            exp -= 1 if x.coefficient == x.num_class.context.minimum_normalized_coefficient # if :low mode
            exp -= FloatingTolerance.ref_adjusted_exp
            exp
          end.send(mode)
          num_class.from_decimal(Flt.DecNum(+1, 1, exp)*v.to_decimal_exact)
        else
          # assert num_class==DecNum && @radix==2
          exp = xs.map do |x|
            exp = (x.ln/DecNum(2).ln).ceil.to_i - 1 # (x.ln/DecNum(2).ln).floor+1 - 1 if :high mode
            exp -= FloatingTolerance.ref_adjusted_exp
            exp
          end.send(mode)
          v*num_class.Num(2)**exp
        end
      when Float
        if @radix == :native || @radix == Float::RADIX
          exp = xs.map do |x|
            f,e = Math.frexp(x)
            exp = e-1
            exp -= 1 if f==FloatingTolerance.float_minimum_normalized_fraction # if :low mode
            exp -= FloatingTolerance.ref_adjusted_exp
          end.send(mode)
          Math.ldexp(v.to_f, exp)
        else
          # assert @radix==10
          exp = xs.map do |x|
            exp = Math.log10(x.abs).ceil - 1 # Math.log10(x.abs).floor+1 - 1 if :high mode
            exp -= FloatingTolerance.ref_adjusted_exp
          end.send(mode)
          v*10.0**exp
        end
      when BigDecimal
        if @radix == :native || @radix == 10
          exp = xs.map do |x|
            sign,digits,base,exp = x.split
            exp -= 1
            exp -= 1 if digits=="1" # if :low mode
            exp -= FloatingTolerance.ref_adjusted_exp
            exp
          end.send(mode)
          sign, digits, base, vexp = v.split
          BigDecimal.new("0.#{digits}E#{vexp+exp}")
        else
          # assert num_class==BigDecimal && @radix==2
          prec = 10
          exp = xs.map do |x|
            exp = (Flt::DecNum(x.to_s).ln/Flt::DecNum(2).ln).ceil - 1 # ... if :high mode
            exp -= FloatingTolerance.ref_adjusted_exp
            exp
          end.send(mode)
          context.Num(v)*context.Num(2)**exp
        end
      end
    end

  end

  # Implementation of (floating) tolerances given in ULPs (units in the last place)
  class UlpsTolerance < FloatingTolerance
    def initialize(n=nil, num_class=nil)
      @ulps = n || 1
      num_class ||= Float
      context = num_class.context
      unit = context.Num(1)
      n = context.Num(@ulps)
      super(context.ulp(unit)*n)
    end
    def to_s
      "#{@ulps} ulp#{(!@ulps.kind_of?(Numeric) || (@ulps > 1)) ? 's' : ''}"
    end
    def relative_to(x)
      context = x.class.context
      n = context.Num(@ulps)
      context.ulp(x)*n
    end
    def relative_to_many(mode, *xs)
      xs.map{|x| relative_to(x)}.send(mode)
    end
  end

  # Implementation of (floating) tolerances given in number of significant decimal digits
  class SigDecimalsTolerance < FloatingTolerance
    def initialize(ndec, rounded = true)
      super Tolerance.decimals(ndec, rounded), 10
      @decimals = ndec
      @rounded = rounded
    end
    def to_s
      "#{@decimals} sig. #{@rounded ? 'r.' : 'r'}dec."
    end
  end

  # Implementation of (absolute) tolerances given in number of decimal digits
  class DecimalsTolerance < AbsoluteTolerance
    def initialize(ndec, rounded = true)
      super Tolerance.decimals(ndec, rounded)
      @decimals = ndec
      @rounded = rounded
    end
    def to_s
      "#{@decimals} #{@rounded ? 'r.' : 'r'}dec."
    end
  end

  # Implementation of (floating) tolerances given in number of significant bits
  class SigBitsTolerance < FloatingTolerance
    def initialize(ndec, rounded = true)
      super Tolerance.bits(ndec, rounded), 2
      @bits = ndec
      @rounded = rounded
    end
    def to_s
      "#{@bits} sig. #{@rounded ? 'r.' : 'r'}bits"
    end
  end

  # Mixin for tolerances defined by Epsilon or a multiple of it
  module EpsilonMixin
    def initialize(mult=nil)
      @mult = mult || 1
      super nil
    end
    def cast_value(num_class)
      Tolerance.epsilon(num_class, @mult)
    end
    def descr_value
      "#{@mult==1 ? '' : "#{@mult} "} eps."
    end
  end

  # Implementation of (relative) tolerances given as a multiple of Epsilon
  class EpsilonTolerance < RelativeTolerance
    include EpsilonMixin
  end

  # Implementation of (absolute) tolerances given as a multiple of Epsilon
  class AbsEpsilonTolerance < AbsoluteTolerance
    include EpsilonMixin
  end

  # Implementation of (floating) tolerances given as a multiple of Epsilon
  class FltEpsilonTolerance < FloatingTolerance
    include EpsilonMixin
  end

  # Mixin for tolerances defined by Big Epsilon or a multiple of it
  module BigEpsilonMixin
    def initialize(mult=nil)
      @mult = mult || 1
      super nil
    end
    def cast_value(num_class)
      Tolerance.big_epsilon(num_class, @mult)
    end
    def descr_value
      "#{@mult==1 ? '' : "#{@mult} "} big eps."
    end
  end

  # Implementation of (relative) tolerances given as a multiple of Big Epsilon
  class BigEpsilonTolerance < RelativeTolerance
    include BigEpsilonMixin
  end

  # Implementation of (absolute) tolerances given as a multiple of Big Epsilon
  class AbsBigEpsilonTolerance < AbsoluteTolerance
    include EpsilonMixin
  end

  # Implementation of (floating) tolerances given as a multiple of Big Epsilon
  class FltBigEpsilonTolerance < FloatingTolerance
    include BigEpsilonMixin
  end

  module_function
  # Tolerance constructor.
  #
  # The first parameter is the value (magnitude) of the tolerance, and is optional for some tolerances.
  #
  # The next parameter is the kind of tolerance as a symbol. It corresponds to the name of the
  # implementation class minus the Tolerance suffix, and converted to snake-case (lowercase with underscores to
  # separate words.)
  #
  # Finally any additional parameters admitted by the class constructor can be passed.
  def Tolerance(*args)
    return args.first if args.size == 1 && Tolerance === args.first
    if args.first.is_a?(Symbol)
      value = nil
    else
      value = args.shift
    end
    cls_name = (args.shift || :absolute).to_s.gsub(/(^|_)(.)/){$2.upcase} + "Tolerance"
    Flt.const_get(cls_name).new(value, *args)
  end

end # Flt

