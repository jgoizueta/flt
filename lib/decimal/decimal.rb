require 'bigdecimal'
require 'forwardable'
require 'rational'
require 'monitor'
require 'ostruct'

module BigFloat

# TODO: arithmetic rounding in arbitrary radix must be reviewed; in general the number of extra
#       digits used before rounding should be adjusted for each radix. This has already been done for division only.
# TODO: write tests for BinFloat
# TODO: put Num, Decimal, BinFloat in separate files
# TODO: update documentation; check rdoc results for clarity given the new Num/Decimal/BinFloat structure
# TODO: test, debug, enhance Burger and Dybvig formatting algorithms; add formatting options
# TODO: port native Float extensions from float-formats

class Num # APFloat (arbitrary precision float) MPFloat ...

  extend DecimalSupport # allows use of unqualified FlagValues(), Flags()

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
      x, y = Decimal.new(x.numerator), Decimal.new(x.denominator)
      x.divide(y, context)
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
    def self.handle(context=nil, *args)
      if args.size>0
        sign, coeff, exp = args.first.split
        Decimal.new([sign, coeff, :nan])._fix_nan(context)
      else
        Decimal.nan
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
      Decimal.infinity(sign)
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
      Decimal.nan
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
      Decimal.nan
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
      Decimal.nan if context.exact?
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
        Decimal.infinity(sign)
      elsif sign==+1
        if context.rounding == :ceiling
          Decimal.infinity(sign)
        else
          Decimal.new([sign, Decimal.int_radix_power(context.precision) - 1, context.emax - context.precision + 1])
        end
      elsif sign==-1
        if context.rounding == :floor
          Decimal.infinity(sign)
        else
          Decimal.new([sign, Decimal.int_radix_power(context.precision) - 1, context.emax - context.precision + 1])
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
      Decimal.nan
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
      Decimal.nan
    end
  end

  EXCEPTIONS = FlagValues(Clamped, InvalidOperation, DivisionByZero, Inexact, Overflow, Underflow,
                          Rounded, Subnormal, DivisionImpossible, ConversionSyntax)

  def self.Flags(*values)
    DecimalSupport::Flags(EXCEPTIONS,*values)
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
      _convert(x).reduce(self)
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
      x.coefficient*(Decimal.int_radix_power(precision - x.number_of_digits))
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
    def ulp(x=nil)
      x ||= 1
      _convert(x).ulp(self)
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
      Num(sign, 1, emin)
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
      # assume radix is even (Decimal.radix%2 == 0)
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
      Num(sign, Decimal.radix/2, -precision)
    end

    def to_s
      inspect
    end

    def inspect
      "<#{self.class}:\n" +
      instance_variables.map { |v| "  #{v}: #{eval(v).inspect}"}.join("\n") +
      ">\n"
    end

    # Maximum integral significand value for numbers using this context's precision.
    def maximum_significand
      if exact?
        exception(InvalidOperation, 'Exact maximum significand')
        nil
      else
        num_class.int_radix_power(precision)-1
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
          raise TypeError,"invalid argument for Decimal.Context"
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
              ans, exact = Clinger.algM(context, coeff, exp, rounding, 10)
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
      # TODO: how many digits to use for binary radix?
      prec = context.exact? ? self.number_of_digits + 4*other.number_of_digits : context.precision
      shift = other.number_of_digits - self.number_of_digits + prec
      shift += num_class.radix==10 ? 1 : 3 # TODO: review, generalize
      exp = self.exponent - other.exponent - shift
      if shift >= 0
        coeff, remainder = (self.coefficient*num_class.int_radix_power(shift)).divmod(other.coefficient)
      else
        coeff, remainder = self.coefficient.divmod(other.coefficient*num_class.int_radix_power(-shift))
      end
      if remainder != 0
        return context.exception(Inexact) if context.exact?
        coeff += 1 if (coeff%(num_class.radix/2)) == 0
      else
        ideal_exp = self.exponent - other.exponent
        while (exp < ideal_exp) && ((coeff % Decimal.radix)==0)
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
      n += 1 if (n%5)==0 # TODO: generalize to radix!=10
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
          return Num(+1, context.maximum_significand, context.etop)
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
          return Num(-1, context.maximum_significand, context.etop)
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
  def normalize(context=nil)
    context = define_context(context)
    return Num(self) if self.special? || self.zero?
    return context.exception(InvalidOperation, "Normalize in exact context") if context.exact?
    return context.exception(Subnormal, "Cannot normalize subnormal") if self.subnormal?
    min_normal_coeff = num_class.int_radix_power(context.precision-1)
    sign, coeff, exp = self._fix(context).split
    while coeff < min_normal_coeff
      coeff *= num_class.radix
      exp -= 1
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
  def ulp(context = nil)
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
      # to r**n; the definition by Goldberg assigns it to the larger ulp.
      # The next line selects the smaller ulp for powers of the radix:
      exp -= 1 if sig == num_class.int_radix_power(context.precision-1)

      return Num(+1, 1, exp)
    end
  end

  def inspect
    if $DEBUG
      "#{num_class}('#{self}') [coeff:#{@coeff.inspect} exp:#{@exp.inspect} s:#{@sign.inspect} radix:#{num_class.radix}]"
    else
      "#{num_class}('#{self}')"
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
    @coeff.is_a?(Integer) ? @coeff.to_s(num_class.radix).size : 0 # TODO: optimize in derived classes
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
    result = plus(:rounding=>r, :precision=>prec)
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
      slf = Decimal.new(self)
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
        self_coeff = Decimal.int_mult_radix_power(self_coeff, de)
      else
        other_coeff = Decimal.int_mult_radix_power(other_coeff, -de)
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
    dg = (@coeff%num_class.int_radix_power(i+1))/num_class.int_radix_power(i)
    if [0,num_class.radix/2].include?(dg)
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
        other = Decimal.new([other.sign, 1, exp])
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



