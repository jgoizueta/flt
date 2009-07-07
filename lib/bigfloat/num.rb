require 'bigfloat/support'
require 'bigfloat/version'

require 'bigdecimal'
require 'forwardable'
require 'rational'
require 'monitor'
require 'ostruct'

module BigFloat

# TODO: update documentation; check rdoc results for clarity given the new Num/Decimal/BinFloat structure
# TODO: Burger and Dybvig formatting algorithms: add formatting options
# TODO: for BinFloat#to_s consider using the context precision as a minimum and/or adding an exact mode
# TODO: for BinFloat(String) with non exact precision, use context precision only if no exact conversion is possible
# TODO: selecting the kind of ulp is awkward; consider one of these options:
#       * don't support variant ulps; always use Muller's ulp
#       * use an options hash for the kind of ulp parameter
#       * keep the kind of ulp in the context
# TODO: Rename classes:
#       * Names such as BigFloat, APFloat, are not accurate since this module also includes
#         extensions to Float.
#       * Decide whether to use same module for Float-Formats & this (Num etc.)
#       * Use symmetrical naming? (Decimal/Binary DecNum/BinNum ...) or asymmetrical (Decimal/BinFloat...)
#       * Names to be considered:
#         - BigFloat: FltPnt, APFloat, FP, Flt, ...
#         - Decimal:  DecFloat, Dec, DecNum, BigDec, ...
#         - BinFloat: Binary, Bin, BinNum, APFloat, MPFloat, BigFloat, ...