# Decimal arbitrary precision floating point number.
# This implementation of Decimal is based on the Decimal module of Python,
# written by Eric Price, Facundo Batista, Raymond Hettinger, Aahz and Tim Peters.
class Decimal < Num # TODO: rename to Dec or DecNum ?

  class << self
    # Numerical base of Decimal.
    def radix
      10
    end

    # Integral power of the base: radix**n for integer n; returns an integer.
    def int_radix_power(n)
      10**n
    end

    # Multiply by an integral power of the base: x*(radix**n) for x,n integer;
    # returns an integer.
    def int_mult_radix_power(x,n)
      x * (10**n)
    end

    # Divide by an integral power of the base: x/(radix**n) for x,n integer;
    # returns an integer.
    def int_div_radix_power(x,n)
      x / (10**n)
    end
  end

  # The context defines the arithmetic context: rounding mode, precision,...
  # Decimal.context is the current (thread-local) context.
  class Context < Num::ContextBase

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
    def initialize(*options)
      super(Decimal, *options)
    end

    # Power. See Decimal#power()
    def power(x,y,modulo=nil)
      _convert(x).power(y,modulo,self)
    end

    # Returns the base 10 logarithm
    def log10(x)
      _convert(x).log10(self)
    end

    # Exponential function: e**x
    def exp(x)
      _convert(x).exp(self)
    end

    # Returns the natural (base e) logarithm
    def ln(x)
      _convert(x).ln(self)
    end

  end

  # the DefaultContext is the base for new contexts; it can be changed.
  DefaultContext = Decimal::Context.new(
                             :exact=>false, :precision=>28, :rounding=>:half_even,
                             :emin=> -999999999, :emax=>+999999999,
                             :flags=>[],
                             :traps=>[DivisionByZero, Overflow, InvalidOperation],
                             :ignored_flags=>[],
                             :capitals=>true,
                             :clamp=>true)

  BasicContext = Decimal::Context.new(DefaultContext,
                             :precision=>9, :rounding=>:half_up,
                             :traps=>[DivisionByZero, Overflow, InvalidOperation, Clamped, Underflow],
                             :flags=>[])

  ExtendedContext = Decimal::Context.new(DefaultContext,
                             :precision=>9, :rounding=>:half_even,
                             :traps=>[], :flags=>[], :clamp=>false)

  #--
  # =Notes on the representation of Decimal numbers.
  #
  #   @sign is +1 for plus and -1 for minus
  #   @coeff is the integral significand stored as an integer (so leading zeros cannot be kept)
  #   @exp is the exponent to be applied to @coeff as an integer or one of :inf, :nan, :snan for special values
  #
  # The Python Decimal representation has these slots:
  #   _sign is 1 for minus, 0 for plus
  #   _int is the integral significand as a string of digits (leading zeroes are not kept)
  #   _exp is the exponent as an integer or 'F' for infinity, 'n' for NaN , 'N' for sNaN
  #   _is_especial is true for special values (infinity, NaN, sNaN)
  # An additional class _WorkRep is used in Python for non-special decimal values with:
  #   sign
  #   int (significand as an integer)
  #   exp
  #
  # =Exponent values
  #
  # In GDAS (General Decimal Arithmetic Specification) numbers are represented by an unnormalized integral
  # significand and an exponent (also called 'scale'.)
  #
  # The reduce operation (originally called 'normalize') removes trailing 0s and increments the exponent if necessary;
  # the representation is rescaled to use the maximum exponent possible (while maintaining an integral significand.)
  #
  # A classical floating-point normalize opration would remove leading 0s and decrement the exponent instead,
  # rescaling to the minimum exponent theat maintains the significand value under some conventional limit (1 or the radix).
  #
  # The logb and adjusted operations return the exponent that applies to the most significand digit (logb as a Decimal
  # and adjusted as an integer.) This is the normalized scientific exponent.
  #
  # The most common normalized exponent is the normalized integral exponent for a fixed number of precision digits.
  #
  # The normalized fractional exponent is what BigDecima#exponent returns.
  #
  # ==Relations between exponent values
  #
  # The number of (kept) significand digits is s = a - e + 1
  # where a is the adjusted exponent and e is the internal exponent (the unnormalized integral exponent.)
  #
  # The number of significant digits (excluding leading and trailing zeroes) is sr = a - re + 1
  # where re is the internal exponent of the reduced value.
  #
  # The normalized integral exponent is e - (p - s) = a - p + 1
  # where p is the fixed precision.
  #
  # The normalized fractional exponent is e + s = a + 1
  #
  # ==Example: 0.01204
  #
  # * The integral significand is 120400 and the internal exponent that applies to it is e = -7
  # * The number of significand digits is s = 6
  # * The reduced representation is 1204 with internal exponent re = -5
  # * The number of significant digits sr = 4
  # * The adjusted exponent is a = -2 (the adjusted representation is 1.204 with exponent -2)
  # * Given a precision p = 8, the normalized integral representation is 12040000 with exponent -9
  # * The normalized fractional representation is 0.1204 with exponent -1
  #
  # ==Exponent limits
  #
  # The (integral) exponent e must be within this limits: etiny <= e <= etop
  # The adjusted exponent a must: emin <= a <= emax
  # emin, emax are the limite of the exponent shown in scientific notation and are use to defined
  # the exponent limits in the contexts.
  # etiny = emin-precision+1 and etop=emax-precision+1 are the limits of the internal exponent.
  # Note that for significands with less than precision digits we can use exponents greater than etop
  # without causing overflow: +Decimal(+1,1,emax) == Decimal(+1,K,etop) where K=10**(precision-1)
  #
  # =Interoperatibility with other numeric types
  #
  # For some numeric types implicit conversion to Decimal is defined through these methods:
  # * Decimal#coerce() is used when a Decimal is the right hand of an operator
  #   and the left hand is another numeric type
  # * Decimal#_bin_op() used internally to define binary operators and use the Ruby coerce protocol:
  #   if the right-hand operand is of known type it is converted with Decimal; otherwise use coerce
  # * _convert() converts known types to Decimal with Decimal() or raises an exception.
  # * Decimal() casts known types and text representations of numbers to Decimal using the constructor.
  # * Decimal#initialize performs the actual type conversion
  #
  # The known or 'coercible' types are initially Integer and Rational, but this can be extended to
  # other types using define_conversion_from() in a Context object.
  #++

  # A decimal value can be defined by:
  # * A String containing a text representation of the number
  # * An Integer
  # * A Rational
  # * Another Decimal value.
  # * A sign, coefficient and exponent (either as separate arguments, as an array or as a Hash with symbolic keys).
  #   This is the internal representation of Decimal, as returned by Decimal#split.
  #   The sign is +1 for plus and -1 for minus; the coefficient and exponent are
  #   integers, except for special values which are defined by :inf, :nan or :snan for the exponent.
  # An optional Context can be passed as the last argument to override the current context; also a hash can be passed
  # to override specific context parameters.
  # The Decimal() admits the same parameters and can be used as a shortcut for Decimal creation.
  def initialize(*args)
    super(*args)
  end

  # ...

  # Ruby-style to string conversion.
  def to_s(eng=false,context=nil)
    # (context || num_class.context).to_string(self)
    context = define_context(context)
    sgn = sign<0 ? '-' : ''
    if special?
      if @exp==:inf
        "#{sgn}Infinity"
      elsif @exp==:nan
        "#{sgn}NaN#{@coeff}"
      else # exp==:snan
        "#{sgn}sNaN#{@coeff}"
      end
    else
      ds = @coeff.to_s
      n_ds = ds.size
      exp = integral_exponent
      leftdigits = exp + n_ds
      if exp<=0 && leftdigits>-6
        dotplace = leftdigits
      elsif !eng
        dotplace = 1
      elsif @coeff==0
        dotplace = (leftdigits+1)%3 - 1
      else
        dotplace = (leftdigits-1)%3 + 1
      end

      if dotplace <=0
        intpart = '0'
        fracpart = '.' + '0'*(-dotplace) + ds
      elsif dotplace >= n_ds
        intpart = ds + '0'*(dotplace - n_ds)
        fracpart = ''
      else
        intpart = ds[0...dotplace]
        fracpart = '.' + ds[dotplace..-1]
      end

      if leftdigits == dotplace
        e = ''
      else
        e = (context.capitals ? 'E' : 'e') + "%+d"%(leftdigits-dotplace)
      end

      sgn + intpart + fracpart + e

    end
  end

  # Raises to the power of x, to modulo if given.
  #
  # With two arguments, compute self**other.  If self is negative then other
  # must be integral.  The result will be inexact unless other is
  # integral and the result is finite and can be expressed exactly
  # in 'precision' digits.
  #
  # With three arguments, compute (self**other) % modulo.  For the
  # three argument form, the following restrictions on the
  # arguments hold:
  #
  #  - all three arguments must be integral
  #  - other must be nonnegative
  #  - at least one of self or other must be nonzero
  #  - modulo must be nonzero and have at most 'precision' digits
  #
  # The result of a.power(b, modulo) is identical to the result
  # that would be obtained by computing (a**b) % modulo with
  # unbounded precision, but is computed more efficiently.  It is
  # always exact.
  def power(other, modulo=nil, context=nil)

    if context.nil? && (modulo.is_a?(Context) || modulo.is_a?(Hash))
      context = modulo
      modulo = nil
    end

    return self.power_modulo(other, modulo, context) if modulo

    context = Decimal.define_context(context)
    other = _convert(other)

    ans = _check_nans(context, other)
    return ans if ans

    # 0**0 = NaN (!), x**0 = 1 for nonzero x (including +/-Infinity)
    if other.zero?
      if self.zero?
        return context.exception(InvalidOperation, '0 ** 0')
      else
        return Decimal(1)
      end
    end

    # result has sign -1 iff self.sign is -1 and other is an odd integer
    result_sign = +1
    _self = self
    if _self.sign == -1
      if other.integral?
        result_sign = -1 if !other.even?
      else
        # -ve**noninteger = NaN
        # (-0)**noninteger = 0**noninteger
        unless self.zero?
          return context.exception(InvalidOperation, 'x ** y with x negative and y not an integer')
        end
      end
      # negate self, without doing any unwanted rounding
      _self = self.copy_negate
    end

    # 0**(+ve or Inf)= 0; 0**(-ve or -Inf) = Infinity
    if _self.zero?
      return (other.sign == +1) ? Decimal(result_sign, 0, 0) : Decimal.infinity(result_sign)
    end

    # Inf**(+ve or Inf) = Inf; Inf**(-ve or -Inf) = 0
    if _self.infinite?
      return (other.sign == +1) ? Decimal.infinity(result_sign) : Decimal(result_sign, 0, 0)
    end

    # 1**other = 1, but the choice of exponent and the flags
    # depend on the exponent of self, and on whether other is a
    # positive integer, a negative integer, or neither
    if _self == Decimal(1)
      return _self if context.exact?
      if other.integral?
        # exp = max(self._exp*max(int(other), 0),
        # 1-context.prec) but evaluating int(other) directly
        # is dangerous until we know other is small (other
        # could be 1e999999999)
        if other.sign == -1
          multiplier = 0
        elsif other > context.precision
          multiplier = context.precision
        else
          multiplier = other.to_i
        end

        exp = _self.exponent * multiplier
        if exp < 1-context.precision
          exp = 1-context.precision
          context.exception Rounded
        end
      else
        context.exception Rounded
        context.exception Inexact
        exp = 1-context.precision
      end

      return Decimal(result_sign, Decimal.int_radix_power(-exp), exp)
    end

    # compute adjusted exponent of self
    self_adj = _self.adjusted_exponent

    # self ** infinity is infinity if self > 1, 0 if self < 1
    # self ** -infinity is infinity if self < 1, 0 if self > 1
    if other.infinite?
      if (other.sign == +1) == (self_adj < 0)
        return Decimal(result_sign, 0, 0)
      else
        return Decimal.infinity(result_sign)
      end
    end

    # from here on, the result always goes through the call
    # to _fix at the end of this function.
    ans = nil

    # crude test to catch cases of extreme overflow/underflow.  If
    # log10(self)*other >= 10**bound and bound >= len(str(Emax))
    # then 10**bound >= 10**len(str(Emax)) >= Emax+1 and hence
    # self**other >= 10**(Emax+1), so overflow occurs.  The test
    # for underflow is similar.
    bound = _self._log10_exp_bound + other.adjusted_exponent
    if (self_adj >= 0) == (other.sign == +1)
      # self > 1 and other +ve, or self < 1 and other -ve
      # possibility of overflow
      if bound >= context.emax.to_s.length
        ans = Decimal(result_sign, 1, context.emax+1)
      end
    else
      # self > 1 and other -ve, or self < 1 and other +ve
      # possibility of underflow to 0
      etiny = context.etiny
      if bound >= (-etiny).to_s.length
        ans = Decimal(result_sign, 1, etiny-1)
      end
    end

    # try for an exact result with precision +1
    if ans.nil?
      if context.exact?
        if other.adjusted_exponent < 100
          test_precision = _self.number_of_digits*other.to_i+1
        else
          test_precision = _self.number_of_digits+1
        end
      else
        test_precision = context.precision + 1
      end
      ans = _self._power_exact(other, test_precision)
      if !ans.nil? && (result_sign == -1)
        ans = Decimal(-1, ans.coefficient, ans.exponent)
      end
    end

    # usual case: inexact result, x**y computed directly as exp(y*log(x))
    if !ans.nil?
      return ans if context.exact?
    else
      return context.exception(Inexact, "Inexact power") if context.exact?

      p = context.precision
      xc = _self.coefficient
      xe = _self.exponent
      yc = other.coefficient
      ye = other.exponent
      yc = -yc if other.sign == -1

      # compute correctly rounded result:  start with precision +3,
      # then increase precision until result is unambiguously roundable
      extra = 3
      coeff, exp = nil, nil
      loop do
        coeff, exp = _dpower(xc, xe, yc, ye, p+extra)
        #break if (coeff % Decimal.int_mult_radix_power(5,coeff.to_s.length-p-1)) != 0
        break if (coeff % (5*10**(coeff.to_s.length-p-1))) != 0
        extra += 3
      end
      ans = Decimal(result_sign, coeff, exp)
    end

    # the specification says that for non-integer other we need to
    # raise Inexact, even when the result is actually exact.  In
    # the same way, we need to raise Underflow here if the result
    # is subnormal.  (The call to _fix will take care of raising
    # Rounded and Subnormal, as usual.)
    if !other.integral?
      context.exception Inexact
      # pad with zeros up to length context.precision+1 if necessary
      if ans.number_of_digits <= context.precision
        expdiff = context.precision+1 - ans.number_of_digits
        ans = Decimal(ans.sign, Decimal.int_mult_radix_power(ans.coefficient, expdiff), ans.exponent-expdiff)
      end
      context.exception Underflow if ans.adjusted_exponent < context.emin
    end
    # unlike exp, ln and log10, the power function respects the
    # rounding mode; no need to use ROUND_HALF_EVEN here
    ans._fix(context)
  end

  # Returns the base 10 logarithm
  def log10(context=nil)
    context = Decimal.define_context(context)

    # log10(NaN) = NaN
    ans = _check_nans(context)
    return ans if ans

    # log10(0.0) == -Infinity
    return Decimal.infinity(-1) if self.zero?

    # log10(Infinity) = Infinity
    return Decimal.infinity if self.infinite? && self.sign == +1

    # log10(negative or -Infinity) raises InvalidOperation
    return context.exception(InvalidOperation, 'log10 of a negative value') if self.sign == -1

    digits = self.digits
    # log10(10**n) = n
    if digits.first == 1 && digits[1..-1].all?{|d| d==0}
      # answer may need rounding
      ans = Decimal(self.exponent + digits.size - 1)
      return ans if context.exact?
    else
      # result is irrational, so necessarily inexact
      return context.exception(Inexact, "Inexact power") if context.exact?
      c = self.coefficient
      e = self.exponent
      p = context.precision

      # correctly rounded result: repeatedly increase precision
      # until result is unambiguously roundable
      places = p-self._log10_exp_bound+2
      coeff = nil
      loop do
        coeff = _dlog10(c, e, places)
        # assert coeff.abs.to_s.length-p >= 1
        break if (coeff % (5*10**(coeff.abs.to_s.length-p-1)))!=0
        places += 3
      end
      ans = Decimal(coeff<0 ? -1 : +1, coeff.abs, -places)
    end

    Decimal.context(context, :rounding=>:half_even) do |local_context|
      ans = ans._fix(local_context)
      context.flags = local_context.flags
    end
    return ans
  end

  # Exponential function
  def exp(context=nil)
    context = Decimal.define_context(context)

    # exp(NaN) = NaN
    ans = _check_nans(context)
    return ans if ans

    # exp(-Infinity) = 0
    return Decimal.zero if self.infinite? && (self.sign == -1)

    # exp(0) = 1
    return Decimal(1) if self.zero?

    # exp(Infinity) = Infinity
    return Decimal(self) if self.infinite?

    # the result is now guaranteed to be inexact (the true
    # mathematical result is transcendental). There's no need to
    # raise Rounded and Inexact here---they'll always be raised as
    # a result of the call to _fix.
    return context.exception(Inexact, 'Inexact exp') if context.exact?
    p = context.precision
    adj = self.adjusted_exponent

    # we only need to do any computation for quite a small range
    # of adjusted exponents---for example, -29 <= adj <= 10 for
    # the default context.  For smaller exponent the result is
    # indistinguishable from 1 at the given precision, while for
    # larger exponent the result either overflows or underflows.
    if self.sign == +1 and adj > ((context.emax+1)*3).to_s.length
      # overflow
      ans = Decimal(+1, 1, context.emax+1)
    elsif self.sign == -1 and adj > ((-context.etiny+1)*3).to_s.length
      # underflow to 0
      ans = Decimal(+1, 1, context.etiny-1)
    elsif self.sign == +1 and adj < -p
      # p+1 digits; final round will raise correct flags
      ans = Decimal(+1, Decimal.int_radix_power(p)+1, -p)
    elsif self.sign == -1 and adj < -p-1
      # p+1 digits; final round will raise correct flags
      ans = Decimal(+1, Decimal.int_radix_power(p+1)-1, -p-1)
    else
      # general case
      c = self.coefficient
      e = self.exponent
      c = -c if self.sign == -1

      # compute correctly rounded result: increase precision by
      # 3 digits at a time until we get an unambiguously
      # roundable result
      extra = 3
      coeff = exp = nil
      loop do
        coeff, exp = _dexp(c, e, p+extra)
        break if (coeff % (5*10**(coeff.to_s.length-p-1)))!=0
        extra += 3
      end
      ans = Decimal(+1, coeff, exp)
    end

    # at this stage, ans should round correctly with *any*
    # rounding mode, not just with ROUND_HALF_EVEN
    Decimal.context(context, :rounding=>:half_even) do |local_context|
      ans = ans._fix(local_context)
      context.flags = local_context.flags
    end

    return ans
  end

  # Returns the natural (base e) logarithm
  def ln(context=nil)
    context = Decimal.define_context(context)

    # ln(NaN) = NaN
    ans = _check_nans(context)
    return ans if ans

    # ln(0.0) == -Infinity
    return Decimal.infinity(-1) if self.zero?

    # ln(Infinity) = Infinity
    return Decimal.infinity if self.infinite? && self.sign == +1

    # ln(1.0) == 0.0
    return Decimal.zero if self == Decimal(1)

    # ln(negative) raises InvalidOperation
    return context.exception(InvalidOperation, 'ln of a negative value') if self.sign==-1

    # result is irrational, so necessarily inexact
    return context.exception(Inexact, 'Inexact exp') if context.exact?

    c = self.coefficient
    e = self.exponent
    p = context.precision

    # correctly rounded result: repeatedly increase precision by 3
    # until we get an unambiguously roundable result
    places = p - self._ln_exp_bound + 2 # at least p+3 places
    coeff = nil
    loop do
      coeff = _dlog(c, e, places)
      # assert coeff.to_s.length-p >= 1
      break if (coeff % (5*10**(coeff.abs.to_s.length-p-1))) != 0
      places += 3
    end
    ans = Decimal((coeff<0) ? -1 : +1, coeff.abs, -places)

    Decimal.context(context, :rounding=>:half_even) do |local_context|
      ans = ans._fix(local_context)
      context.flags = local_context.flags
    end
    return ans
  end

  # Auxiliar Methods



  # Power-modulo: self._power_modulo(other, modulo) == (self**other) % modulo
  # This is equivalent to Python's 3-argument version of pow()
  def _power_modulo(other, modulo, context=nil)

    context = Decimal.define_context(context)
    other = _convert(other)
    modulo = _convert(third)

    if self.nan? || other.nan? || modulo.nan?
      return context.exception(InvalidOperation, 'sNaN', self) if self.snan?
      return context.exception(InvalidOperation, 'sNaN', other) if other.snan?
      return context.exception(InvalidOperation, 'sNaN', modulo) if other.modulo?
      return self._fix_nan(context) if self.nan?
      return other._fix_nan(context) if other.nan?
      return modulo._fix_nan(context) # if modulo.nan?
    end

    if !(self.integral? && other.integral? && modulo.integral?)
      return context.exception(InvalidOperation, '3-argument power not allowed unless all arguments are integers.')
    end

    if other < 0
      return context.exception(InvalidOperation, '3-argument power cannot have a negative 2nd argument.')
    end

    if modulo.zero?
      return context.exception(InvalidOperation, '3-argument power cannot have a 0 3rd argument.')
    end

    if modulo.adjusted_exponent >= context.precision
      return context.exception(InvalidOperation, 'insufficient precision: power 3rd argument must not have more than precision digits')
    end

    if other.zero? && self.zero?
      return context.exception(InvalidOperation, "0**0 not defined")
    end

    sign = other.even? ? +1 : -1
    modulo = modulo.to_i.abs

    base = (self.coefficient % modulo * (Decimal.int_radix_power(self.exponent) % modulo)) % modulo

    other.exponent.times do
      base = (base**Decimal.radix) % modulo
    end
    base = (base**other.coefficient) % modulo

    Decimal(sign, base, 0)
  end

  # Attempt to compute self**other exactly
  # Given Decimals self and other and an integer p, attempt to
  # compute an exact result for the power self**other, with p
  # digits of precision.  Return nil if self**other is not
  # exactly representable in p digits.
  #
  # Assumes that elimination of special cases has already been
  # performed: self and other must both be nonspecial; self must
  # be positive and not numerically equal to 1; other must be
  # nonzero.  For efficiency, other.exponent should not be too large,
  # so that 10**other.exponent.abs is a feasible calculation.
  def _power_exact(other, p)

    # In the comments below, we write x for the value of self and
    # y for the value of other.  Write x = xc*10**xe and y =
    # yc*10**ye.

    # The main purpose of this method is to identify the *failure*
    # of x**y to be exactly representable with as little effort as
    # possible.  So we look for cheap and easy tests that
    # eliminate the possibility of x**y being exact.  Only if all
    # these tests are passed do we go on to actually compute x**y.

    # Here's the main idea.  First normalize both x and y.  We
    # express y as a rational m/n, with m and n relatively prime
    # and n>0.  Then for x**y to be exactly representable (at
    # *any* precision), xc must be the nth power of a positive
    # integer and xe must be divisible by n.  If m is negative
    # then additionally xc must be a power of either 2 or 5, hence
    # a power of 2**n or 5**n.
    #
    # There's a limit to how small |y| can be: if y=m/n as above
    # then:
    #
    #  (1) if xc != 1 then for the result to be representable we
    #      need xc**(1/n) >= 2, and hence also xc**|y| >= 2.  So
    #      if |y| <= 1/nbits(xc) then xc < 2**nbits(xc) <=
    #      2**(1/|y|), hence xc**|y| < 2 and the result is not
    #      representable.
    #
    #  (2) if xe != 0, |xe|*(1/n) >= 1, so |xe|*|y| >= 1.  Hence if
    #      |y| < 1/|xe| then the result is not representable.
    #
    # Note that since x is not equal to 1, at least one of (1) and
    # (2) must apply.  Now |y| < 1/nbits(xc) iff |yc|*nbits(xc) <
    # 10**-ye iff len(str(|yc|*nbits(xc)) <= -ye.
    #
    # There's also a limit to how large y can be, at least if it's
    # positive: the normalized result will have coefficient xc**y,
    # so if it's representable then xc**y < 10**p, and y <
    # p/log10(xc).  Hence if y*log10(xc) >= p then the result is
    # not exactly representable.

    # if len(str(abs(yc*xe)) <= -ye then abs(yc*xe) < 10**-ye,
    # so |y| < 1/xe and the result is not representable.
    # Similarly, len(str(abs(yc)*xc_bits)) <= -ye implies |y|
    # < 1/nbits(xc).

    xc = self.coefficient
    xe = self.exponent
    while (xc % Decimal.radix) == 0
      xc /= Decimal.radix
      xe += 1
    end

    yc = other.coefficient
    ye = other.exponent
    while (yc % Decimal.radix) == 0
      yc /= Decimal.radix
      ye += 1
    end

    # case where xc == 1: result is 10**(xe*y), with xe*y
    # required to be an integer
    if xc == 1
      if ye >= 0
        exponent = xe*yc*Decimal.int_radix_power(ye)
      else
        exponent, remainder = (xe*yc).divmod(Decimal.int_radix_power(-ye))
        return nil if remainder!=0
      end
      exponent = -exponent if other.sign == -1
      # if other is a nonnegative integer, use ideal exponent
      if other.integral? and (other.sign == +1)
        ideal_exponent = self.exponent*other.to_i
        zeros = [exponent-ideal_exponent, p-1].min
      else
        zeros = 0
      end
      return Decimal(+1, Decimal.int_radix_power(zeros), exponent-zeros)
    end

    # case where y is negative: xc must be either a power
    # of 2 or a power of 5.
    if other.sign == -1
      last_digit = (xc % 10)
      if [2,4,6,8].include?(last_digit)
        # quick test for power of 2
        return nil if xc & -xc != xc
        # now xc is a power of 2; e is its exponent
        e = _nbits(xc)-1
        # find e*y and xe*y; both must be integers
        if ye >= 0
          y_as_int = yc*Decimal.int_radix_power(ye)
          e = e*y_as_int
          xe = xe*y_as_int
        else
          ten_pow = Decimal.int_radix_power(-ye)
          e, remainder = (e*yc).divmod(ten_pow)
          return nil if remainder!=0
          xe, remainder = (xe*yc).divmod(ten_pow)
          return nil if remainder!=0
        end

        return nil if e*65 >= p*93 # 93/65 > log(10)/log(5)
        xc = 5**e
      elsif last_digit == 5
        # e >= log_5(xc) if xc is a power of 5; we have
        # equality all the way up to xc=5**2658
        e = _nbits(xc)*28/65
        xc, remainder = (5**e).divmod(xc)
        return nil if remainder!=0
        while (xc % 5) == 0
          xc /= 5
          e -= 1
        end
        if ye >= 0
          y_as_integer = Decimal.int_mult_radix_power(yc,ye)
          e = e*y_as_integer
          xe = xe*y_as_integer
        else
          ten_pow = Decimal.int_radix_power(-ye)
          e, remainder = (e*yc).divmod(ten_pow)
          return nil if remainder
          xe, remainder = (xe*yc).divmod(ten_pow)
          return nil if remainder
        end
        return nil if e*3 >= p*10 # 10/3 > log(10)/log(2)
        xc = 2**e
      else
        return nil
      end

      return nil if xc >= Decimal.int_radix_power(p)
      xe = -e-xe
      return Decimal(+1, xc, xe)

    end

    # now y is positive; find m and n such that y = m/n
    if ye >= 0
      m, n = yc*10**ye, 1
    else
      return nil if (xe != 0) and ((yc*xe).abs.to_s.length <= -ye)
      xc_bits = _nbits(xc)
      return nil if (xc != 1) and ((yc.abs*xc_bits).to_s.length <= -ye)
      m, n = yc, Decimal.int_radix_power(-ye)
      while ((m % 2) == 0) && ((n % 2) == 0)
        m /= 2
        n /= 2
      end
      while ((m % 5) == 0) && ((n % 5) == 0)
        m /= 5
        n /= 5
      end
    end

    # compute nth root of xc*10**xe
    if n > 1
      # if 1 < xc < 2**n then xc isn't an nth power
      return nil if xc != 1 and xc_bits <= n

      xe, rem = xe.divmod(n)
      return nil if rem != 0

      # compute nth root of xc using Newton's method
      a = 1 << -(-_nbits(xc)/n) # initial estimate
      q = r = nil
      loop do
        q, r = xc.divmod(a**(n-1))
        break if a <= q
        a = (a*(n-1) + q)/n
      end
      return nil if !((a == q) and (r == 0))
      xc = a
    end

    # now xc*10**xe is the nth root of the original xc*10**xe
    # compute mth power of xc*10**xe

    # if m > p*100/_log10_lb(xc) then m > p/log10(xc), hence xc**m >
    # 10**p and the result is not representable.
    return nil if (xc > 1) and (m > p*100/_log10_lb(xc))
    xc = xc**m
    xe *= m
    return nil if xc > 10**p

    # by this point the result *is* exactly representable
    # adjust the exponent to get as close as possible to the ideal
    # exponent, if necessary
    str_xc = xc.to_s
    if other.integral? && other.sign == +1
      ideal_exponent = self.exponent*other.to_i
      zeros = [xe-ideal_exponent, p-str_xc.length].min
    else
      zeros = 0
    end
    return Decimal(+1, Decimal.int_mult_radix_power(xc, zeros), xe-zeros)
  end

  # Compute a lower bound for the adjusted exponent of self.log10()
  # In other words, find r such that self.log10() >= 10**r.
  # Assumes that self is finite and positive and that self != 1.
  def _log10_exp_bound
    # For x >= 10 or x < 0.1 we only need a bound on the integer
    # part of log10(self), and this comes directly from the
    # exponent of x.  For 0.1 <= x <= 10 we use the inequalities
    # 1-1/x <= log(x) <= x-1. If x > 1 we have |log10(x)| >
    # (1-1/x)/2.31 > 0.  If x < 1 then |log10(x)| > (1-x)/2.31 > 0

    adj = self.exponent + number_of_digits - 1
    return adj.to_s.length - 1 if adj >= 1 # self >= 10
    return (-1-adj).to_s.length-1 if adj <= -2 # self < 0.1

    c = self.coefficient
    e = self.exponent
    if adj == 0
      # 1 < self < 10
      num = (c - Decimal.int_radix_power(-e)).to_s
      den = (231*c).to_s
      return num.length - den.length - ((num < den) ? 1 : 0) + 2
    end
    # adj == -1, 0.1 <= self < 1
    num = (Decimal.int_radix_power(-e)-c).to_s
    return num.length + e - ((num < "231") ? 1 : 0) - 1
  end

  # Compute a lower bound for the adjusted exponent of self.ln().
  # In other words, compute r such that self.ln() >= 10**r.  Assumes
  # that self is finite and positive and that self != 1.
  def _ln_exp_bound
    # for 0.1 <= x <= 10 we use the inequalities 1-1/x <= ln(x) <= x-1
    adj = self.exponent + number_of_digits - 1
    if adj >= 1
      # argument >= 10; we use 23/10 = 2.3 as a lower bound for ln(10)
      return (adj*23/10).to_s.length - 1
    end
    if adj <= -2
      # argument <= 0.1
      return ((-1-adj)*23/10).to_s.length - 1
    end
    c = self.coefficient
    e = self.exponent
    if adj == 0
      # 1 < self < 10
      num = (c-(10**-e)).to_s
      den = c.to_s
      return num.length - den.length - ((num < den) ? 1 : 0)
    end
    # adj == -1, 0.1 <= self < 1
    return e + (10**-e - c).to_s.length - 1
  end

  module AuxiliarFunctions #:nodoc:

    module_function

    # Number of bits in binary representation of the positive integer n, or 0 if n == 0.
    #--
    # This function from Tim Peters was taken from here:
    # http://mail.python.org/pipermail/python-list/1999-July/007758.html
    # The correction being in the function definition is for speed, and
    # the whole function is not resolved with math.log because of avoiding
    # the use of floats.
    #++
    def _nbits(n, correction = {                      #:nodoc:
            '0'=> 4, '1'=> 3, '2'=> 2, '3'=> 2,
            '4'=> 1, '5'=> 1, '6'=> 1, '7'=> 1,
            '8'=> 0, '9'=> 0, 'a'=> 0, 'b'=> 0,
            'c'=> 0, 'd'=> 0, 'e'=> 0, 'f'=> 0})
      raise  TypeError, "The argument to _nbits should be nonnegative." if n < 0
      hex_n = "%x" % n
      4*hex_n.length - correction[hex_n[0,1]]
    end

    # Given integers xc, xe, yc and ye representing Decimals x = xc*10**xe and
    # y = yc*10**ye, compute x**y.  Returns a pair of integers (c, e) such that:
    #
    #   10**(p-1) <= c <= 10**p, and
    #   (c-1)*10**e < x**y < (c+1)*10**e
    #
    # in other words, c*10**e is an approximation to x**y with p digits
    # of precision, and with an error in c of at most 1.  (This is
    # almost, but not quite, the same as the error being < 1ulp: when c
    # == 10**(p-1) we can only guarantee error < 10ulp.)
    #
    # We assume that: x is positive and not equal to 1, and y is nonzero.
    def _dpower(xc, xe, yc, ye, p)
      # Find b such that 10**(b-1) <= |y| <= 10**b
      b = yc.abs.to_s.length + ye

      # log(x) = lxc*10**(-p-b-1), to p+b+1 places after the decimal point
      lxc = _dlog(xc, xe, p+b+1)

      # compute product y*log(x) = yc*lxc*10**(-p-b-1+ye) = pc*10**(-p-1)
      shift = ye-b
      if shift >= 0
          pc = lxc*yc*10**shift
      else
          pc = _div_nearest(lxc*yc, 10**-shift)
      end

      if pc == 0
          # we prefer a result that isn't exactly 1; this makes it
          # easier to compute a correctly rounded result in __pow__
          if (xc.to_s.length + xe >= 1) == (yc > 0) # if x**y > 1:
              coeff, exp = 10**(p-1)+1, 1-p
          else
              coeff, exp = 10**p-1, -p
          end
      else
          coeff, exp = _dexp(pc, -(p+1), p+1)
          coeff = _div_nearest(coeff, 10)
          exp += 1
      end

      return coeff, exp
    end

    # Compute an approximation to exp(c*10**e), with p decimal places of precision.
    # Returns integers d, f such that:
    #
    #   10**(p-1) <= d <= 10**p, and
    #   (d-1)*10**f < exp(c*10**e) < (d+1)*10**f
    #
    # In other words, d*10**f is an approximation to exp(c*10**e) with p
    # digits of precision, and with an error in d of at most 1.  This is
    # almost, but not quite, the same as the error being < 1ulp: when d
    # = 10**(p-1) the error could be up to 10 ulp.
    def _dexp(c, e, p)
        # we'll call iexp with M = 10**(p+2), giving p+3 digits of precision
        p += 2

        # compute log(10) with extra precision = adjusted exponent of c*10**e
        extra = [0, e + c.to_s.length - 1].max
        q = p + extra

        # compute quotient c*10**e/(log(10)) = c*10**(e+q)/(log(10)*10**q),
        # rounding down
        shift = e+q
        if shift >= 0
            cshift = c*10**shift
        else
            cshift = c/10**-shift
        end
        quot, rem = cshift.divmod(_log10_digits(q))

        # reduce remainder back to original precision
        rem = _div_nearest(rem, 10**extra)

        # error in result of _iexp < 120;  error after division < 0.62
        return _div_nearest(_iexp(rem, 10**p), 1000), quot - p + 3
    end

    # Closest integer to a/b, a and b positive integers; rounds to even
    # in the case of a tie.
    def _div_nearest(a, b)
      q, r = a.divmod(b)
      q + (((2*r + (q&1)) > b) ? 1 : 0)
    end

    # Closest integer to the square root of the positive integer n.  a is
    # an initial approximation to the square root.  Any positive integer
    # will do for a, but the closer a is to the square root of n the
    # faster convergence will be.
    def _sqrt_nearest(n, a)

        if n <= 0 or a <= 0
            raise ArgumentError, "Both arguments to _sqrt_nearest should be positive."
        end

        b=0
        while a != b
            b, a = a, a--n/a>>1 # ??
        end
        return a
    end

    # Given an integer x and a nonnegative integer shift, return closest
    # integer to x / 2**shift; use round-to-even in case of a tie.
    def _rshift_nearest(x, shift)
        b, q = (1 << shift), (x >> shift)
        return q + (((2*(x & (b-1)) + (q&1)) > b) ? 1 : 0)
        #return q + (2*(x & (b-1)) + (((q&1) > b) ? 1 : 0))
    end

    # Integer approximation to M*log(x/M), with absolute error boundable
    # in terms only of x/M.
    #
    # Given positive integers x and M, return an integer approximation to
    # M * log(x/M).  For L = 8 and 0.1 <= x/M <= 10 the difference
    # between the approximation and the exact result is at most 22.  For
    # L = 8 and 1.0 <= x/M <= 10.0 the difference is at most 15.  In
    # both cases these are upper bounds on the error; it will usually be
    # much smaller.
    def _ilog(x, m, l = 8)
      # The basic algorithm is the following: let log1p be the function
      # log1p(x) = log(1+x).  Then log(x/M) = log1p((x-M)/M).  We use
      # the reduction
      #
      #    log1p(y) = 2*log1p(y/(1+sqrt(1+y)))
      #
      # repeatedly until the argument to log1p is small (< 2**-L in
      # absolute value).  For small y we can use the Taylor series
      # expansion
      #
      #    log1p(y) ~ y - y**2/2 + y**3/3 - ... - (-y)**T/T
      #
      # truncating at T such that y**T is small enough.  The whole
      # computation is carried out in a form of fixed-point arithmetic,
      # with a real number z being represented by an integer
      # approximation to z*M.  To avoid loss of precision, the y below
      # is actually an integer approximation to 2**R*y*M, where R is the
      # number of reductions performed so far.

      y = x-m
      # argument reduction; R = number of reductions performed
      r = 0
      # while (r <= l && y.abs << l-r >= m ||
      #        r > l and y.abs>> r-l >= m)
      while (((r <= l) && ((y.abs << (l-r)) >= m)) ||
             ((r > l) && ((y.abs>>(r-l)) >= m)))
          y = _div_nearest((m*y) << 1,
                           m + _sqrt_nearest(m*(m+_rshift_nearest(y, r)), m))
          r += 1
      end

      # Taylor series with T terms
      t = -(-10*m.to_s.length/(3*l)).to_i
      yshift = _rshift_nearest(y, r)
      w = _div_nearest(m, t)
      # (1...t).reverse_each do |k| # Ruby 1.9
      (1...t).to_a.reverse.each do |k|
         w = _div_nearest(m, k) - _div_nearest(yshift*w, m)
      end

      return _div_nearest(w*y, m)
    end

    # Given integers c, e and p with c > 0, p >= 0, compute an integer
    # approximation to 10**p * log10(c*10**e), with an absolute error of
    # at most 1.  Assumes that c*10**e is not exactly 1.
    def _dlog10(c, e, p)
       # increase precision by 2; compensate for this by dividing
      # final result by 100
      p += 2

      # write c*10**e as d*10**f with either:
      #   f >= 0 and 1 <= d <= 10, or
      #   f <= 0 and 0.1 <= d <= 1.
      # Thus for c*10**e close to 1, f = 0
      l = c.to_s.length
      f = e+l - ((e+l >= 1) ? 1 : 0)

      if p > 0
        m = 10**p
        k = e+p-f
        if k >= 0
          c *= 10**k
        else
          c = _div_nearest(c, 10**-k)
        end
        log_d = _ilog(c, m) # error < 5 + 22 = 27
        log_10 = _log10_digits(p) # error < 1
        log_d = _div_nearest(log_d*m, log_10)
        log_tenpower = f*m # exact
      else
        log_d = 0  # error < 2.31
        log_tenpower = _div_nearest(f, 10**-p) # error < 0.5
      end

      return _div_nearest(log_tenpower+log_d, 100)
    end

    # Compute a lower bound for 100*log10(c) for a positive integer c.
    def _log10_lb(c, correction = {
            '1'=> 100, '2'=> 70, '3'=> 53, '4'=> 40, '5'=> 31,
            '6'=> 23, '7'=> 16, '8'=> 10, '9'=> 5})
        raise ArgumentError, "The argument to _log10_lb should be nonnegative." if c <= 0
        str_c = c.to_s
        return 100*str_c.length - correction[str_c[0,1]]
    end

    # Given integers c, e and p with c > 0, compute an integer
    # approximation to 10**p * log(c*10**e), with an absolute error of
    # at most 1.  Assumes that c*10**e is not exactly 1.
    def _dlog(c, e, p)

        # Increase precision by 2. The precision increase is compensated
        # for at the end with a division by 100.
        p += 2

        # rewrite c*10**e as d*10**f with either f >= 0 and 1 <= d <= 10,
        # or f <= 0 and 0.1 <= d <= 1.  Then we can compute 10**p * log(c*10**e)
        # as 10**p * log(d) + 10**p*f * log(10).
        l = c.to_s.length
        f = e+l - ((e+l >= 1) ? 1 : 0)

        # compute approximation to 10**p*log(d), with error < 27
        if p > 0
            k = e+p-f
            if k >= 0
                c *= 10**k
            else
                c = _div_nearest(c, 10**-k)  # error of <= 0.5 in c
            end

            # _ilog magnifies existing error in c by a factor of at most 10
            log_d = _ilog(c, 10**p) # error < 5 + 22 = 27
        else
            # p <= 0: just approximate the whole thing by 0; error < 2.31
            log_d = 0
        end

        # compute approximation to f*10**p*log(10), with error < 11.
        if f
            extra = f.abs.to_s.length - 1
            if p + extra >= 0
                # error in f * _log10_digits(p+extra) < |f| * 1 = |f|
                # after division, error < |f|/10**extra + 0.5 < 10 + 0.5 < 11
                f_log_ten = _div_nearest(f*_log10_digits(p+extra), 10**extra)
            else
                f_log_ten = 0
            end
        else
            f_log_ten = 0
        end

        # error in sum < 11+27 = 38; error after division < 0.38 + 0.5 < 1
        return _div_nearest(f_log_ten + log_d, 100)
    end

    # Given integers x and M, M > 0, such that x/M is small in absolute
    # value, compute an integer approximation to M*exp(x/M).  For 0 <=
    # x/M <= 2.4, the absolute error in the result is bounded by 60 (and
    # is usually much smaller).
    def _iexp(x, m, l=8)

        # Algorithm: to compute exp(z) for a real number z, first divide z
        # by a suitable power R of 2 so that |z/2**R| < 2**-L.  Then
        # compute expm1(z/2**R) = exp(z/2**R) - 1 using the usual Taylor
        # series
        #
        #     expm1(x) = x + x**2/2! + x**3/3! + ...
        #
        # Now use the identity
        #
        #     expm1(2x) = expm1(x)*(expm1(x)+2)
        #
        # R times to compute the sequence expm1(z/2**R),
        # expm1(z/2**(R-1)), ... , exp(z/2), exp(z).

        # Find R such that x/2**R/M <= 2**-L
        r = _nbits((x<<l)/m)

        # Taylor series.  (2**L)**T > M
        t = -(-10*m.to_s.length/(3*l)).to_i
        y = _div_nearest(x, t)
        mshift = m<<r
        (1...t).to_a.reverse.each do |i|
            y = _div_nearest(x*(mshift + y), mshift * i)
        end

        # Expansion
        (0...r).to_a.reverse.each do |k|
            mshift = m<<(k+2)
            y = _div_nearest(y*(y+mshift), mshift)
        end

        return m+y
    end

    # We'll memoize the digits of log(10):
    @log10_digits = "23025850929940456840179914546843642076011014886"
    class <<self
      attr_accessor :log10_digits
    end

    # Given an integer p >= 0, return floor(10**p)*log(10).
    def _log10_digits(p)
      # digits are stored as a string, for quick conversion to
      # integer in the case that we've already computed enough
      # digits; the stored digits should always be correct
      # (truncated, not rounded to nearest).
      raise ArgumentError, "p should be nonnegative" if p<0
      if p >= AuxiliarFunctions.log10_digits.length
          digits = nil
          # compute p+3, p+6, p+9, ... digits; continue until at
          # least one of the extra digits is nonzero
          extra = 3
          loop do
            # compute p+extra digits, correct to within 1ulp
            m = 10**(p+extra+2)
            digits = _div_nearest(_ilog(10*m, m), 100).to_s
            break if digits[-extra..-1] != '0'*extra
            extra += 3
          end
          # keep all reliable digits so far; remove trailing zeros
          # and next nonzero digit
          AuxiliarFunctions.log10_digits = digits.sub(/0*$/,'')[0...-1]
      end
      return (AuxiliarFunctions.log10_digits[0...p+1]).to_i
    end

    # Compute an approximation to exp(c*10**e), with p decimal places of
    # precision.
    #
    # Returns integers d, f such that:
    #
    #   10**(p-1) <= d <= 10**p, and
    #   (d-1)*10**f < exp(c*10**e) < (d+1)*10**f
    #
    # In other words, d*10**f is an approximation to exp(c*10**e) with p
    # digits of precision, and with an error in d of at most 1.  This is
    # almost, but not quite, the same as the error being < 1ulp: when d
    # = 10**(p-1) the error could be up to 10 ulp.
    def dexp(c, e, p)
      # we'll call iexp with M = 10**(p+2), giving p+3 digits of precision
      p += 2

      # compute log(10) with extra precision = adjusted exponent of c*10**e
      extra = [0, e + c.to_s.length - 1].max
      q = p + extra

      # compute quotient c*10**e/(log(10)) = c*10**(e+q)/(log(10)*10**q),
      # rounding down
      shift = e+q
      if shift >= 0
          cshift = c*10**shift
      else
          cshift = c/10**-shift
      end
      quot, rem = cshift.divmod(_log10_digits(q))

      # reduce remainder back to original precision
      rem = _div_nearest(rem, 10**extra)

      # error in result of _iexp < 120;  error after division < 0.62
      return _div_nearest(_iexp(rem, 10**p), 1000), quot - p + 3
    end

  end # AuxiliarFunctions

  # This is for using auxiliar functions from Decimal instance method
  # without the "AuxiliarFunctions." prefix
  include AuxiliarFunctions
  # If we need to use them from Decimal class methods, we can avoid
  # the use of the prefix with:
  # extend AuxiliarFunctions