class Num # APFloat (arbitrary precision float) MPFloat ...

  extend Support # allows use of unqualified FlagValues(), Flags(), etc.
  include Support::AuxiliarFunctions # make auxiliar functions available unqualified to instance menthods

  ROUND_HALF_EVEN = :half_even
  ROUND_HALF_DOWN = :half_down
  ROUND_HALF_UP = :half_up
  ROUND_FLOOR = :floor
  ROUND_CEILING = :ceiling
  ROUND_DOWN = :down
  ROUND_UP = :up
  ROUND_05UP = :up05

  # Numerical conversion base support
  # base (default) coercible types associated to procedures for numerical conversion
  @_base_coercible_types = {
    Integer=>lambda{|x, context| x>=0 ? [+1,x,0] : [-1,-x,0]},
    Rational=>lambda{|x, context|
      x, y = context.num_class.new(x.numerator), context.num_class.new(x.denominator)
      z = x.divide(y, context)
      z
    }
  }
  @_base_conversions = {
    Integer=>:to_i, Rational=>:to_r, Float=>:to_f
  }
  class <<self
    attr_reader :_base_coercible_types
    attr_reader :_base_conversions
    def base_coercible_types
      Num._base_coercible_types
    end
    def base_conversions
      Num._base_conversions
    end
    # We use this two level scheme to acces base_... because we're using instance variables of the object
    # Num to store the base_... objects (and we store them to avoid generating them each time) and to access
    # them would requiere that derived classes define their own versios of the accesors, even if they
    # only call super.
  end

  # Base class for errors.
  class Error < StandardError
  end

  # Base class for exceptions.
  #
  # All exception conditions derive from this class.
  # The exception classes also define the values returned when trapping is disable for
  # a particular exception.
  class Exception < StandardError
    attr :context
    def initialize(context=nil)
      @context = context
    end

    # Defines the value returned when trapping is inactive
    # for the condition. The arguments are those passed to
    # Context#exception after the message.
    def self.handle(context, *args)
    end
  end

  # Invalid operation exception.
  #
  # The result of the operation is a quiet positive NaN,
  # except when the cause is a signaling NaN, in which case the result is
  # also a quiet NaN, but with the original sign, and an optional
  # diagnostic information.
  class InvalidOperation < Exception
    def self.handle(context, *args)
      if args.size>0
        sign, coeff, exp = args.first.split
        context.num_class.new([sign, coeff, :nan])._fix_nan(context)
      else
        context.num_class.nan
      end
    end
    def initialize(context=nil, *args)
      @value = args.first if args.size>0
      super context
    end
  end

  # Division by zero exception.
  #
  # The result of the operation is +/-Infinity, where the sign is the product
  # of the signs of the operands for divide, or 1 for an odd power of -0.
  class DivisionByZero < Exception
    def self.handle(context,sign,*args)
      context.num_class.infinity(sign)
    end
    def initialize(context=nil, sign=nil, *args)
      @sign = sign
      super context
    end
  end

  # Cannot perform the division adequately exception.
  #
  # This occurs and signals invalid-operation if the integer result of a
  # divide-integer or remainder operation had too many digits (would be
  # longer than precision).
  # The result is NaN.
  class DivisionImpossible < Exception
    def self.handle(context,*args)
      context.num_class.nan
    end
  end

  # Undefined result of division exception.
  #
  # This occurs and signals invalid-operation if division by zero was
  # attempted (during a divide-integer, divide, or remainder operation), and
  # the dividend is also zero.
  #  The result is NaN.
  class DivisionUndefined < Exception
    def self.handle(context,*args)
      context.num_class.nan
    end
  end

  # Inexact Exception.
  #
  # This occurs and signals inexact whenever the result of an operation is
  # not exact (that is, it needed to be rounded and any discarded digits
  # were non-zero), or if an overflow or underflow condition occurs.  The
  # result in all cases is unchanged unless the context has exact precision,
  # in which case the result is Nan
  class Inexact < Exception
    def self.handle(context, *args)
      context.num_class.nan if context.exact?
    end
  end

  # Overflow Exception.
  #
  # This occurs and signals overflow if the adjusted exponent of a result
  # (from a conversion or from an operation that is not an attempt to divide
  # by zero), after rounding, would be greater than the largest value that
  # can be handled by the implementation (the value Emax).
  #
  # The result depends on the rounding mode:
  #
  # For round-half-up and round-half-even (and for round-half-down and
  # round-up, if implemented), the result of the operation is +/-Infinity,
  # where the sign is that of the intermediate result.  For round-down, the
  # result is the largest finite number that can be represented in the
  # current precision, with the sign of the intermediate result.  For
  # round-ceiling, the result is the same as for round-down if the sign of
  # the intermediate result is 1, or is +Infinity otherwise.  For round-floor,
  # the result is the same as for round-down if the sign of the intermediate
  # result is 0, or is -Infinity otherwise.  In all cases, Inexact and Rounded
  # will also be raised.
  class Overflow < Exception
    def self.handle(context, sign, *args)
      if [:half_up, :half_even, :half_down, :up].include?(context.rounding)
        context.num_class.infinity(sign)
      elsif sign==+1
        if context.rounding == :ceiling
          context.num_class.infinity(sign)
        else
          context.num_class.new([sign, context.num_class.int_radix_power(context.precision) - 1, context.emax - context.precision + 1])
        end
      elsif sign==-1
        if context.rounding == :floor
          context.num_class.infinity(sign)
        else
          context.num_class.new([sign, context.num_class.int_radix_power(context.precision) - 1, context.emax - context.precision + 1])
        end
      end
    end
    def initialize(context=nil, sign=nil, *args)
      @sign = sign
      super context
    end
  end

  # Numerical Underflow with result rounded to 0 exception.
  #
  # This occurs and signals underflow if a result is inexact and the
  # adjusted exponent of the result would be smaller (more negative) than
  # the smallest value that can be handled by the implementation (the value
  # emin).  That is, the result is both inexact and subnormal.
  #
  # The result after an underflow will be a subnormal number rounded, if
  # necessary, so that its exponent is not less than Etiny.  This may result
  # in 0 with the sign of the intermediate result and an exponent of etiny.
  #
  # In all cases, Inexact, Rounded, and Subnormal will also be raised.
  class Underflow < Exception
  end

  # Clamped exception: exponent of a 0 changed to fit bounds.
  #
  # This occurs and signals clamped if the exponent of a result has been
  # altered in order to fit the constraints of a specific concrete
  # representation.  This may occur when the exponent of a zero result would
  # be outside the bounds of a representation, or when a large normal
  # number would have an encoded exponent that cannot be represented.  In
  # this latter case, the exponent is reduced to fit and the corresponding
  # number of zero digits are appended to the coefficient ("fold-down").
  class Clamped < Exception
  end

  # Invalid context exception.
  #
  # This occurs and signals invalid-operation if an invalid context was
  # detected during an operation.  This can occur if contexts are not checked
  # on creation and either the precision exceeds the capability of the
  # underlying concrete representation or an unknown or unsupported rounding
  # was specified.  These aspects of the context need only be checked when
  # the values are required to be used.  The result is NaN.
  class InvalidContext < Exception
    def self.handle(context,*args)
      context.num_class.nan
    end
  end

  # Number got rounded exception (not  necessarily changed during rounding).
  #
  # This occurs and signals rounded whenever the result of an operation is
  # rounded (that is, some zero or non-zero digits were discarded from the
  # coefficient), or if an overflow or underflow condition occurs.  The
  # result in all cases is unchanged.
  class Rounded < Exception
  end

  # Exponent < emin before rounding exception.
  #
  # This occurs and signals subnormal whenever the result of a conversion or
  # operation is subnormal (that is, its adjusted exponent is less than
  # Emin, before any rounding).  The result in all cases is unchanged.
  class Subnormal < Exception
  end

  # Conversion syntax error exception (Trying to convert badly formed string.)
  #
  # This occurs and signals invalid-operation if an string is being
  # converted to a number and it does not conform to the numeric string
  # syntax.  The result is NaN.
  class ConversionSyntax < InvalidOperation
    def self.handle(context, *args)
      context.num_class.nan
    end
  end

  EXCEPTIONS = FlagValues(Clamped, InvalidOperation, DivisionByZero, Inexact, Overflow, Underflow,
                          Rounded, Subnormal, DivisionImpossible, ConversionSyntax)

  def self.Flags(*values)
    BigFloat::Support::Flags(EXCEPTIONS,*values)
  end

  class ContextBase
    # If an options hash is passed, the options are
    # applied to the default context; if a Context is passed as the first
    # argument, it is used as the base instead of the default context.
    #
    # The valid options are:
    # * :rounding : one of :half_even, :half_down, :half_up, :floor,
    #   :ceiling, :down, :up, :up05
    # * :precision : number of digits (or 0 for exact precision)
    # * :exact : if true precision is ignored and Inexact conditions are trapped,
    #            if :quiet it set exact precision but no trapping;
    # * :traps : a Flags object with the exceptions to be trapped
    # * :flags : a Flags object with the raised flags
    # * :ignored_flags : a Flags object with the exceptions to be ignored
    # * :emin, :emax : minimum and maximum adjusted exponents
    # * :elimit : the exponent limits can also be defined by a single value;
    #   if positive it is taken as emax and emin=1-emax; otherwiae it is
    #   taken as emin and emax=1-emin. Such limits comply with IEEE 754-2008
    # * :capitals : (true or false) to use capitals in text representations
    # * :clamp : (true or false) enables clamping
    #
    # See also the context constructor method Decimal.Context().
    def initialize(num_class, *options)
      @num_class = num_class

      if options.first.kind_of?(ContextBase)
        base = options.shift
        copy_from base
      else
        @exact = false
        @rounding = @emin = @emax = nil
        @capitals = false
        @clamp = false
        @ignored_flags = Num::Flags()
        @traps = Num::Flags()
        @flags = Num::Flags()
        @coercible_type_handlers = num_class.base_coercible_types.dup
        @conversions = num_class.base_conversions.dup
      end
      assign options.first

    end

    def num_class
      @num_class
    end

    def Num(*args)
      num_class.Num(*args)
    end
    private :Num

    def radix
      @num_class.radix
    end

    # Integral power of the base: radix**n for integer n; returns an integer.
    def int_radix_power(n)
      @num_class.int_radix_power(n)
    end

    # Multiply by an integral power of the base: x*(radix**n) for x,n integer;
    # returns an integer.
    def int_mult_radix_power(x,n)
      @num_class.int_mult_radix_power(x,n)
    end

    # Divide by an integral power of the base: x/(radix**n) for x,n integer;
    # returns an integer.
    def int_div_radix_power(x,n)
      @num_class.int_div_radix_power(x,n)
    end


    attr_accessor :rounding, :emin, :emax, :flags, :traps, :ignored_flags, :capitals, :clamp

    # TODO: consider the convenience of adding accessors of this kind:
    # def rounding(new_rounding=nil)
    #   old_rounding = @rounding
    #   @rounding = new_rounding unless new_rounding.nil?
    #   old_rounding
    # end

    # Ignore all flags if they are raised
    def ignore_all_flags
      #@ignored_flags << EXCEPTIONS
      @ignored_flags.set!
    end

    # Ignore a specified set of flags if they are raised
    def ignore_flags(*flags)
      #@ignored_flags << flags
      @ignored_flags.set(*flags)
    end

    # Stop ignoring a set of flags, if they are raised
    def regard_flags(*flags)
      @ignored_flags.clear(*flags)
    end

    # 'tiny' exponent (emin - precision + 1)
    # is the minimum valid value for the (integral) exponent
    def etiny
      emin - precision + 1
    end

    # top exponent (emax - precision + 1)
    # is the maximum valid value for the (integral) exponent
    def etop
      emax - precision + 1
    end

    # Set the exponent limits, according to IEEE 754-2008
    # if e > 0 it is taken as emax and emin=1-emax
    # if e < 0  it is taken as emin and emax=1-emin
    def elimit=(e)
      @emin, @emax = [elimit, 1-elimit].sort
    end

    # synonym for precision()
    def digits
      self.precision
    end

    # synonym for precision=()
    def digits=(n)
      self.precision=n
    end

    # synonym for precision()
    def prec
      self.precision
    end

    # synonym for precision=()
    def prec=(n)
      self.precision = n
    end

    # is clamping enabled?
    def clamp?
      @clamp
    end

    # Set the number of digits of precision.
    # If 0 is set the precision turns to be exact.
    def precision=(n)
      @precision = n
      @exact = false unless n==0
      update_precision
      n
    end

    # Number of digits of precision
    def precision
      @precision
    end

    # Enables or disables the exact precision
    def exact=(v)
      @exact = v
      update_precision
      v
    end

    # Returns true if the precision is exact
    def exact
      @exact
    end

    # Returns true if the precision is exact
    def exact?
      @exact
    end

    # Alters the contexts by assigning options from a Hash. See Decimal#new() for the valid options.
    def assign(options)
      if options
        @rounding = options[:rounding] unless options[:rounding].nil?
        @precision = options[:precision] unless options[:precision].nil?
        @traps = Decimal::Flags(options[:traps]) unless options[:traps].nil?
        @flags = Decimal::Flags(options[:flags]) unless options[:flags].nil?
        @ignored_flags = Decimal::Flags(options[:ignored_flags]) unless options[:ignored_flags].nil?
        if elimit=options[:elimit]
          @emin, @emax = [elimit, 1-elimit].sort
        end
        @emin = options[:emin] unless options[:emin].nil?
        @emax = options[:emax] unless options[:emax].nil?
        @capitals = options[:capitals ] unless options[:capitals ].nil?
        @clamp = options[:clamp ] unless options[:clamp ].nil?
        @exact = options[:exact ] unless options[:exact ].nil?
        update_precision
      end
    end

    attr_reader :coercible_type_handlers, :conversions
    protected :coercible_type_handlers, :conversions

    # Copy the state from other Context object.
    def copy_from(other)
      raise TypeError, "Assign #{other.num_class} context to #{self.num_class} context" if other.num_class != self.num_class
      @rounding = other.rounding
      @precision = other.precision
      @traps = other.traps.dup
      @flags = other.flags.dup
      @ignored_flags = other.ignored_flags.dup
      @emin = other.emin
      @emax = other.emax
      @capitals = other.capitals
      @clamp = other.clamp
      @exact = other.exact
      @coercible_type_handlers = other.coercible_type_handlers.dup
      @conversions = other.conversions.dup
    end

    def dup
      self.class.new(self)
    end

    CONDITION_MAP = {
      #ConversionSyntax=>InvalidOperation,
      #DivisionImpossible=>InvalidOperation,
      DivisionUndefined=>InvalidOperation,
      InvalidContext=>InvalidOperation
    }

    # Raises a flag (unless it is being ignores) and raises and
    # exceptioin if the trap for it is enabled.
    def exception(cond, msg='', *params)
      err = (CONDITION_MAP[cond] || cond)
      return err.handle(self, *params) if @ignored_flags[err]
      @flags << err # @flags[err] = true
      return cond.handle(self, *params) if !@traps[err]
      raise err.new(*params), msg
    end

    # Addition of two decimal numbers
    def add(x,y)
      _convert(x).add(y,self)
    end

    # Subtraction of two decimal numbers
    def subtract(x,y)
      _convert(x).subtract(y,self)
    end

    # Multiplication of two decimal numbers
    def multiply(x,y)
      _convert(x).multiply(y,self)
    end

    # Division of two decimal numbers
    def divide(x,y)
      _convert(x).divide(y,self)
    end

    # Absolute value of a decimal number
    def abs(x)
      _convert(x).abs(self)
    end

    # Unary prefix plus operator
    def plus(x)
      _convert(x).plus(self)
    end

    # Unary prefix minus operator
    def minus(x)
      _convert(x)._neg(self)
    end

    # Converts a number to a string
    def to_string(x, eng=false)
      _convert(x)._fix(self).to_s(eng, self)
    end

    # Converts a number to a string, using scientific notation
    def to_sci_string(x)
      to_string x, false
    end

    # Converts a number to a string, using engineering notation
    def to_eng_string(x)
      to_string x, true
    end

    # Reduces an operand to its simplest form
    # by removing trailing 0s and incrementing the exponent.
    # (formerly called normalize in GDAS)
    def reduce(x)
      _convert(x).reduce(self)
    end

    # normalizes so that the coefficient has precision digits
    # (this is not the old GDA normalize function)
    def normalize(x)
      _convert(x).normalize(self)
    end

    # Adjusted exponent of x returned as a Decimal value.
    def logb(x)
      _convert(x).logb(self)
    end

    # Adds the second value to the exponent of the first: x*(radix**y)
    #
    # y must be an integer
    def scaleb(x, y)
      _convert(x).scaleb(y,self)
    end

    # Exponent in relation to the significand as an integer
    # normalized to precision digits. (minimum exponent)
    def normalized_integral_exponent(x)
      x = _convert(x)
      x.exponent - (precision - x.number_of_digits)
    end

    # Significand normalized to precision digits
    # x == normalized_integral_significand(x) * radix**(normalized_integral_exponent)
    def normalized_integral_significand(x)
      x = _convert(x)
      x.coefficient*(num_class.int_radix_power(precision - x.number_of_digits))
    end

    # Returns both the (signed) normalized integral significand and the corresponding exponent
    def to_normalized_int_scale(x)
      x = _convert(x)
      [x.sign*normalized_integral_significand(x), normalized_integral_exponent(x)]
    end

    # Is a normal number?
    def normal?(x)
      _convert(x).normal?(self)
    end

    # Is a subnormal number?
    def subnormal?(x)
      _convert(x).subnormal?(self)
    end

    # Classifies a number as one of
    # 'sNaN', 'NaN', '-Infinity', '-Normal', '-Subnormal', '-Zero',
    #  '+Zero', '+Subnormal', '+Normal', '+Infinity'
    def number_class(x)
      _convert(x).number_class(self)
    end

    # Square root of a decimal number
    def sqrt(x)
      _convert(x).sqrt(self)
    end

    # Ruby-style integer division: (x/y).floor
    def div(x,y)
      _convert(x).div(y,self)
    end

    # Ruby-style modulo: x - y*div(x,y)
    def modulo(x,y)
      _convert(x).modulo(y,self)
    end

    # Ruby-style integer division and modulo: (x/y).floor, x - y*(x/y).floor
    def divmod(x,y)
      _convert(x).divmod(y,self)
    end

    # General Decimal Arithmetic Specification integer division: (x/y).truncate
    def divide_int(x,y)
      _convert(x).divide_int(y,self)
    end

    # General Decimal Arithmetic Specification remainder: x - y*divide_int(x,y)
    def remainder(x,y)
      _convert(x).remainder(y,self)
    end

    # General Decimal Arithmetic Specification remainder-near
    #  x - y*round_half_even(x/y)
    def remainder_near(x,y)
      _convert(x).remainder_near(y,self)
    end

    # General Decimal Arithmetic Specification integer division and remainder:
    #  (x/y).truncate, x - y*(x/y).truncate
    def divrem(x,y)
      _convert(x).divrem(y,self)
    end

    # Fused multiply-add.
    #
    # Computes (x*y+z) with no rounding of the intermediate product x*y.
    def fma(x,y,z)
      _convert(x).fma(y,z,self)
    end

    # Compares like <=> but returns a Decimal value.
    # * -1 if x < y
    # * 0 if x == b
    # * +1 if x > y
    # * NaN if x or y is NaN
    def compare(x,y)
      _convert(x).compare(y, self)
    end

    # Returns a copy of x with the sign set to +
    def copy_abs(x)
      _convert(x).copy_abs
    end

    # Returns a copy of x with the sign inverted
    def copy_negate(x)
      _convert(x).copy_negate
    end

    # Returns a copy of x with the sign of y
    def copy_sign(x,y)
      _convert(x).copy_sign(y)
    end

    # Rescale x so that the exponent is exp, either by padding with zeros
    # or by truncating digits.
    def rescale(x, exp, watch_exp=true)
      _convert(x).rescale(exp, self, watch_exp)
    end

    # Quantize x so its exponent is the same as that of y.
    def quantize(x, y, watch_exp=true)
      _convert(x).quantize(y, self, watch_exp)
    end

    # Return true if x and y have the same exponent.
    #
    # If either operand is a special value, the following rules are used:
    # * return true if both operands are infinities
    # * return true if both operands are NaNs
    # * otherwise, return false.
    def same_quantum?(x,y)
      _convert(x).same_quantum?(y)
    end

    # Rounds to a nearby integer.
    #
    # See also: Decimal#to_integral_value(), which does exactly the same as
    # this method except that it doesn't raise Inexact or Rounded.
    def to_integral_exact(x)
      _convert(x).to_integral_exact(self)
    end

    # Rounds to a nearby integerwithout raising inexact, rounded.
    #
    # See also: Decimal#to_integral_exact(), which does exactly the same as
    # this method except that it may raise Inexact or Rounded.
    def to_integral_value(x)
      _convert(x).to_integral_value(self)
    end

    # Returns the largest representable number smaller than x.
    def next_minus(x)
      _convert(x).next_minus(self)
    end

    # Returns the smallest representable number larger than x.
    def next_plus(x)
      _convert(x).next_plus(self)
    end

    # Returns the number closest to x, in the direction towards y.
    #
    # The result is the closest representable number to x
    # (excluding x) that is in the direction towards y,
    # unless both have the same value.  If the two operands are
    # numerically equal, then the result is a copy of x with the
    # sign set to be the same as the sign of y.
    def next_toward(x, y)
      _convert(x).next_toward(y, self)
    end

    # ulp (unit in the last place) according to the definition proposed by J.M. Muller in
    # "On the definition of ulp(x)" INRIA No. 5504
    def ulp(x=nil, mode=:low)
      x ||= 1
      _convert(x).ulp(self, mode)
    end

    # Some singular Decimal values that depend on the context

    # Maximum finite number
    def maximum_finite(sign=+1)
      return exception(InvalidOperation, "Exact context maximum finite value") if exact?
      # equals +Num(+1, 1, emax)
      # equals Num.infinity.next_minus(self)
      Num(sign, num_class.int_radix_power(precision)-1, etop)
    end

    # Minimum positive normal number
    def minimum_normal(sign=+1)
      return exception(InvalidOperation, "Exact context maximum normal value") if exact?
      #Num(sign, 1, emin).normalize(self)
      Num(sign, minimum_normalized_coefficient, etiny)
    end

    # Maximum subnormal number
    def maximum_subnormal(sign=+1)
      return exception(InvalidOperation, "Exact context maximum subnormal value") if exact?
      # equals mininum_normal.next_minus(self)
      Num(sign, num_class.int_radix_power(precision-1)-1, etiny)
    end

    # Minimum nonzero positive number (minimum positive subnormal)
    def minimum_nonzero(sign=+1)
      return exception(InvalidOperation, "Exact context minimum nonzero value") if exact?
      Num(sign, 1, etiny)
    end

    # This is the difference between 1 and the smallest Decimal
    # value greater than 1: (Decimal(1).next_plus - Decimal(1))
    def epsilon(sign=+1)
      return exception(InvalidOperation, "Exact context epsilon") if exact?
      Num(sign, 1, 1-precision)
    end

    # The strict epsilon is the smallest value that produces something different from 1
    # wehen added to 1. It may be smaller than the general epsilon, because
    # of the particular rounding rules used.
    def strict_epsilon(sign=+1)
      return exception(InvalidOperation, "Exact context strict epsilon") if exact?
      # assume radix is even (num_class.radix%2 == 0)
      case rounding
      when :down, :floor
        # largest epsilon: 0.0...10 (precision digits shown to the right of the decimal point)
        exp = 1-precision
        coeff = 1
      when :half_even, :half_down #, :up #  :up #     :down,    :half_down, :up05, :floor
        # next largest:    0.0...050...1 (+precision-1 additional digits here)
        exp = 1-2*precision
        coeff = 1 + num_class.int_radix_power(precision)/2
      when :half_up
        # next largest:    0.0...05 (precision digits shown to the right of the decimal point)
        exp = 1-2*precision
        coeff = num_class.int_radix_power(precision)/2
      when :up, :ceiling, :up05
        # smallest epsilon
        return minimum_nonzero(sign)
      end
      return Num(sign, coeff, exp)
    end

    # This is the maximum relative error corresponding to 1/2 ulp:
    #  (radix/2)*radix**(-precision) == epsilon/2
    # This is called "machine epsilon" in Goldberg's "What Every Computer Scientist..."
    def half_epsilon(sign=+1)
      Num(sign, num_class.radix/2, -precision)
    end

    def to_s
      inspect
    end

    def inspect
      class_name = self.class.to_s.split('::').last
      "<#{class_name}:\n" +
      instance_variables.map { |v| "  #{v}: #{eval(v).inspect}"}.join("\n") +
      ">\n"
    end

    # Maximum integral significand value for numbers using this context's precision.
    def maximum_coefficient
      if exact?
        exception(InvalidOperation, 'Exact maximum coefficient')
        nil
      else
        num_class.int_radix_power(precision)-1
      end
    end

    # Minimum value of a normalized coefficient (normalized unit)
    def minimum_normalized_coefficient
      if exact?
        exception(InvalidOperation, 'Exact maximum coefficient')
        nil
      else
        num_class.int_radix_power(precision-1)
      end
    end

    # Maximum number of diagnostic digits in NaNs for numbers using this context's precision.
    def maximum_nan_diagnostic_digits
      if exact?
        nil # ?
      else
        precision - (clamp ? 1 : 0)
      end
    end

    # Internal use: array of numeric types that be coerced to Decimal.
    def coercible_types
      @coercible_type_handlers.keys
    end

    # Internal use: array of numeric types that be coerced to Decimal, including Decimal
    def coercible_types_or_num
      [num_class] + coercible_types
    end

    # Internally used to convert numeric types to Decimal (or to an array [sign,coefficient,exponent])
    def _coerce(x)
      c = x.class
      while c!=Object && (h=@coercible_type_handlers[c]).nil?
        c = c.superclass
      end
      if h
        h.call(x, self)
      else
        nil
      end
    end

    # Define a numerical conversion from type to Decimal.
    # The block that defines the conversion has two parameters: the value to be converted and the context and
    # must return either a Decimal or [sign,coefficient,exponent]
    def define_conversion_from(type, &blk)
      @coercible_type_handlers[type] = blk
    end

    # Define a numerical conversion from Decimal to type as an instance method of Decimal
    def define_conversion_to(type, &blk)
      @conversions[type] = blk
    end

    # Convert a Decimal x to other numerical type
    def convert_to(type, x)
      converter = @conversions[type]
      if converter.nil?
        raise TypeError, "Undefined conversion from Decimal to #{type}."
      elsif converter.is_a?(Symbol)
        x.send converter
      else
        converter.call(x)
      end
    end

    private

    def _convert(x)
      # cannot call AuxiliarFunctions._convert now because it needs num_class
      # alternatives:
      #  num_class.send(:_convert, x) # cannot num_class._convert because it is private
      #  extend ContextBase with AuxiliarFunctions
      @num_class.send :_convert, x
    end

    def update_precision
      if @emax && !@emin
        @emin = 1 - @emax
      elsif @emin && !@emax
        @emax = 1 - @emin
      end
      if @exact || @precision==0
        quiet = (@exact == :quiet)
        @exact = true
        @precision = 0
        @traps << Inexact unless quiet
        @ignored_flags[Inexact] = false
      else
        @traps[Inexact] = false
      end
    end

  end


  # Context constructor; if an options hash is passed, the options are
  # applied to the default context; if a Context is passed as the first
  # argument, it is used as the base instead of the default context.
  #
  # See Context#new() for the valid options
  def self.Context(*args)
    case args.size
      when 0
        base = self::DefaultContext
      when 1
        arg = args.first
        if arg.instance_of?(self::Context)
          base = arg
          options = nil
        elsif arg.instance_of?(Hash)
          base = self::DefaultContext
          options = arg
        else
          raise TypeError,"invalid argument for #{num_class}.Context"
        end
      when 2
        base = args.first
        options = args.last
      else
        raise ArgumentError,"wrong number of arguments (#{args.size} for 0, 1 or 2)"
    end

    if options.nil? || options.empty?
      base
    else
      self::Context.new(base, options)
    end

  end

  # Define a context by passing either of:
  # * A Context object
  # * A hash of options (or nothing) to alter a copy of the current context.
  # * A Context object and a hash of options to alter a copy of it
  def self.define_context(*options)
    context = options.shift if options.first.instance_of?(self::Context)
    if context && options.empty?
      context
    else
      context ||= self.context
      self.Context(context, *options)
    end
  end

  # This makes the class define context accesible to instance methods
  def define_context(*options)
    self.class.define_context(*options)
  end
  private :define_context

  # The current context (thread-local).
  # If arguments are passed they are interpreted as in Decimal.define_context() to change
  # the current context.
  # If a block is given, this method is a synonym for Decimal.local_context().
  def self.context(*args, &blk)
    if blk
      # setup a local context
      local_context(*args, &blk)
    elsif args.empty?
      # return the current context
      # return the current context
      self._context = self::DefaultContext.dup if _context.nil?
      _context
    else
      # change the current context
      # TODO: consider doing self._context = ... here
      # so we would have Decimal.context = c that assigns a duplicate of c
      # and Decimal.context c to set alias c
      self.context = define_context(*args)
    end
  end

  # Change the current context (thread-local).
  def self.context=(c)
    self._context = c.dup
  end

  # Defines a scope with a local context. A context can be passed which will be
  # set a the current context for the scope; also a hash can be passed with
  # options to apply to the local scope.
  # Changes done to the current context are reversed when the scope is exited.
  def self.local_context(*args)
    keep = self.context # use this so _context is initialized if necessary
    self.context = define_context(*args) # this dups the assigned context
    result = yield _context
    # TODO: consider the convenience of copying the flags from Decimal.context to keep
    # This way a local context does not affect the settings of the previous context,
    # but flags are transferred.
    # (this could be done always or be controlled by some option)
    #   keep.flags = Decimal.context.flags
    # Another alternative to consider: logically or the flags:
    #   keep.flags ||= Decimal.context.flags # (this requires implementing || in Flags)
    self._context = keep
    result
  end

  class <<self
    # This is the thread-local context storage low level interface
    protected
    def _context #:nodoc:
      # TODO: memoize the variable id
      Thread.current["BigFloat::#{self}.context"]
    end
    def _context=(c) #:nodoc:
      Thread.current["BigFloat::#{self}.context"] = c
    end
  end

  def num_class
    self.class
  end

  class <<self
    def num_class
      self
    end
  end

  class << self
    # A decimal number with value zero and the specified sign
    def zero(sign=+1)
      new [sign, 0, 0]
    end

    # A decimal infinite number with the specified sign
    def infinity(sign=+1)
      new [sign, 0, :inf]
    end

    # A decimal NaN (not a number)
    def nan()
      new [+1, nil, :nan]
    end
  end

  def initialize(*args)
    context = nil
    if args.size>0 && args.last.kind_of?(ContextBase)
      context ||= args.pop
    elsif args.size>1 && args.last.instance_of?(Hash)
      context ||= args.pop
    elsif args.size==1 && args.last.instance_of?(Hash)
      arg = args.last
      args = [arg[:sign], args[:coefficient], args[:exponent]]
      arg.delete :sign
      arg.delete :coefficient
      arg.delete :exponent
      context ||= arg
    end
    args = args.first if args.size==1 && args.first.is_a?(Array)

    context = define_context(context)

    case args.size
    when 3
      # internal representation
      @sign, @coeff, @exp = args
      # TO DO: validate

    when 2
      # signed integer and scale
      @coeff, @exp = args
      if @coeff < 0
        @sign = -1
        @coeff = -@coeff
      else
        @sign = +1
      end

    when 1
      arg = args.first
      case arg

      when num_class
        @sign, @coeff, @exp = arg.split

      when *context.coercible_types
        v = context._coerce(arg)
        @sign, @coeff, @exp = v.is_a?(Num) ? v.split : v

      when String
        if arg.strip != arg
          @sign,@coeff,@exp = context.exception(ConversionSyntax, "no trailing or leading whitespace is permitted").split
          return
        end
        m = _parser(arg)
        if m.nil?
          @sign,@coeff,@exp = context.exception(ConversionSyntax, "Invalid literal for Decimal: #{arg.inspect}").split
          return
        end
        @sign =  (m.sign == '-') ? -1 : +1
        if m.int || m.onlyfrac
          if m.int
            intpart = m.int
            fracpart = m.frac
          else
            intpart = ''
            fracpart = m.onlyfrac
          end
          exp = m.exp.to_i
          if fracpart
            coeff = (intpart+fracpart).to_i
            exp -= fracpart.size
          else
            coeff = intpart.to_i
          end
          if num_class.radix != 10
            # convert coeff*10**exp to coeff'*radix**exp'
            # coeff, exp = num_class.decimal_to_radix(coeff, exp, context)
            # Unlike definition of a Decimal by a text literal, when a text (decimal) literal is converted
            # to a BinFloat rounding is performed as dictated by the context, unlike exact precision is
            # requested. To avoid rounding without exact mode, the number should be constructed by
            # givin the sign, coefficient and exponent.
            if (10%num_class.radix) == 0
              rounding = context.rounding
              if @sign == -1
                if rounding == :ceiling
                  rounding = :floor
                elsif rounding == :floor
                  rounding = :ceiling
                end
              end
              # TODO: for exact rounding, use BurgerDybvig.float_to_digits (to convert base 10 to base 2)
              # generating the minimum number of digits for the input precision (convert input to Decimal first)
              # then check for an exact result.
              ans, exact = Support::Clinger.algM(context, coeff, exp, rounding, 10)
              context.exception(Inexact,"Inexact decimal to radix #{num_class.radix} conversion") if !exact
              if !exact && context.exact?
                @sign, coeff, exp =  num_class.nan.split
              else
                discard, coeff, exp = ans.split
              end
            else
              # hard case, but probably won't be needed; here's a Q&D solution for testing
              if exp >= 0
                sign,coeff,exp = num_class.new(coeff*10**exp)
              else
                sign,coeff,exp = (num_class.new(coeff)/num_class.new(10**-exp)).split
              end
            end
          end
          @coeff, @exp = coeff, exp
        else
          if m.diag
            # NaN
            @coeff = (m.diag.nil? || m.diag.empty?) ? nil : m.diag.to_i
            @coeff = nil if @coeff==0
             if @coeff
               max_diag_len = context.maximum_nan_diagnostic_digits
               if max_diag_len && @coeff >= context.int_radix_power(max_diag_len)
                  @sign,@coeff,@exp = context.exception(ConversionSyntax, "diagnostic info too long in NaN").split
                 return
               end
             end
            @exp = m.signal ? :snan : :nan
          else
            # Infinity
            @coeff = 0
            @exp = :inf
          end
        end
      else
        raise TypeError, "invalid argument #{arg.inspect}"
      end
    else
      raise ArgumentError, "wrong number of arguments (#{args.size} for 1, 2 or 3)"
    end
  end

  # shortcut constructor:
  def Num(*args)
    self.class.Num(*args)
  end
  private :Num

  class <<self
    def Num(*args)
      if args.size==1 && args.first.instance_of?(self)
        args.first
      else
        new(*args)
      end
    end
  end

  # Returns the internal representation of the number, composed of:
  # * a sign which is +1 for plus and -1 for minus
  # * a coefficient (significand) which is a nonnegative integer
  # * an exponent (an integer) or :inf, :nan or :snan for special values
  # The value of non-special numbers is sign*coefficient*10^exponent
  def split
    [@sign, @coeff, @exp]
  end

  # Returns whether the number is a special value (NaN or Infinity).
  def special?
    @exp.instance_of?(Symbol)
  end

  # Returns whether the number is not actualy one (NaN, not a number).
  def nan?
    @exp==:nan || @exp==:snan
  end

  # Returns whether the number is a quite NaN (non-signaling)
  def qnan?
    @exp == :nan
  end

  # Returns whether the number is a signaling NaN
  def snan?
    @exp == :snan
  end

  # Returns whether the number is infinite
  def infinite?
    @exp == :inf
  end

  # Returns whether the number is finite
  def finite?
    !special?
  end

  # Returns whether the number is zero
  def zero?
    @coeff==0 && !special?
  end

  # Returns whether the number not zero
  def nonzero?
    special? || @coeff>0
  end

  # Returns whether the number is subnormal
  def subnormal?(context=nil)
    return false if special? || zero?
    context = define_context(context)
    self.adjusted_exponent < context.emin
  end

  # Returns whether the number is normal
  def normal?(context=nil)
    return false if special? || zero?
    context = define_context(context)
    (context.emin <= self.adjusted_exponent) &&  (self.adjusted_exponent <= context.emax)
  end

  # Classifies a number as one of
  # 'sNaN', 'NaN', '-Infinity', '-Normal', '-Subnormal', '-Zero',
  #  '+Zero', '+Subnormal', '+Normal', '+Infinity'
  def number_class(context=nil)
    return "sNaN" if snan?
    return "NaN" if nan?
    if infinite?
      return '+Infinity' if @sign==+1
      return '-Infinity' # if @sign==-1
    end
    if zero?
      return '+Zero' if @sign==+1
      return '-Zero' # if @sign==-1
    end
    define_context(context)
    if subnormal?(context)
      return '+Subnormal' if @sign==+1
      return '-Subnormal' # if @sign==-1
    end
    return '+Normal' if @sign==+1
    return '-Normal' if @sign==-1
  end

  # Used internally to convert numbers to be used in an operation to a suitable numeric type
  def coerce(other)
    case other
      when *num_class.context.coercible_types_or_num
        [Num(other),self]
      when Float
        [other, self.to_f]
      else
        super
    end
  end

  # Used internally to define binary operators
  def _bin_op(op, meth, other, context=nil)
    context = define_context(context)
    case other
      when *context.coercible_types_or_num
        self.send meth, Num(other, context), context
      else
        x, y = other.coerce(self)
        x.send op, y
    end
  end
  private :_bin_op

  # Unary minus operator
  def -@(context=nil)
    #(context || num_class.context).minus(self)
    _neg(context)
  end

  # Unary plus operator
  def +@(context=nil)
    #(context || num_class.context).plus(self)
    _pos(context)
  end

  # Addition of two decimal numbers
  def +(other, context=nil)
    _bin_op :+, :add, other, context
  end

  # Subtraction of two decimal numbers
  def -(other, context=nil)
    _bin_op :-, :subtract, other, context
  end

  # Multiplication of two decimal numbers
  def *(other, context=nil)
    _bin_op :*, :multiply, other, context
  end

  # Division of two decimal numbers
  def /(other, context=nil)
    _bin_op :/, :divide, other, context
  end

  # Modulo of two decimal numbers
  def %(other, context=nil)
    _bin_op :%, :modulo, other, context
  end

  # Power
  def **(other, context=nil)
    _bin_op :**, :power, other, context
  end

  # Addition
  def add(other, context=nil)

    context = define_context(context)
    other = _convert(other)

    if self.special? || other.special?
      ans = _check_nans(context,other)
      return ans if ans

      if self.infinite?
        if self.sign != other.sign && other.infinite?
          return context.exception(InvalidOperation, '-INF + INF')
        end
        return Num(self)
      end

      return Num(other) if other.infinite?
    end

    exp = [self.exponent, other.exponent].min
    negativezero = (context.rounding == ROUND_FLOOR && self.sign != other.sign)

    if self.zero? && other.zero?
      sign = [self.sign, other.sign].max
      sign = -1 if negativezero
      ans = Num([sign, 0, exp])._fix(context)
      return ans
    end

    if self.zero?
      exp = [exp, other.exponent - context.precision - 1].max unless context.exact?
      return other._rescale(exp, context.rounding)._fix(context)
    end

    if other.zero?
      exp = [exp, self.exponent - context.precision - 1].max unless context.exact?
      return self._rescale(exp, context.rounding)._fix(context)
    end

    op1, op2 = _normalize(self, other, context.precision)

    result_sign = result_coeff = result_exp = nil
    if op1.sign != op2.sign
      return ans = Num(negativezero ? -1 : +1, 0, exp)._fix(context) if op1.coefficient == op2.coefficient
      op1,op2 = op2,op1 if op1.coefficient < op2.coefficient
      result_sign = op1.sign
      op1,op2 = op1.copy_negate, op2.copy_negate if result_sign < 0
    elsif op1.sign < 0
      result_sign = -1
      op1,op2 = op1.copy_negate, op2.copy_negate
    else
      result_sign = +1
    end

    if op2.sign == +1
      result_coeff = op1.coefficient + op2.coefficient
    else
      result_coeff = op1.coefficient - op2.coefficient
    end

    result_exp = op1.exponent

    return Num(result_sign, result_coeff, result_exp)._fix(context)

  end

  # Subtraction
  def subtract(other, context=nil)

    context = define_context(context)
    other = _convert(other)

    if self.special? || other.special?
      ans = _check_nans(context,other)
      return ans if ans
    end
    return add(other.copy_negate, context)
  end

  # Multiplication
  def multiply(other, context=nil)
    context = define_context(context)
    other = _convert(other)
    resultsign = self.sign * other.sign
    if self.special? || other.special?
      ans = _check_nans(context,other)
      return ans if ans

      if self.infinite?
        return context.exception(InvalidOperation,"(+-)INF * 0") if other.zero?
        return num_class.infinity(resultsign)
      end
      if other.infinite?
        return context.exception(InvalidOperation,"0 * (+-)INF") if self.zero?
        return num_class.infinity(resultsign)
      end
    end

    resultexp = self.exponent + other.exponent

    return Num(resultsign, 0, resultexp)._fix(context) if self.zero? || other.zero?
    #return Num(resultsign, other.coefficient, resultexp)._fix(context) if self.coefficient==1
    #return Num(resultsign, self.coefficient, resultexp)._fix(context) if other.coefficient==1

    return Num(resultsign, other.coefficient*self.coefficient, resultexp)._fix(context)

  end

  # Division
  def divide(other, context=nil)
    context = define_context(context)
    other = _convert(other)
    resultsign = self.sign * other.sign
    if self.special? || other.special?
      ans = _check_nans(context,other)
      return ans if ans
      if self.infinite?
        return context.exception(InvalidOperation,"(+-)INF/(+-)INF") if other.infinite?
        return num_class.infinity(resultsign)
      end
      if other.infinite?
        context.exception(Clamped,"Division by infinity")
        return num_class.new([resultsign, 0, context.etiny])
      end
    end

    if other.zero?
      return context.exception(DivisionUndefined, '0 / 0') if self.zero?
      return context.exception(DivisionByZero, 'x / 0', resultsign)
    end

    if self.zero?
      exp = self.exponent - other.exponent
      coeff = 0
    else
      prec = context.exact? ? self.number_of_digits + 4*other.number_of_digits : context.precision
      shift = other.number_of_digits - self.number_of_digits + prec
      shift += 1
      exp = self.exponent - other.exponent - shift
      if shift >= 0
        coeff, remainder = (self.coefficient*num_class.int_radix_power(shift)).divmod(other.coefficient)
      else
        coeff, remainder = self.coefficient.divmod(other.coefficient*num_class.int_radix_power(-shift))
      end
      if remainder != 0
        return context.exception(Inexact) if context.exact?
        # result is not exact; adjust to ensure correct rounding
        if num_class.radix == 10
          # perform 05up rounding so the the final rounding will be correct
          coeff += 1 if (coeff%5) == 0
        else
          # since we will round to less digits and there is a remainder, we just need
          # to append some nonzero digit; but we must avoid producing a tie (adding a single
          # digit whose value is radix/2), so we append two digits, 01, that will be rounded away
          coeff = num_class.int_mult_radix_power(coeff, 2) + 1
          exp -= 2
        end
      else
        # result is exact; get as close to idaal exponent as possible
        ideal_exp = self.exponent - other.exponent
        while (exp < ideal_exp) && ((coeff % num_class.radix)==0)
          coeff /= num_class.radix
          exp += 1
        end
      end

    end
    return Num(resultsign, coeff, exp)._fix(context)

  end

  # Square root
  def sqrt(context=nil)
    context = define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
      return Num(self) if infinite? && @sign==+1
    end
    return Num(@sign, 0, @exp/2)._fix(context) if zero?
    return context.exception(InvalidOperation, 'sqrt(-x), x>0') if @sign<0
    prec = context.precision + 1

    # express the number in radix**2 base
    e = (@exp >> 1)
    if (@exp & 1)!=0
      c = @coeff*num_class.radix
      l = (number_of_digits >> 1) + 1
    else
      c = @coeff
      l = (number_of_digits+1) >> 1
    end
    shift = prec - l
    if shift >= 0
      c = num_class.int_mult_radix_power(c, (shift<<1))
      exact = true
    else
      c, remainder = c.divmod(num_class.int_radix_power((-shift)<<1))
      exact = (remainder==0)
    end
    e -= shift

    n = num_class.int_radix_power(prec)
    while true
      q = c / n
      break if n <= q
      n = ((n + q) >> 1)
    end
    exact = exact && (n*n == c)

    if exact
      if shift >= 0
        n = num_class.int_div_radix_power(n, shift)
      else
        n = num_class.int_mult_radix_power(n, -shift)
      end
      e += shift
    else
      return context.exception(Inexact) if context.exact?
      # result is not exact; adjust to ensure correct rounding
      if num_class.radix == 10
        n += 1 if (n%5)==0
      else
        n = num_class.int_mult_radix_power(n, 2) + 1
        e -= 2
      end
    end
    ans = Num(+1,n,e)
    num_class.local_context(:rounding=>:half_even) do
      ans = ans._fix(context)
    end
    return ans
  end

  # Absolute value
  def abs(context=nil)
    if special?
      ans = _check_nans(context)
      return ans if ans
    end
    sign<0 ? _neg(context) : _pos(context)
  end

  # Unary prefix plus operator
  def plus(context=nil)
    _pos(context)
  end

  # Unary prefix minus operator
  def minus(context=nil)
    _neg(context)
  end

  # Largest representable number smaller than itself
  def next_minus(context=nil)
    context = define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
      if infinite?
        return Num(self) if @sign == -1
        # @sign == +1
        if context.exact?
           return context.exception(InvalidOperation, 'Exact +INF next minus')
        else
          return Num(+1, context.maximum_coefficient, context.etop)
        end
      end
    end

    return context.exception(InvalidOperation, 'Exact next minus') if context.exact?

    result = nil
    num_class.local_context(context) do |local|
      local.rounding = :floor
      local.ignore_all_flags
      result = self._fix(local)
      if result == self
        result = self - Num(+1, 1, local.etiny-1)
      end
    end
    result
  end

  # Smallest representable number larger than itself
  def next_plus(context=nil)
    context = define_context(context)

    if special?
      ans = _check_nans(context)
      return ans if ans
      if infinite?
        return Num(self) if @sign == +1
        # @sign == -1
        if context.exact?
           return context.exception(InvalidOperation, 'Exact -INF next plus')
        else
          return Num(-1, context.maximum_coefficient, context.etop)
        end
      end
    end

    return context.exception(InvalidOperation, 'Exact next plus') if context.exact?

    result = nil
    num_class.local_context(context) do |local|
      local.rounding = :ceiling
      local.ignore_all_flags
      result = self._fix(local)
      if result == self
        result = self + Num(+1, 1, local.etiny-1)
      end
    end
    result

  end

  # Returns the number closest to self, in the direction towards other.
  def next_toward(other, context=nil)
    context = define_context(context)
    other = _convert(other)
    ans = _check_nans(context,other)
    return ans if ans

    return context.exception(InvalidOperation, 'Exact next_toward') if context.exact?

    comparison = self <=> other
    return self.copy_sign(other) if comparison == 0

    if comparison == -1
      result = self.next_plus(context)
    else # comparison == 1
      result = self.next_minus(context)
    end

    # decide which flags to raise using value of ans
    if result.infinite?
      context.exception Overflow, 'Infinite result from next_toward', result.sign
      context.exception Rounded
      context.exception Inexact
    elsif result.adjusted_exponent < context.emin
      context.exception Underflow
      context.exception Subnormal
      context.exception Rounded
      context.exception Inexact
      # if precision == 1 then we don't raise Clamped for a
      # result 0E-etiny.
      context.exception Clamped if result.zero?
    end

    result
  end

  # General Decimal Arithmetic Specification integer division and remainder:
  #  (x/y).truncate, x - y*(x/y).truncate
  def divrem(other, context=nil)
    context = define_context(context)
    other = _convert(other)

    ans = _check_nans(context,other)
    return [ans,ans] if ans

    sign = self.sign * other.sign

    if self.infinite?
      if other.infinite?
        ans = context.exception(InvalidOperation, 'divmod(INF,INF)')
        return [ans,ans]
      else
        return [num_class.infinity(sign), context.exception(InvalidOperation, 'INF % x')]
      end
    end

    if other.zero?
      if self.zero?
        ans = context.exception(DivisionUndefined, 'divmod(0,0)')
        return [ans,ans]
      else
        return [context.exception(DivisionByZero, 'x // 0', sign),
                 context.exception(InvalidOperation, 'x % 0')]
      end
    end

    quotient, remainder = self._divide_truncate(other, context)
    return [quotient, remainder._fix(context)]
  end

  # Ruby-style integer division and modulo: (x/y).floor, x - y*(x/y).floor
  def divmod(other, context=nil)
    context = define_context(context)
    other = _convert(other)

    ans = _check_nans(context,other)
    return [ans,ans] if ans

    sign = self.sign * other.sign

    if self.infinite?
      if other.infinite?
        ans = context.exception(InvalidOperation, 'divmod(INF,INF)')
        return [ans,ans]
      else
        return [num_class.infinity(sign), context.exception(InvalidOperation, 'INF % x')]
      end
    end

    if other.zero?
      if self.zero?
        ans = context.exception(DivisionUndefined, 'divmod(0,0)')
        return [ans,ans]
      else
        return [context.exception(DivisionByZero, 'x // 0', sign),
                 context.exception(InvalidOperation, 'x % 0')]
      end
    end

    quotient, remainder = self._divide_floor(other, context)
    return [quotient, remainder._fix(context)]
  end


  # General Decimal Arithmetic Specification integer division: (x/y).truncate
  def divide_int(other, context=nil)
    context = define_context(context)
    other = _convert(other)

    ans = _check_nans(context,other)
    return ans if ans

    sign = self.sign * other.sign

    if self.infinite?
      return context.exception(InvalidOperation, 'INF // INF') if other.infinite?
      return num_class.infinity(sign)
    end

    if other.zero?
      if self.zero?
        return context.exception(DivisionUndefined, '0 // 0')
      else
        return context.exception(DivisionByZero, 'x // 0', sign)
      end
    end
    return self._divide_truncate(other, context).first
  end

  # Ruby-style integer division: (x/y).floor
  def div(other, context=nil)
    context = define_context(context)
    other = _convert(other)

    ans = _check_nans(context,other)
    return [ans,ans] if ans

    sign = self.sign * other.sign

    if self.infinite?
      return context.exception(InvalidOperation, 'INF // INF') if other.infinite?
      return num_class.infinity(sign)
    end

    if other.zero?
      if self.zero?
        return context.exception(DivisionUndefined, '0 // 0')
      else
        return context.exception(DivisionByZero, 'x // 0', sign)
      end
    end
    return self._divide_floor(other, context).first
  end


  # Ruby-style modulo: x - y*div(x,y)
  def modulo(other, context=nil)
    context = define_context(context)
    other = _convert(other)

    ans = _check_nans(context,other)
    return ans if ans

    #sign = self.sign * other.sign

    if self.infinite?
      return context.exception(InvalidOperation, 'INF % x')
    elsif other.zero?
      if self.zero?
        return context.exception(DivisionUndefined, '0 % 0')
      else
        return context.exception(InvalidOperation, 'x % 0')
      end
    end

    return self._divide_floor(other, context).last._fix(context)
  end

  # General Decimal Arithmetic Specification remainder: x - y*divide_int(x,y)
  def remainder(other, context=nil)
    context = define_context(context)
    other = _convert(other)

    ans = _check_nans(context,other)
    return ans if ans

    #sign = self.sign * other.sign

    if self.infinite?
      return context.exception(InvalidOperation, 'INF % x')
    elsif other.zero?
      if self.zero?
        return context.exception(DivisionUndefined, '0 % 0')
      else
        return context.exception(InvalidOperation, 'x % 0')
      end
    end

    return self._divide_truncate(other, context).last._fix(context)
  end

  # General Decimal Arithmetic Specification remainder-near:
  #  x - y*round_half_even(x/y)
  def remainder_near(other, context=nil)
    context = define_context(context)
    other = _convert(other)

    ans = _check_nans(context,other)
    return ans if ans

    sign = self.sign * other.sign

    if self.infinite?
      return context.exception(InvalidOperation, 'remainder_near(INF,x)')
    elsif other.zero?
      if self.zero?
        return context.exception(DivisionUndefined, 'remainder_near(0,0)')
      else
        return context.exception(InvalidOperation, 'remainder_near(x,0)')
      end
    end

    if other.infinite?
      return Num(self)._fix(context)
    end

    ideal_exp = [self.exponent, other.exponent].min
    if self.zero?
      return Num(self.sign, 0, ideal_exp)._fix(context)
    end

    expdiff = self.adjusted_exponent - other.adjusted_exponent
    if (expdiff >= context.precision+1) && !context.exact?
      return context.exception(DivisionImpossible)
    elsif expdiff <= -2
      return self._rescale(ideal_exp, context.rounding)._fix(context)
    end

      self_coeff = self.coefficient
      other_coeff = other.coefficient
      de = self.exponent - other.exponent
      if de >= 0
        self_coeff = num_class.int_mult_radix_power(self_coeff, de)
      else
        other_coeff = num_class.int_mult_radix_power(other_coeff, -de)
      end
      q, r = self_coeff.divmod(other_coeff)
      if 2*r + (q&1) > other_coeff
        r -= other_coeff
        q += 1
      end

      return context.exception(DivisionImpossible) if q >= num_class.int_radix_power(context.precision) && !context.exact?

      sign = self.sign
      if r < 0
        sign = -sign
        r = -r
      end

    return Num(sign, r, ideal_exp)._fix(context)

  end

  # Reduces an operand to its simplest form
  # by removing trailing 0s and incrementing the exponent.
  # (formerly called normalize in GDAS)
  def reduce(context=nil)
    context = define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
    end
    dup = _fix(context)
    return dup if dup.infinite?

    return Num(dup.sign, 0, 0) if dup.zero?

    exp_max = context.clamp? ? context.etop : context.emax
    end_d = nd = dup.number_of_digits
    exp = dup.exponent
    coeff = dup.coefficient
    dgs = dup.digits
    while (dgs[end_d-1]==0) && (exp < exp_max)
      exp += 1
      end_d -= 1
    end
    return Num(dup.sign, coeff/num_class.int_radix_power(nd-end_d), exp)
  end

  # normalizes so that the coefficient has precision digits
  # (this is not the old GDA normalize function)
  # Note that this reduces precision to that specified by the context if the
  # number is more precise.
  # For surnormal numbers the Subnormal flag is raised an a subnormal is returned
  # but with the smallest possible exponent.
  def normalize(context=nil)
    context = define_context(context)
    return Num(self) if self.special? || self.zero?
    sign, coeff, exp = self._fix(context).split
    return context.exception(InvalidOperation, "Normalize in exact context") if context.exact?
    if self.subnormal?
      context.exception Subnormal
      if exp > context.etiny
        coeff = num_class.int_mult_radix_power(coeff, exp - context.etiny)
        exp = context.etiny
      end
    else
      min_normal_coeff = context.minimum_normalized_coefficient
      while coeff < min_normal_coeff
        coeff = num_class.int_mult_radix_power(coeff, 1)
        exp -= 1
      end
    end
    Num(sign, coeff, exp)
  end

  # Returns the exponent of the magnitude of the most significant digit.
  #
  # The result is the integer which is the exponent of the magnitude
  # of the most significant digit of the number (as though it were truncated
  # to a single digit while maintaining the value of that digit and
  # without limiting the resulting exponent).
  def logb(context=nil)
    context = define_context(context)
    ans = _check_nans(context)
    return ans if ans
    return num_class.infinity if infinite?
    return context.exception(DivisionByZero,'logb(0)',-1) if zero?
    Num(adjusted_exponent)
  end

  # Adds a value to the exponent.
  def scaleb(other, context=nil)

    context = define_context(context)
    other = _convert(other)
    ans = _check_nans(context, other)
    return ans if ans
    return context.exception(InvalidOperation) if other.infinite? || other.exponent != 0
    unless context.exact?
      liminf = -2 * (context.emax + context.precision)
      limsup =  2 * (context.emax + context.precision)
      i = other.to_i
      return context.exception(InvalidOperation) if !((liminf <= i) && (i <= limsup))
    end
    return Num(self) if infinite?
    return Num(@sign, @coeff, @exp+i)._fix(context)

  end

  # Convert to other numerical type.
  def convert_to(type, context=nil)
    context = define_context(context)
    context.convert_to(type, self)
  end

  # Ruby-style to integer conversion.
  def to_i
    if special?
      if nan?
        #return context.exception(InvalidContext)
        num_class.context.exception InvalidContext
        return nil
      end
      raise Error, "Cannot convert infinity to Integer"
    end
    if @exp >= 0
      return @sign*num_class.int_mult_radix_power(@coeff,@exp)
    else
      return @sign*num_class.int_div_radix_power(@coeff,-@exp)
    end
  end

  # Conversion to Rational.
  # Conversion of special values will raise an exception under Ruby 1.9
  def to_r
    if special?
      num = (@exp == :inf) ? @sign : 0
      Rational.respond_to?(:new!) ? Rational.new!(num,0) : Rational(num,0)
    else
      if @exp < 0
        Rational(@sign*@coeff, num_class.int_radix_power(-@exp))
      else
        Rational(num_class.int_mult_radix_power(@sign*@coeff,@exp), 1)
      end
    end
  end

  # Conversion to Float
  def to_f
    if special?
      if @exp==:inf
        @sign/0.0
      else
        0.0/0.0
      end
    else
      # to_rational.to_f
      # to_s.to_f
      (@sign*@coeff*(num_class.radix.to_f**@exp)).to_f
    end
  end

  # ulp (unit in the last place) according to the definition proposed by J.M. Muller in
  # "On the definition of ulp(x)" INRIA No. 5504
  # If the mode parameter has the value :high the Golberg ulp is computed instead; which is
  # different on the powers of the radix (which are the borders between areas of different
  # ulp-magnitude)
  def ulp(context = nil, mode=:low)
    context = define_context(context)

    return context.exception(InvalidOperation, "ulp in exact context") if context.exact?

    if self.nan?
      return Num(self)
    elsif self.infinite?
      # The ulp here is context.maximum_finite - context.maximum_finite.next_minus
      return Num(+1, 1, context.etop)
    elsif self.zero? || self.adjusted_exponent <= context.emin
      # This is the ulp value for self.abs <= context.minimum_normal*Decimal.context
      # Here we use it for self.abs < context.minimum_normal*Decimal.context;
      #  because of the simple exponent check; the remaining cases are handled below.
      return context.minimum_nonzero
    else
      # The next can compute the ulp value for the values that
      #   self.abs > context.minimum_normal && self.abs <= context.maximum_finite
      # The cases self.abs < context.minimum_normal*Decimal.context have been handled above.

      # assert self.normal? && self.abs>context.minimum_nonzero
      norm = self.normalize
      exp = norm.integral_exponent
      sig = norm.integral_significand

      # Powers of the radix, r**n, are between areas with different ulp values: r**(n-p-1) and r**(n-p)
      # (p is context.precision).
      # This method and the ulp definitions by Muller, Kahan and Harrison assign the smaller ulp value
      # to r**n; the definition by Goldberg assigns it to the larger ulp (so ulp varies with adjusted_exponent).
      # The next line selects the smaller ulp for powers of the radix:
      exp -= 1 if sig == num_class.int_radix_power(context.precision-1) if mode == :low

      return Num(+1, 1, exp)
    end
  end

  def inspect
    # TODO: depending on the final naming of module and classes, it may or may not be desiderable to
    # remove the class name qualifier
    class_name = num_class.to_s.split('::').last
    if $DEBUG
      "#{class_name}('#{self}') [coeff:#{@coeff.inspect} exp:#{@exp.inspect} s:#{@sign.inspect} radix:#{num_class.radix}]"
    else
      "#{class_name}('#{self}')"
    end
  end

  # Internal comparison operator: returns -1 if the first number is less than the second,
  # 0 if both are equal or +1 if the first is greater than the secong.
  def <=>(other)
    case other
    when *num_class.context.coercible_types_or_num
      other = Num(other)
      if self.special? || other.special?
        if self.nan? || other.nan?
          1
        else
          self_v = self.finite? ? 0 : self.sign
          other_v = other.finite? ? 0 : other.sign
          self_v <=> other_v
        end
      else
        if self.zero?
          if other.zero?
            0
          else
            -other.sign
          end
        elsif other.zero?
          self.sign
        elsif other.sign < self.sign
          +1
        elsif self.sign < other.sign
          -1
        else
          self_adjusted = self.adjusted_exponent
          other_adjusted = other.adjusted_exponent
          if self_adjusted == other_adjusted
            self_padded,other_padded = self.coefficient,other.coefficient
            d = self.exponent - other.exponent
            if d>0
              self_padded *= num_class.int_radix_power(d)
            else
              other_padded *= num_class.int_radix_power(-d)
            end
            (self_padded <=> other_padded)*self.sign
          elsif self_adjusted > other_adjusted
            self.sign
          else
            -self.sign
          end
        end
      end
    else
      if !self.nan? && defined? other.coerce
        x, y = other.coerce(self)
        x <=> y
      else
        nil
      end
    end
  end
  def ==(other)
    (self<=>other) == 0
  end
  include Comparable

  def hash
    ([num_class]+reduce.split).hash # TODO: optimize
  end

  def eql?(other)
    return false unless other.is_a?(num_class)
    reduce.split == other.reduce.split
  end

  # Compares like <=> but returns a Decimal value.
  def compare(other, context=nil)

    other = _convert(other)

    if self.special? || other.special?
      ans = _check_nans(context, other)
      return ans if ans
    end

    return Num(self <=> other)

  end

  # Exponent of the magnitude of the most significant digit of the operand
  def adjusted_exponent
    if special?
      0
    else
      @exp + number_of_digits - 1
    end
  end

  # Synonym for Decimal#adjusted_exponent()
  def scientific_exponent
    adjusted_exponent
  end

  # Exponent as though the significand were a fraction (the decimal point before its first digit)
  def fractional_exponent
    scientific_exponent + 1
  end

  # Number of digits in the significand
  def number_of_digits
    # digits.size
    @coeff.is_a?(Integer) ? @coeff.to_s(num_class.radix).size : 0
  end

  # Digits of the significand as an array of integers
  def digits
    @coeff.to_s(num_class.radix).split('').map{|d| d.to_i} # TODO: optimize in derivided classes
  end

  # Significand as an integer, unsigned. Synonym of coefficient
  def integral_significand
    @coeff
  end

  # Exponent of the significand as an integer. Synonym of exponent
  def integral_exponent
    # fractional_exponent - number_of_digits
    @exp
  end

  # Sign of the number: +1 for plus / -1 for minus.
  def sign
    @sign
  end

  # Significand as an integer, unsigned
  def coefficient
    @coeff
  end

  # Exponent of the significand as an integer.
  def exponent
    @exp
  end

  # Return the value of the number as an signed integer and a scale.
  def to_int_scale
    if special?
      nil
    else
      [@sign*integral_significand, integral_exponent]
    end
  end

  # Returns a copy of with the sign set to +
  def copy_abs
    Num(+1,@coeff,@exp)
  end

  # Returns a copy of with the sign inverted
  def copy_negate
    Num(-@sign,@coeff,@exp)
  end

  # Returns a copy of with the sign of other
  def copy_sign(other)
    Num(other.sign, @coeff, @exp)
  end

  # Returns true if the value is an integer
  def integral?
    if finite?
      if @exp>=0 || @coeff==0
        true
      else
        if @exp <= -number_of_digits
          false
        else
          m = num_class.int_radix_power(-@exp)
          (@coeff % m) == 0
        end
      end
    else
      false
    end
  end

  # returns true if is an even integer
  def even?
    # integral? && ((to_i%2)==0)
    if finite?
      if @exp>0 || @coeff==0
        true
      else
        if @exp <= -number_of_digits
          false
        else
          m = num_class.int_radix_power(-@exp)
          if (@coeff % m) == 0
            # ((@coeff / m) % 2) == 0
            ((@coeff / m) & 1) == 0
          else
            false
          end
        end
      end
    else
      false
    end
  end

  # returns true if is an odd integer
  def odd?
    # integral? && ((to_i%2)==1)
    # integral? && !even?
    if finite?
      if @exp>0 || @coeff==0
        false
      else
        if @exp <= -number_of_digits
          false
        else
          m = num_class.int_radix_power(-@exp)
          if (@coeff % m) == 0
            # ((@coeff / m) % 2) == 1
            ((@coeff / m) & 1) == 1
          else
            false
          end
        end
      end
    else
      false
    end
  end

  # Rescale so that the exponent is exp, either by padding with zeros
  # or by truncating digits.
  def rescale(exp, context=nil, watch_exp=true)
    context = define_context(context)
    exp = _convert(exp)
    if self.special? || exp.special?
      ans = _check_nans(context, exp)
      return ans if ans
      if exp.infinite? || self.infinite?
        return Num(self) if exp.infinite? && self.infinite?
        return context.exception(InvalidOperation, 'rescale with one INF')
      end
    end
    return context.exception(InvalidOperation,"exponent of rescale is not integral") unless exp.integral?
    exp = exp.to_i
    _watched_rescale(exp, context, watch_exp)
  end

  # Quantize so its exponent is the same as that of y.
  def quantize(exp, context=nil, watch_exp=true)
    exp = _convert(exp)
    context = define_context(context)
    if self.special? || exp.special?
      ans = _check_nans(context, exp)
      return ans if ans
      if exp.infinite? || self.infinite?
        return Num(self) if exp.infinite? && self.infinite?
        return context.exception(InvalidOperation, 'quantize with one INF')
      end
    end
    exp = exp.exponent
    _watched_rescale(exp, context, watch_exp)
  end

  # Return true if has the same exponent as other.
  #
  # If either operand is a special value, the following rules are used:
  # * return true if both operands are infinities
  # * return true if both operands are NaNs
  # * otherwise, return false.
  def same_quantum?(other)
    other = _convert(other)
    if self.special? || other.special?
      return (self.nan? && other.nan?) || (self.infinite? && other.infinite?)
    end
    return self.exponent == other.exponent
  end

  # Rounds to a nearby integer. May raise Inexact or Rounded.
  def to_integral_exact(context=nil)
    context = define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
      return Num(self)
    end
    return Num(self) if @exp >= 0
    return Num(@sign, 0, 0) if zero?
    context.exception Rounded
    ans = _rescale(0, context.rounding)
    context.exception Inexact if ans != self
    return ans
  end

  # Rounds to a nearby integer. Doesn't raise Inexact or Rounded.
  def to_integral_value(context=nil)
    context = define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
      return Num(self)
    end
    return Num(self) if @exp >= 0
    return _rescale(0, context.rounding)
  end

  # General rounding.
  #
  # With an integer argument this acts like Float#round: the parameter specifies the number
  # of fractional digits (or digits to the left of the decimal point if negative).
  #
  # Options can be passed as a Hash instead; valid options are:
  # * :rounding method for rounding (see Context#new())
  # The precision can be specified as:
  # * :places number of fractional digits as above.
  # * :exponent specifies the exponent corresponding to the
  #   digit to be rounded (exponent == -places)
  # * :precision or :significan_digits is the number of digits
  # * :power 10^exponent, value of the digit to be rounded,
  #   should be passed as a type convertible to Decimal.
  # * :index 0-based index of the digit to be rounded
  # * :rindex right 0-based index of the digit to be rounded
  #
  # The default is :places=>0 (round to integer).
  #
  # Example: ways of specifiying the rounding position
  #   number:     1   2   3   4  .  5    6    7    8
  #   :places    -3  -2  -1   0     1    2    3    4
  #   :exponent   3   2   1   0    -1   -2   -3   -4
  #   :precision  1   2   3   4     5    6    7    8
  #   :power    1E3 1E2  10   1   0.1 1E-2 1E-3 1E-4
  #   :index      0   1   2   3     4    5    6    7
  #   :index      7   6   5   4     3    2    1    0
  def round(opt={})
    opt = { :places=>opt } if opt.kind_of?(Integer)
    r = opt[:rounding] || :half_up
    as_int = false
    if v=(opt[:precision] || opt[:significant_digits])
      prec = v
    elsif v=(opt[:places])
      prec = adjusted_exponent + 1 + v
    elsif v=(opt[:exponent])
      prec = adjusted_exponent + 1 - v
    elsif v=(opt[:power])
      prec = adjusted_exponent + 1 - Decimal(v).adjusted_exponent
    elsif v=(opt[:index])
      prec = i+1
    elsif v=(opt[:rindex])
      prec = number_of_digits - v
    else
      prec = adjusted_exponent + 1
      as_int = true
    end
    dg = number_of_digits-prec
    changed = _round(r, dg)
    coeff = num_class.int_div_radix_power(@coeff, dg)
    exp = @exp + dg
    coeff += 1 if changed==1
    result = Num(@sign, coeff, exp)
    return as_int ? result.to_i : result
  end

  # General ceiling operation (as for Float) with same options for precision
  # as Decimal#round()
  def ceil(opt={})
    opt[:rounding] = :ceiling
    round opt
  end

  # General floor operation (as for Float) with same options for precision
  # as Decimal#round()
  def floor(opt={})
    opt[:rounding] = :floor
    round opt
  end

  # General truncate operation (as for Float) with same options for precision
  # as Decimal#round()
  def truncate(opt={})
    opt[:rounding] = :down
    round opt
  end

  # Fused multiply-add.
  #
  # Computes (self*other+third) with no rounding of the intermediate product self*other.
  def fma(other, third, context=nil)
    context =define_context(context)
    other = _convert(other)
    third = _convert(third)
    if self.special? || other.special?
      return context.exception(InvalidOperation, 'sNaN', self) if self.snan?
      return context.exception(InvalidOperation, 'sNaN', other) if other.snan?
      if self.nan?
        product = self
      elsif other.nan?
        product = other
      elsif self.infinite?
        return context.exception(InvalidOperation, 'INF * 0 in fma') if other.zero?
        product = num_class.infinity(self.sign*other.sign)
      elsif other.infinite?
        return context.exception(InvalidOperation, '0 * INF  in fma') if self.zero?
        product = num_class.infinity(self.sign*other.sign)
      end
    else
      product = Num(self.sign*other.sign,self.coefficient*other.coefficient, self.exponent+other.exponent)
    end
    return product.add(third, context)
  end

  # Check if the number or other is NaN, signal if sNaN or return NaN;
  # return nil if none is NaN.
  def _check_nans(context=nil, other=nil)
    #self_is_nan = self.nan?
    #other_is_nan = other.nil? ? false : other.nan?
    if self.nan? || (other && other.nan?)
      context = define_context(context)
      return context.exception(InvalidOperation, 'sNaN', self) if self.snan?
      return context.exception(InvalidOperation, 'sNaN', other) if other && other.snan?
      return self._fix_nan(context) if self.nan?
      return other._fix_nan(context)
    else
      return nil
    end
  end

  # Rescale so that the exponent is exp, either by padding with zeros
  # or by truncating digits, using the given rounding mode.
  #
  # Specials are returned without change.  This operation is
  # quiet: it raises no flags, and uses no information from the
  # context.
  #
  # exp = exp to scale to (an integer)
  # rounding = rounding mode
  def _rescale(exp, rounding)

    return Num(self) if special?
    return Num(sign, 0, exp) if zero?
    return Num(sign, @coeff*num_class.int_radix_power(self.exponent - exp), exp) if self.exponent > exp
    #nd = number_of_digits + self.exponent - exp
    nd = exp - self.exponent
    if number_of_digits < nd
      slf = Num(sign, 1, exp-1)
      nd = number_of_digits
    else
      slf = num_class.new(self)
    end

    changed = slf._round(rounding, nd)
    coeff = num_class.int_div_radix_power(@coeff, nd)
    coeff += 1 if changed==1
    Num(slf.sign, coeff, exp)

  end

  def _watched_rescale(exp, context, watch_exp)
    if !watch_exp
      ans = _rescale(exp, context.rounding)
      context.exception(Rounded) if ans.exponent > self.exponent
      context.exception(Inexact) if ans != self
      return ans
    end

    if exp < context.etiny || exp > context.emax
      return context.exception(InvalidOperation, "target operation out of bounds in quantize/rescale")
    end

    return Num(@sign, 0, exp)._fix(context) if zero?

    self_adjusted = adjusted_exponent
    return context.exception(InvalidOperation,"exponent of quantize/rescale result too large for current context") if self_adjusted > context.emax
    return context.exception(InvalidOperation,"quantize/rescale has too many digits for current context") if (self_adjusted - exp + 1 > context.precision) && !context.exact?

    ans = _rescale(exp, context.rounding)
    return context.exception(InvalidOperation,"exponent of rescale result too large for current context") if ans.adjusted_exponent > context.emax
    return context.exception(InvalidOperation,"rescale result has too many digits for current context") if (ans.number_of_digits > context.precision) && !context.exact?
    if ans.exponent > self.exponent
      context.exception(Rounded)
      context.exception(Inexact) if ans!=self
    end
    context.exception(Subnormal) if !ans.zero? && (ans.adjusted_exponent < context.emin)
    return ans._fix(context)
  end

  # Returns copy with sign inverted
  def _neg(context=nil)
    if special?
      ans = _check_nans(context)
      return ans if ans
    end
    if zero?
      ans = copy_abs
    else
      ans = copy_negate
    end
    context = define_context(context)
    ans._fix(context)
  end

  # Returns a copy with precision adjusted
  def _pos(context=nil)
    if special?
      ans = _check_nans(context)
      return ans if ans
    end
    if zero?
      ans = copy_abs
    else
      ans = Num(self)
    end
    context = define_context(context)
    ans._fix(context)
  end

  # Returns a copy with positive sign
  def _abs(round=true, context=nil)
    return copy_abs if not round

    if special?
      ans = _check_nans(context)
      return ans if ans
    end
    if sign>0
      ans = _neg(context)
    else
      ans = _pos(context)
    end
    ans
  end

  # Round if it is necessary to keep within precision.
  def _fix(context)
    return self if context.exact?

    if special?
      if nan?
        return _fix_nan(context)
      else
        return Num(self)
      end
    end

    etiny = context.etiny
    etop  = context.etop
    if zero?
      exp_max = context.clamp? ? etop : context.emax
      new_exp = [[@exp, etiny].max, exp_max].min
      if new_exp!=@exp
        context.exception Clamped
        return Num(sign,0,new_exp)
      else
        return Num(self)
      end
    end

    nd = number_of_digits
    exp_min = nd + @exp - context.precision
    if exp_min > etop
      context.exception Inexact
      context.exception Rounded
      return context.exception(Overflow, 'above Emax', sign)
    end

    self_is_subnormal = exp_min < etiny

    if self_is_subnormal
      context.exception Subnormal
      exp_min = etiny
    end

    if @exp < exp_min
      context.exception Rounded
      # dig is the digits number from 0 (MS) to number_of_digits-1 (LS)
      # dg = numberof_digits-dig is from 1 (LS) to number_of_digits (MS)
      dg = exp_min - @exp # dig = number_of_digits + exp - exp_min
      if dg > number_of_digits # dig<0
        d = Num(sign,1,exp_min-1)
        dg = number_of_digits # dig = 0
      else
        d = Num(self)
      end
      changed = d._round(context.rounding, dg)
      coeff = num_class.int_div_radix_power(d.coefficient, dg)
      coeff += 1 if changed==1
      ans = Num(sign, coeff, exp_min)
      if changed!=0
        context.exception Inexact
        if self_is_subnormal
          context.exception Underflow
          if ans.zero?
            context.exception Clamped
          end
        elsif ans.number_of_digits == context.precision+1
          if ans.exponent< etop
            ans = Num(ans.sign, num_class.int_div_radix_power(ans.coefficient,1), ans.exponent+1)
          else
            ans = context.exception(Overflow, 'above Emax', d.sign)
          end
        end
      end
      return ans
    end

    if context.clamp? &&  @exp>etop
      context.exception Clamped
      self_padded = num_class.int_mult_radix_power(@coeff, @exp-etop)
      return Num(sign,self_padded,etop)
    end

    return Num(self)

  end

  # adjust payload of a NaN to the context
  def _fix_nan(context)
    if  !context.exact?
      payload = @coeff
      payload = nil if payload==0

      max_payload_len = context.maximum_nan_diagnostic_digits

      if number_of_digits > max_payload_len
          payload = payload.to_s[-max_payload_len..-1].to_i
          return Decimal([@sign, payload, @exp])
      end
    end
    Num(self)
  end

  protected

  def _divide_truncate(other, context)
    context = define_context(context)
    sign = self.sign * other.sign
    if other.infinite?
      ideal_exp = self.exponent
    else
      ideal_exp = [self.exponent, other.exponent].min
    end

    expdiff = self.adjusted_exponent - other.adjusted_exponent
    if self.zero? || other.infinite? || (expdiff <= -2)
      return [Num(sign, 0, 0), _rescale(ideal_exp, context.rounding)]
    end
    if (expdiff <= context.precision) || context.exact?
      self_coeff = self.coefficient
      other_coeff = other.coefficient
      de = self.exponent - other.exponent
      if de >= 0
        self_coeff = num_class.int_mult_radix_power(self_coeff, de)
      else
        other_coeff = num_class.int_mult_radix_power(other_coeff, -de)
      end
      q, r = self_coeff.divmod(other_coeff)
      if (q < num_class.int_radix_power(context.precision)) || context.exact?
        return [Num(sign, q, 0),Num(self.sign, r, ideal_exp)]
      end
    end
    # Here the quotient is too large to be representable
    ans = context.exception(DivisionImpossible, 'quotient too large in //, % or divmod')
    return [ans, ans]

  end

  def _divide_floor(other, context)
    context = define_context(context)
    sign = self.sign * other.sign
    if other.infinite?
      ideal_exp = self.exponent
    else
      ideal_exp = [self.exponent, other.exponent].min
    end

    expdiff = self.adjusted_exponent - other.adjusted_exponent
    if self.zero? || other.infinite? || (expdiff <= -2)
      return [Num(sign, 0, 0), _rescale(ideal_exp, context.rounding)]
    end
    if (expdiff <= context.precision) || context.exact?
      self_coeff = self.coefficient*self.sign
      other_coeff = other.coefficient*other.sign
      de = self.exponent - other.exponent
      if de >= 0
        self_coeff = num_class.int_mult_radix_power(self_coeff, de)
      else
        other_coeff = num_class.int_mult_radix_power(other_coeff, -de)
      end
      q, r = self_coeff.divmod(other_coeff)
      if r<0
        r = -r
        rs = -1
      else
        rs = +1
      end
      if q<0
        q = -q
        qs = -1
      else
        qs = +1
      end
      if (q < num_class.int_radix_power(context.precision)) || context.exact?
        return [Num(qs, q, 0),Num(rs, r, ideal_exp)]
      end
    end
    # Here the quotient is too large to be representable
    ans = context.exception(DivisionImpossible, 'quotient too large in //, % or divmod')
    return [ans, ans]

  end

  # Auxiliar Methods

  # Round to i digits using the specified method
  def _round(rounding, i)
    send("_round_#{rounding}", i)
  end

  # Round down (toward 0, truncate) to i digits
  def _round_down(i)
    (@coeff % num_class.int_radix_power(i))==0 ? 0 : -1
  end

  # Round up (away from 0) to i digits
  def _round_up(i)
    -_round_down(i)
  end

  # Round to closest i-digit number with ties down (rounds 5 toward 0)
  def _round_half_down(i)
    m = num_class.int_radix_power(i)
    if (m>1) && ((@coeff%m) == m/2)
      -1
    else
      _round_half_up(i)
    end
  end

  # Round to closest i-digit number with ties up (rounds 5 away from 0)
  def _round_half_up(i)
    m = num_class.int_radix_power(i)
    if (m>1) && ((@coeff % m) >= m/2)
      1
    else
      (@coeff % m)==0 ? 0 : -1
    end
  end

  # Round to closest i-digit number with ties (5) to an even digit
  def _round_half_even(i)
    m = num_class.int_radix_power(i)
    if (m>1) && ((@coeff%m) == m/2 && ((@coeff/m)%2)==0)
      -1
    else
      _round_half_up(i)
    end
  end

  # Round up (not away from 0 if negative) to i digits
  def _round_ceiling(i)
    sign<0 ? _round_down(i) : -_round_down(i)
  end

  # Round down (not toward 0 if negative) to i digits
  def _round_floor(i)
    sign>0 ? _round_down(i) : -_round_down(i)
  end

  # Round down unless digit i-1 is 0 or 5
  def _round_up05(i)
    if ((@coeff/num_class.int_radix_power(i))%(num_class.radix/2))==0
      -_round_down(i)
    else
      _round_down(i)
    end
  end

  module AuxiliarFunctions

    module_function

    # Convert a numeric value to decimal (internal use)
    def _convert(x, error=true)
      case x
      when num_class
        x
      when *num_class.context.coercible_types
        num_class.new(x)
      else
        raise TypeError, "Unable to convert #{x.class} to #{num_class}" if error
        nil
      end
    end

    # Parse numeric text literals (internal use)
    def _parser(txt)
      md = /^\s*([-+])?(?:(?:(\d+)(?:\.(\d*))?|\.(\d+))(?:[eE]([-+]?\d+))?|Inf(?:inity)?|(s)?NaN(\d*))\s*$/i.match(txt)
      if md
        OpenStruct.new :sign=>md[1], :int=>md[2], :frac=>md[3], :onlyfrac=>md[4], :exp=>md[5],
                       :signal=>md[6], :diag=>md[7]
      end
    end

    # Normalizes op1, op2 to have the same exp and length of coefficient. Used for addition.
    def _normalize(op1, op2, prec=0)
      if op1.exponent < op2.exponent
        swap = true
        tmp,other = op2,op1
      else
        swap = false
        tmp,other = op1,op2
      end
      tmp_len = tmp.number_of_digits
      other_len = other.number_of_digits
      exp = tmp.exponent + [-1, tmp_len - prec - 2].min
      if (other_len+other.exponent-1 < exp) && prec>0
        other = num_class.new([other.sign, 1, exp])
      end
      tmp = Num(tmp.sign,
                        num_class.int_mult_radix_power(tmp.coefficient, tmp.exponent-other.exponent),
                        other.exponent)
      return swap ? [other, tmp] : [tmp, other]
    end

  end

  include AuxiliarFunctions
  extend AuxiliarFunctions

end

end # BigFloat