end

# Decimal constructor. See Decimal#new for the parameters.
# If a Decimal is passed a reference to it is returned (no new object is created).
def Decimal(*args)
  Decimal.Num(*args)
end

# ===================================================================================

class BinFloat < Num

  class << self
    # Numerical base of Decimal.
    def radix
      2
    end

    # Integral power of the base: radix**n for integer n; returns an integer.
    def int_radix_power(n)
      (n < 0) ? (2**n) : (1<<n)
    end

    # Multiply by an integral power of the base: x*(radix**n) for x,n integer;
    # returns an integer.
    def int_mult_radix_power(x,n)
      x * ((n < 0) ? (2**n) : (1<<n))
    end

    # Divide by an integral power of the base: x/(radix**n) for x,n integer;
    # returns an integer.
    def int_div_radix_power(x,n)
      x / ((n < 0) ? (2**n) : (1<<n))
    end
  end

  # The context defines the arithmetic context: rounding mode, precision,...
  # Decimal.context is the current (thread-local) context.
  class Context < Num::ContextBase

    def initialize(*options)
      super(BinFloat, *options)
    end

  end

  class <<self

    def base_coercible_types
      unless defined? @base_coercible_types
        @base_coercible_types = super.merge(
          Float=>lambda{|x, context|
            if x.nan?
              BinFloat.nan
            elsif x.infinite?
              BinFloat.infinity(x<0 ? -1 : +1)
            elsif x.zero?
              BinFloat.zero((x.to_s[0,1].strip=="-") ? -1 : +1)
            else
              coeff, exp = Math.frexp(x)
              coeff = Math.ldexp(coeff, Float::MANT_DIG).to_i
              exp -= Float::MANT_DIG
              if coeff < 0
                sign = -1
                coeff = -coeff
              else
                sign = +1
              end
              BinFloat(sign, coeff, exp)
            end
          }
        )
      end
      @base_coercible_types
    end
  end

  # the DefaultContext is the base for new contexts; it can be changed.
  DefaultContext = BinFloat::Context.new(
                             :exact=>false, :precision=>53, :rounding=>:half_even,
                             :emin=> -1025, :emax=>+1023,
                             :flags=>[],
                             :traps=>[DivisionByZero, Overflow, InvalidOperation],
                             :ignored_flags=>[],
                             :capitals=>true,
                             :clamp=>true)

  ExtendedContext = BinFloat::Context.new(DefaultContext,
                             :traps=>[], :flags=>[], :clamp=>false)


  def initialize(*args)
    super(*args)
  end

  # Ruby-style to string conversion.
  def to_s(eng=false,context=nil)
    # (context || num_class.context).to_string(self)
    context = define_context(context)
    sgn = sign<0 ? '-' : ''
    if special?
      if @exp==:inf
        "#{sgn}Infinity"
      elsif @exp==:nan
        "#{sgn}NaN#{@coeff}"
      else # exp==:snan
        "#{sgn}sNaN#{@coeff}"
      end
    else
      inexact = true
      rounding = context.rounding
      if @sign == -1
        if rounding == :ceiling
          rounding = :floor
        elsif rounding == :floor
          rounding = :ceiling
        end
      end
      output_radix = 10
      x = self.abs.to_f

      p = self.number_of_digits # use context.precision ? / handle exacts

      if false
        # use as many digits as possible
        dec_pos,r,*digits = BurgerDybvig.float_to_digits_max(x,@coeff,@exp,rounding,
                                 context.etiny,p,num_class.radix,output_radix)
        inexact = :roundup if r
      else
        # use as few digits as possible
        dec_pos,*digits = BurgerDybvig.float_to_digits(x,@coeff,@exp,rounding,
                                 context.etiny,p,num_class.radix,output_radix)
      end
      # TODO: format properly
      digits = digits.map{|d| d.to_s(output_radix)}.join
      if dec_pos <= 0
        if dec_pos >= -4 && digits.length <= 15
          digits = "0." + "0"*(-dec_pos) + digits
        else
          digits = digits[0,1]+"."+digits[1..-1]+"E#{dec_pos-1}"
        end
      elsif dec_pos > digits.length
        if dec_pos <= 20
          digits = digits + "0"*(dec_pos-digits.length)
        else
          # TODO: if digits.length == 1
          digits = digits[0,1]+"."+digits[1..-1]+"E#{dec_pos-1}"
        end
      elsif dec_pos != digits.length
        digits = digits[0...dec_pos] + "." + digits[dec_pos..-1]
      end
      txt = ((sign==-1) ? '-' : '') + digits
    end
  end

  # Specific to_f conversion TODO: check if it representes an optimization
  if Float::RADIX==2
    def to_f
      if special?
        super
      else
        Math.ldexp(@sign*@coeff, @exp)
      end
    end
  end

end

def BinFloat(*args)
  BinFloat.Num(*args)
end

  # these are functions from Nio::Clinger, generalized for arbitrary floating point formats
  module Clinger #:nodoc:

    module_function

    def ratio_float(context, u,v,k,round_mode)
      # since this handles only positive numbers and ceiling and floor
      # are not symmetrical, they should have been swapped before calling this.
      q = u.div v
      r = u-q*v
      v_r = v-r
      z = context.num_class.new(+1,q,k)
      exact = (r==0)
      if (round_mode == :down || round_mode == :floor)
        # z = z
      elsif (round_mode == :up || round_mode == :ceiling)
        z = z.next_plus(context)
      elsif r<v_r
        # z = z
      elsif r>v_r
        z = z.next_plus(context)
      else
        # tie
        if (round_mode == :half_down) || (round_mode == :half_even && ((q%2)==0)) ||
           (round_mode == :down) || (round_mode == :floor)
           # z = z
        else
          z = z.next_plus(context)
        end
      end
      return z, exact
    end

    def algM(context, f, e, round_mode, eb=10) # ceiling & floor must be swapped for negative numbers
      if e<0
       u,v,k = f,eb**(-e),0
      else
        u,v,k = f*(eb**e),1,0
      end

      if exact_mode = context.exact?
        exact_mode = :quiet if !context.traps[Num::Inexact]
        n = [(Math.log(u)/Math.log(2)).ceil,1].max # TODO: check if correct and optimize
        context.precision = n
      else
        n = context.precision
      end
      min_e = context.etiny
      max_e = context.etop

      rp_n = context.num_class.int_radix_power(n)
      rp_n_1 = context.num_class.int_radix_power(n-1)
      r = context.num_class.radix
      loop do
         x = u.div(v) # bottleneck
         # overflow if k>=max_e
         if (x>=rp_n_1 && x<rp_n) || k==min_e || k==max_e
            result = ratio_float(context,u,v,k,round_mode)
            context.exact = exact_mode if exact_mode
            return result
         elsif x<rp_n_1
           u *= r
           k -= 1
         elsif x>=rp_n
           v *= r
           k += 1
         end
      end

    end
  end

  # Burger and Dybvig free formatting algorithm, translated directly from Scheme;
  # after some testing, of the three different implementations in their
  # paper, the second seems to be more efficient in Ruby.
  # This algorithm formats arbitrary base floating pont numbers as decimal
  # text literals.
  module BurgerDybvig # :nodoc: all
    module_function
    def float_to_digits(v,f,e,round_mode,min_e,p,b,_B)
      # since this handles only positive numbers and ceiling and floor
      # are not symmetrical, they should have been swapped before calling this.
      roundl, roundh = rounding_h_l(round_mode, f)

        if e >= 0
          if f != exptt(b,p-1)
            be = exptt(b,e)
            r,s,m_p,m_m,k = scale(f*be*2,2,be,be,0,_B,roundl ,roundh,v)
          else
            be = exptt(b,e)
            be1 = be*b
            r,s,m_p,m_m,k = scale(f*be1*2,b*2,be1,be,0,_B,roundl ,roundh,v)
          end
        else
          if e==min_e or f != exptt(b,p-1)
            r,s,m_p,m_m,k = scale(f*2,exptt(b,-e)*2,1,1,0,_B,roundl ,roundh,v)
          else
            r,s,m_p,m_m,k = scale(f*b*2,exptt(b,1-e)*2,b,1,0,_B,roundl ,roundh,v)
          end
        end
        [k]+generate(r,s,m_p,m_m,_B,roundl ,roundh)
    end

    def float_to_digits_max(v,f,e,round_mode,min_e,p,b,_B)
      roundl, roundh = rounding_h_l(round_mode, f)
        if e >= 0
          if f != exptt(b,p-1)
            be = exptt(b,e)
            r,s,m_p,m_m,k = scale(f*be*2,2,be,be,0,_B,roundl ,roundh,v)
          else
            be = exptt(b,e)
            be1 = be*b
            r,s,m_p,m_m,k = scale(f*be1*2,b*2,be1,be,0,_B,roundl ,roundh,v)
          end
        else
          if e==min_e or f != exptt(b,p-1)
            r,s,m_p,m_m,k = scale(f*2,exptt(b,-e)*2,1,1,0,_B,roundl ,roundh,v)
          else
            r,s,m_p,m_m,k = scale(f*b*2,exptt(b,1-e)*2,b,1,0,_B,roundl ,roundh,v)
          end
        end
        [k]+generate_max(r,s,m_p,m_m,_B,roundl ,roundh)
    end

    def rounding_h_l(round_mode, f)
       # to support IEEE rounding modes (see algM) here,
       # the m_p,m_m passed to generate should be modified when the rounding
       # is :ieee_up,:ieee_down or :ieee_zero (here equivalent to :ieee_down since numbers as positive)
       # The should be substituted in those cases by r and r+1, and roundl,roundh would take
       # the values [true,false] for :ieee_down/:ieee_zero and [false,true] for :ieee_up
      case round_mode
        # TODO: review and complete
        when :half_even
          roundl = roundh = ((f%2)==0)
        when :up, :ceiling
          roundl = true
          roundh = false
        when :down, :floor
          roundl = false
          roundh = true
        else
          # here we don't assume any rounding in the floating point numbers
          # the result is valid for any rounding but may produce more digits
          # than stricly necessary for specifica rounding modes.
          roundl = false
          roundh = false
      end
      return roundl, roundh
    end

    def scale(r,s,m_p,m_m,k,_B,low_ok ,high_ok,v)
      return scale2(r,s,m_p,m_m,k,_B,low_ok ,high_ok) if v==0
      est = (logB(_B,v)-1E-10).ceil.to_i
      if est>=0
        fixup(r,s*exptt(_B,est),m_p,m_m,est,_B,low_ok,high_ok)
      else
        sc = exptt(_B,-est)
        fixup(r*sc,s,m_p*sc,m_m*sc,est,_B,low_ok,high_ok)
      end
    end

    def fixup(r,s,m_p,m_m,k,_B,low_ok,high_ok)
      if (high_ok ? (r+m_p >= s) : (r+m_p > s)) # too low?
        [r,s*_B,m_p,m_m,k+1]
      else
        [r,s,m_p,m_m,k]
      end
    end

    def scale2(r,s,m_p,m_m,k,_B,low_ok ,high_ok)
      loop do
        if (high_ok ? (r+m_p >= s) : (r+m_p > s)) # k is too low
          s *= _B
          k += 1
        elsif (high_ok ? ((r+m_p)*_B<s) : ((r+m_p)*_B<=s)) # k is too high
          r *= _B
          m_p *= _B
          m_m *= _B
          k -= 1
        else
          break
        end
      end
      [r,s,m_p,m_m,k]
    end

    def generate(r,s,m_p,m_m,_B,low_ok ,high_ok)
      list = []
      loop do
        d,r = (r*_B).divmod(s)
        m_p *= _B
        m_m *= _B
        tc1 = low_ok ? (r<=m_m) : (r<m_m)
        tc2 = high_ok ? (r+m_p >= s) : (r+m_p > s)

        if not tc1
          if not tc2
            list << d
          else
            list << d+1
            break
          end
        else
          if not tc2
            list << d
            break
          else
            if r*2 < s
              list << d
              break
            else
              list << d+1
              break
            end
          end
        end

      end
      list
    end

    def generate_max(r,s,m_p,m_m,_B,low_ok ,high_ok)
      list = [false]
      loop do
        d,r = (r*_B).divmod(s)
        m_p *= _B
        m_m *= _B

        list << d

        tc1 = low_ok ? (r<=m_m) : (r<m_m)
        tc2 = high_ok ? (r+m_p >= s) : (r+m_p > s)

        if tc1 && tc2
          list[0] = true if r*2 >= s
          break
        end
      end
      list
    end

    def exptt(_B, k)
      _B**k # TODO: memoize computed values or use table for common bases and exponents
    end

    def logB(_B, x)
      Math.log(x)/Math.log(_B) # TODO: memoize 1/log(_B)
    end

  end

end # BigFloat