# Base classes for floating-point numbers and contexts.

#--
# TODO: selecting the kind of ulp is awkward; consider one of these options:
#       * don't support variant ulps; always use Muller's ulp
#       * use an options hash for the kind of ulp parameter
#       * keep the kind of ulp in the context
#       also, note that Tolerance uses only the Muller king of ulp.
# TODO: move the exception classes from Flt::Num to Flt ? move also Flt::Num::ContextBas to Flt ?
# TODO: find better name for :all_digits (:preserve_precision, :mantain_precision, ...) ?
# TODO: should the context determine the mode for cross-base literal-to-Num conversion (:free, :fixed)?
#           BinNum.context.input = :fixed; x = BinNum('0.1')
#++

require 'flt/support'
require 'flt/support/flag_values'
require 'flt/support/reader'
require 'flt/support/formatter'
require 'flt/support/rationalizer'

require 'bigdecimal'
require 'forwardable'
require 'rational'
require 'monitor'
require 'ostruct'

module Flt

# Generic radix arbitrary-precision, floating-point numbers. This is a base class for
# floating point types of specific radix.
#
# The implementation of floating-point arithmetic is largely based on the Decimal module of Python,
# written by Eric Price, Facundo Batista, Raymond Hettinger, Aahz and Tim Peters.
#
# =Notes on the representation of Flt::Num numbers.
#
# * @sign is +1 for plus and -1 for minus
# * @coeff is the integral significand stored as an integer (so leading zeros cannot be kept)
# * @exp is the exponent to be applied to @coeff as an integer or one of :inf, :nan, :snan for special values
#
# The value represented is @sign*@coeff*b**@exp with b = num_class.radix the radix for the the Num-derived class.
#
# The original Python Decimal representation has these slots:
# * _sign is 1 for minus, 0 for plus
# * _int is the integral significand as a string of digits (leading zeroes are not kept)
# * _exp is the exponent as an integer or 'F' for infinity, 'n' for NaN , 'N' for sNaN
# * _is_especial is true for special values (infinity, NaN, sNaN)
# An additional class _WorkRep is used in Python for non-special decimal values with:
# * sign
# * int (significand as an integer)
# * exp
#
# =Exponent values
#
# In GDAS (General Decimal Arithmetic Specification) numbers are represented by an unnormalized integral
# significand and an exponent (also called 'scale'.)
#
# The reduce operation (originally called 'normalize') removes trailing 0s and increments the exponent if necessary;
# the representation is rescaled to use the maximum exponent possible (while maintaining an integral significand.)
# So, a reduced number uses as few digits as possible to retain it's value; information about digit significance
# is lost.
#
# A classical floating-point normalize operation would remove leading 0s and decrement the exponent instead,
# rescaling to the minimum exponent that maintains the significand value under some conventional limit
# (1 for fractional normalization; the radix for scientific or adjusted normalization and the maximum
# integral significand with as many digits as determined by the context precision for integral normalization.)
# So, normalization is meaningful given some fixed limited precision, as given by the context precision in our case.
# Normalization uses all the available precision digits and loses information about digit significance too.
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
# The number of significant digits (excluding leading and trailing zeroes) is sr = a - re + 1 = s + e - re
# where re is the internal exponent of the reduced value.
#
# The normalized integral exponent is ei = e - (p - s) = a - p + 1
# where p is the fixed precision.
#
# The normalized fractional exponent is ef = e + s = a + 1
#
# For context c and a number x we have:
# * e == x.exponent == x.to_int_scale.last == x.integral_exponent
# * ei == c.normalized_integral_exponent(x) == c.normalize(x).exponent == c.to_normalized_int_scale(x).last
# * a == c.adjusted_exponent == c.scientific_exponent == c.logb(x).to_i == c.a
# * re == c.reduce(x).exponent.to_i == c.reduced_exponent # the first uses c because it rounds to it
# * s == x.number_of_digits == x.digits.size
# * sr == c.reduce(x).number_of_digits
# * p == c.precision
# * ne == x.fractional_exponent
#
# ==Example: 0.0120400
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
# A context defines the limits for adjusted (scientific) exponents, emin, emax, and equivalently,
# the limits for internal (integral) exponents, etiny, etop. The emin, emax are the limits of the exponent
# shown in scientific notation (except for subnormal numbers) and are use to define the context exponent
# limits. We have etiny == emin-p+1 and etop==emax-p+1 where p is the context precision.
#
# For a given context a number with an integral significand not exceeding the context precision in number of digits
# and with integral exponents e in the range:
#   etiny <= e <= etop
# is always valid.
# The adjusted exponent, a, of valid normal numbers within the context must verify:
#   emin <= a <= emax
# If the significand is normalized (uses the full precision of the context)
# the internal exponent cannot exceed etop. Significands with less digits than the context precision
# can have internal exponents greater than etop withoug causing overflow:
#  +DecNum(1,context.emax) == DecNum(10**(context.precision-1),context.etop)
# The maximum finite value, which has a normalized (full precision) significand has internal exponent e==etop.
# The minimum normal value and all adjusted subnormal values have e==etiny, but non-adjusted subnormal values
# can have e<etiny: +DecNum(10,context.etiny-1) == Decimal(1,context.etiny) == context.minimum_nonzero
# Subnormal numbers have adjusted exponents in the range: context.etiny <= a < context.emin
#
# =Interoperatibility with other numeric types
#
# For some numeric types implicit conversion to DecNum is defined through these methods:
# * DecNum#coerce() is used when a Decimal is the right hand of an operator
# and the left hand is another numeric type
# * DecNum#_bin_op() used internally to define binary operators and use the Ruby coerce protocol:
# if the right-hand operand is of known type it is converted with Decimal; otherwise use coerce
# * _convert() converts known types to Decimal with Decimal() or raises an exception.
# * DecNum() casts known types and text representations of numbers to Decimal using the constructor.
# * DecNum#initialize performs the actual type conversion
#
# The known or 'coercible' types for DecNum are initially Integer and Rational, but this can be extended to
# other types using define_conversion_from() in a Context object.
#
class Num < Numeric

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
    Flt::Support::Flags(EXCEPTIONS,*values)
  end

  # Base class for Context classes.
  #
  # Derived classes will implement Floating-Point contexts for the specific
  # floating-point types (DecNum, BinNum)
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
    # * :normalized : (true or false) normalizes all results
    #
    # See also the context constructor method Flt::Num.Context().
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
        @angle = :rad # angular units: :rad (radians) / :deg (degrees) / :grad (gradians)
        @normalized = false
      end
      assign options.first

    end

    # Evaluate a block under a context (set up the context as a local context)
    #
    # When we have a context object we can use this instead of using the context method of the
    # numeric class, e.g.:
    #   DecNum.context(context) { ... }
    # This saves verbosity, specially when numeric class is not fixed, in which case
    # we would have to write:
    #   context.num_class.context(context) { ... }
    # With this method, we simply write:
    #   context.eval { ... }
    def eval(&blk)
      # TODO: consider other names for this method; use ? apply ? local ? with ?
      num_class.context(self, &blk)
    end

    # Evalute a block under a context (set up the context as a local context) and inject the
    # context methods (math and otherwise) into the block scope.
    #
    # This allows the use of regular algebraic notations for math functions,
    # e.g. exp(x) instead of x.exp
    def math(*parameters, &blk)
      # TODO: consider renaming this to eval
      num_class.context(self) do
        if parameters.empty?
          num_class.context.instance_eval &blk
        else
          # needs instance_exe (available in Ruby 1.9, ActiveRecord; TODO: include implementation here)
          num_class.context.instance_exec *parameters, &blk
        end
      end
    end

    # This gives access to the numeric class (Flt::Num-derived) this context is for.
    def num_class
      @num_class
    end

    # Constructor for the associated numeric class
    def Num(*args)
      context = { context: self }
      if args.last.kind_of?(Hash)
        args = args[0...-1] + [ context.merge(args.last) ]
      else
        args << context
      end
      num_class.Num(*args)
    end

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

    attr_accessor :rounding, :emin, :emax, :flags, :traps, :ignored_flags, :capitals, :clamp, :angle, :normalized

    def normalized?
      normalized
    end

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
      @emin, @emax = [e, 1-e].sort
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
      @exact = false
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

    # Alters the contexts by assigning options from a Hash. See DecNum#new() for the valid options.
    def assign(options)
      if options
        @rounding = options[:rounding] unless options[:rounding].nil?
        @precision = options[:precision] unless options[:precision].nil?
        @traps = DecNum::Flags(options[:traps]) unless options[:traps].nil?
        @flags = DecNum::Flags(options[:flags]) unless options[:flags].nil?
        @ignored_flags = DecNum::Flags(options[:ignored_flags]) unless options[:ignored_flags].nil?
        if elimit=options[:elimit]
          @emin, @emax = [elimit, 1-elimit].sort
        end
        @emin = options[:emin] unless options[:emin].nil?
        @emax = options[:emax] unless options[:emax].nil?
        @capitals = options[:capitals ] unless options[:capitals ].nil?
        @clamp = options[:clamp] unless options[:clamp].nil?
        @exact = options[:exact] unless options[:exact].nil?
        @angle = options[:angle] unless options[:angle].nil?
        @normalized = options[:normalized] unless options[:normalized].nil?
        update_precision
        if options[:extra_precision] && !@exact
          @precision += options[:extra_precision]
        end
      end
      self
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
      @angle = other.angle
      @normalized = other.normalized
    end

    def dup
      self.class.new(self)
    end

    # Create a context as a copy of the current one with some options
    # changed.
    def [](options={})
      self.class.new self, options
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

    # Power. See DecNum#power()
    def power(x,y,modulo=nil)
      _convert(x).power(y,modulo,self)
    end

    # Returns the base 10 logarithm
    def log10(x)
      _convert(x).log10(self)
    end

    # Returns the base 2 logarithm
    def log2(x)
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

    # Ruby-style log function: arbitrary base logarithm which defaults to natural logarithm
    def log(x, base=nil)
      _convert(x).log(base, self)
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

    # Normalizes (changes quantum) so that the coefficient has precision digits, unless it is subnormal.
    # For surnormal numbers the Subnormal flag is raised an a subnormal is returned with the smallest
    # possible exponent.
    #
    # This is different from reduce GDAS function which was formerly called normalize, and corresponds
    # to the classic meaning of floating-point normalization.
    #
    # Note that the number is also rounded (precision is reduced) if it had more precision than the context.
    def normalize(x)
      _convert(x).normalize(self)
    end

    # Adjusted exponent of x returned as a DecNum value.
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

    # Compares like <=> but returns a DecNum value.
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
    # See also: DecNum#to_integral_value(), which does exactly the same as
    # this method except that it doesn't raise Inexact or Rounded.
    def to_integral_exact(x)
      _convert(x).to_integral_exact(self)
    end

    # Rounds to a nearby integerwithout raising inexact, rounded.
    #
    # See also: DecNum#to_integral_exact(), which does exactly the same as
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

    # Some singular DecNum values that depend on the context

    # Maximum finite number
    def maximum_finite(sign=+1)
      return exception(InvalidOperation, "Exact context maximum finite value") if exact?
      # equals Num(+1, 1, emax+1) - Num(+1, 1, etop)
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

    # This is the difference between 1 and the smallest DecNum
    # value greater than 1: (DecNum(1).next_plus - DecNum(1))
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
      when :half_even, :half_down
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
      instance_variables.map { |v| "  #{v}: #{instance_variable_get(v).inspect}"}.join("\n") +
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

    # Internal use: array of numeric types that be coerced to DecNum.
    def coercible_types
      @coercible_type_handlers.keys
    end

    # Internal use: array of numeric types that be coerced to DecNum, including DecNum
    def coercible_types_or_num
      [num_class] + coercible_types
    end

    # Internally used to convert numeric types to DecNum (or to an array [sign,coefficient,exponent])
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

    # Define a numerical conversion from type to DecNum.
    # The block that defines the conversion has two parameters: the value to be converted and the context and
    # must return either a DecNum or [sign,coefficient,exponent]
    def define_conversion_from(type, &blk)
      @coercible_type_handlers[type] = blk
    end

    # Define a numerical conversion from DecNum to type as an instance method of DecNum
    def define_conversion_to(type, &blk)
      @conversions[type] = blk
    end

    # Convert a DecNum x to other numerical type
    def convert_to(type, x)
      converter = @conversions[type]
      if converter.nil?
        raise TypeError, "Undefined conversion from DecNum to #{type}."
      elsif converter.is_a?(Symbol)
        x.send converter
      else
        converter.call(x)
      end
    end

    # Simply calls x.split; implemented to ease handling Float and BigDecimal as Nums withoug
    # having to add methods like split to those classes.
    def split(x)
      _convert(x).split
    end

    def to_int_scale(x)
      _convert(x).to_int_scale
    end

    def sign(x)
      _convert(x).sign
    end

    def coefficient(x)
      _convert(x).coefficient
    end

    def exponent(x)
      _convert(x).exponent
    end

    def nan?(x)
      _convert(x).nan?
    end

    def infinite?(x)
      _convert(x).infinite?
    end

    def special?(x)
      _convert(x).special?
    end

    def zero?(x)
      _convert(x).zero?
    end

    # Maximum number of base b digits that can be stored in a context floating point number
    # and then preserved when converted back to base b.
    #
    # To store a base b number in a floating point number and be able to get then back exactly
    # the number cannot have more than these significant digits.
    def representable_digits(b)
      unless exact?
        if b == radix
          precision
        else
          ((precision-1)*log(radix, b)).floor
        end
      end
    end

    # Mininum number of base b digits necessary to store any context floating point number
    # while being able to convert the digits back to the same exact context floating point number
    #
    # To convert any floating point number to base b and be able to round the result back to
    # the same floating point number, at least this many base b digits are needed.
    def necessary_digits(b)
      unless exact?
        if b == radix
          precision
        else
          (precision*log(radix, b)).ceil + 1
        end
      end
    end

    # A floating-point number with value zero and the specified sign
    def zero(sign = +1)
      num_class.zero(sign)
    end

    # A floating-point infinite number with the specified sign
    def infinity(sign = +1)
      num_class.infinity(sign)
    end

    # A floating-point NaN (not a number)
    def nan
      num_class.nan
    end

    # One half: 1/2
    def one_half
      num_class.one_half
    end

    # Exact conversion to Rational
    def to_r(x)
      x.to_r
    end

    # Approximate conversion to Rational within given tolerance
    def rationalize(x, tol = nil)
      x.rationalize(tol)
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
      if @exact || @precision == 0 || @precision == :exact
        quiet = (@exact == :quiet)
        @exact = true
        @precision = 0
        @traps << Inexact unless quiet
        @ignored_flags[Inexact] = false
      else
        @exact = false
        @traps[Inexact] = false
      end
    end

  end

  # Context constructor; if an options hash is passed, the options are
  # applied to the default context; if a Context is passed as the first
  # argument, it is used as the base instead of the default context.
  #
  # Note that this method should be called on concrete floating point types such as
  # Flt::DecNum and Flt::BinNum, and not in the abstract base class Flt::Num.
  #
  # See Flt::Num::ContextBase#new() for the valid options
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
  # * A Context object (of the same type)
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
  # If arguments are passed they are interpreted as in Num.define_context() and an altered copy
  # of the current context is returned.
  # If a block is given, this method is a synonym for Num.local_context().
  def self.context(*args, &blk)
    if blk
      # setup a local context
      local_context(*args, &blk)
    elsif args.empty?
      # return the current context
      ctxt = self._context
      self._context = ctxt = self::DefaultContext.dup if ctxt.nil?
      ctxt
    else
      # Return a modified copy of the current context
      if args.first.kind_of?(ContextBase)
        self.define_context(*args)
      else
        self.define_context(self.context, *args)
      end
    end
  end

  # Change the current context (thread-local).
  def self.context=(c)
    self._context = c.dup
  end

  # Modify the current context, e.g. DecNum.set_context(:precision=>10)
  def self.set_context(*args)
    self.context = define_context(*args)
  end

  # Defines a scope with a local context. A context can be passed which will be
  # set a the current context for the scope; also a hash can be passed with
  # options to apply to the local scope.
  # Changes done to the current context are reversed when the scope is exited.
  def self.local_context(*args)
    begin
      keep = self.context # use this so _context is initialized if necessary
      self.context = define_context(*args) # this dups the assigned context
      result = yield _context
    ensure
      # TODO: consider the convenience of copying the flags from DecNum.context to keep
      # This way a local context does not affect the settings of the previous context,
      # but flags are transferred.
      # (this could be done always or be controlled by some option)
      #   keep.flags = DecNum.context.flags
      # Another alternative to consider: logically or the flags:
      #   keep.flags ||= DecNum.context.flags # (this requires implementing || in Flags)
      self._context = keep
      result
    end
  end

  class <<self
    # This is the thread-local context storage low level interface
    protected
    def _context #:nodoc:
      # TODO: memoize the variable id
      Thread.current["Flt::#{self}.context"]
    end
    def _context=(c) #:nodoc:
      Thread.current["Flt::#{self}.context"] = c
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
    # A floating-point number with value zero and the specified sign
    def zero(sign=+1)
      new [sign, 0, 0]
    end

    # A floating-point infinite number with the specified sign
    def infinity(sign=+1)
      new [sign, 0, :inf]
    end

    # A floating-point NaN (not a number)
    def nan()
      new [+1, nil, :nan]
    end

    # One half: 1/2
    def one_half
      new '0.5'
    end

    def int_radix_power(n)
      self.radix**n
    end

    def int_mult_radix_power(x,n)
      n < 0 ? (x / self.radix**(-n)) : (x * self.radix**n)
    end

    def int_div_radix_power(x,n)
      n < 0 ? (x * self.radix**(-n) ) : (x / self.radix**n)
    end

    def math(*args, &blk)
      self.context.math(*args, &blk)
    end

  end

  # A floating point-number value can be defined by:
  # * A String containing a text representation of the number
  # * An Integer
  # * A Rational
  # * For binary floating point: a Float
  # * A Value of a type for which conversion is defined in the context.
  # * Another floating-point value of the same type.
  # * A sign, coefficient and exponent (either as separate arguments, as an array or as a Hash with symbolic keys),
  #   or a signed coefficient and an exponent.
  #   This is the internal representation of Num, as returned by Num#split.
  #   The sign is +1 for plus and -1 for minus; the coefficient and exponent are
  #   integers, except for special values which are defined by :inf, :nan or :snan for the exponent.
  #
  # An optional Context can be passed after the value-definint argument to override the current context
  # and options can be passed in a last hash argument; alternatively context options can be overriden
  # by options of the hash argument.
  #
  # When the number is defined by a numeric literal (a String), it can be followed by a symbol that specifies
  # the mode used to convert the literal to a floating-point value:
  # * :free is currently the default for all cases. The precision of the input literal (including trailing zeros)
  #   is preserved and the precision of the context is ignored.
  #   When the literal is in the same base as the floating-point radix, (which, by default, is the case for
  #   DecNum only), the literal is preserved exactly in floating-point.
  #   Otherwise, all significative digits that can be derived from the literal are generanted, significative
  #   meaning here that if the digit is changed and the value converted back to a literal of the same base and
  #   precision, the original literal will not be obtained.
  # * :short is a variation of :free in which only the minimun number of digits that are necessary to
  #   produce the original literal when the value is converted back with the same original precision;
  #   namely, given an input in base b1, its :short representation in base 2 is the shortest number in base b2
  #   such that when converted back to base b2 with the same precision that the input had, the result is identical
  #   to the input:
  #     short = Num[b2].new(input, :short, base: b1)
  #     Num[b1].context.precision = precision_of_inpu
  #     Num[b1].new(short.to_s(base: b2), :fixed, base: b2)) == Num[b1].new(input, :free, base: b1)
  # * :fixed will round and normalize the value to the precision specified by the context (normalize meaning
  #   that exaclty the number of digits specified by the precision will be generated, even if the original
  #   literal has fewer digits.) This may fail returning NaN (and raising Inexact) if the context precision is
  #   :exact, but not if the floating-point radix is a multiple of the input base.
  #
  # Options that can be passed for construction from literal:
  # * :base is the numeric base of the input, 10 by default.
  def initialize(*args)
    options = args.pop if args.last.is_a?(Hash)
    options ||= {}
    context = args.pop if args.size > 0 && (args.last.kind_of?(ContextBase) || args.last.nil?)
    context ||= options.delete(:context)
    mode = args.pop if args.last.is_a?(Symbol) && ![:inf, :nan, :snan].include?(args.last)
    args = args.first if args.size==1 && args.first.is_a?(Array)
    if args.empty? && !options.empty?
      args = [options.delete(:sign)||+1,
              options.delete(:coefficient) || 0,
              options.delete(:exponent) || 0]
    end
    mode ||= options.delete(:mode)
    base = options.delete(:base)
    context = options if context.nil? && !options.empty?
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
        m = _parser(arg, :base => base)
        if m.nil?
          @sign,@coeff,@exp = context.exception(ConversionSyntax, "Invalid literal for DecNum: #{arg.inspect}").split
          return
        end
        @sign = (m.sign == '-') ? -1 : +1
        if m.int || m.onlyfrac
          sign = @sign
          if m.int
            intpart = m.int
            fracpart = m.frac
          else
            intpart = ''
            fracpart = m.onlyfrac
          end
          fracpart ||= ''
          base = m.base
          exp = m.exp.to_i
          coeff = (intpart+fracpart).to_i(base)
          if m.exp_base && m.exp_base != base
            # The exponent uses a different base;
            # compute exponent in base; assume base = exp_base**k
            k = Math.log(base, m.exp_base).round
            exp -= fracpart.size*k
            base = m.exp_base
          else
            exp -= fracpart.size
          end

          if false
            # Old behaviour: use :fixed format when num_class.radix != base
            # Advantages:
            # * Behaviour similar to Float: BinFloat(txt) == Float(txt)
            mode ||= ((num_class.radix == base) ? :free : :fixed)
          else
            # New behaviour: the default is always :free
            # Advantages:
            # * Is coherent with construction of DecNum from decimal literal:
            #   preserve precision of the literal with independence of context.
            mode ||= :free
          end

          if mode == :free && base == num_class.radix
            # simple case, the job is already done
            #
            # :free mode with same base must not be handled by the Reader;
            # note that if we used the Reader for the same base case in :free mode,
            # an extra 'significative' digit would be added, because that digit
            # is significative in the sense that (under non-directed rounding,
            # and with the significance interpretation of Reader wit the all-digits option)
            # it's not free to take any value without affecting the value of
            # the other digits: e.g. input: '0.1', the result of :free
            # conversion with the Reader is '0.10' because de last digit is not free;
            # if it was 9 for example the actual value would round to '0.2' with the input
            # precision given here.
            #
            # On the other hand, :short, should be handled by the Reader even when
            # the input and output bases are the same because we want to find the shortest
            # number that can be converted back to the input with the same input precision.
          else
            rounding = context.rounding
            reader = Support::Reader.new(:mode=>mode)
            ans = reader.read(context, rounding, sign, coeff, exp, base)
            context.exception(Inexact,"Inexact decimal to radix #{num_class.radix} conversion") if !reader.exact?
            if !reader.exact? && context.exact?
              sign, coeff, exp =  num_class.nan.split
            else
              sign, coeff, exp = ans.split
            end
          end
          @sign, @coeff, @exp = sign, coeff, exp
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
    # Num is the general constructor that can be invoked on specific Flt::Num-derived classes.
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

  # Exponent corresponding to the integral significand with all trailing digits removed.
  # Does not use any context; equals the value of self.reduce.exponent (but as an integer rather than a Num)
  # except for special values and when the number is rounded under the context or exceeds its limits.
  def reduced_exponent
    if self.special? || self.zero?
      0
    else
      exp = self.exponent
      dgs = self.digits
      nd = dgs.size # self.number_of_digits
        while dgs[nd-1]==0
        exp += 1
        nd -= 1
      end
      exp
    end
  end

  # Normalizes (changes quantum) so that the coefficient has precision digits, unless it is subnormal.
  # For surnormal numbers the Subnormal flag is raised an a subnormal is returned with the smallest
  # possible exponent.
  #
  # This is different from reduce GDAS function which was formerly called normalize, and corresponds
  # to the classic meaning of floating-point normalization.
  #
  # Note that the number is also rounded (precision is reduced) if it had more precision than the context.
  def normalize(context=nil)
    context = define_context(context)
    return Num(self) if self.special? || self.zero? || context.exact?
    sign, coeff, exp = self._fix(context).split
    if self.subnormal?(context)
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
    Num(adjusted_exponent)._fix(context)
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

  # Naive implementation of exponential and logarithm functions; should be replaced
  # by something more efficient in specific Num classes.

  # Exponential function
  def exp(context=nil)
    context = num_class.define_context(context)

    # exp(NaN) = NaN
    ans = _check_nans(context)
    return ans if ans

    # exp(-Infinity) = 0
    return num_class.zero if self.infinite? && (self.sign == -1)

    # exp(0) = 1
    return Num(1) if self.zero?

    # exp(Infinity) = Infinity
    return Num(self) if self.infinite?

    # the result is now guaranteed to be inexact (the true
    # mathematical result is transcendental). There's no need to
    # raise Rounded and Inexact here---they'll always be raised as
    # a result of the call to _fix.
    return context.exception(Inexact, 'Inexact exp') if context.exact?
    p = context.precision
    adj = self.adjusted_exponent

    if self.sign == +1 and adj > _number_of_digits((context.emax+1)*3)
      # overflow
      ans = Num(+1, 1, context.emax+1)
    elsif self.sign == -1 and adj > _number_of_digits((-context.etiny+1)*3)
      # underflow to 0
      ans = Num(+1, 1, context.etiny-1)
    elsif self.sign == +1 and adj < -p
      # p+1 digits; final round will raise correct flags
      ans = Num(+1, num_clas.int_radix_power(p)+1, -p)
    elsif self.sign == -1 and adj < -p-1
      # p+1 digits; final round will raise correct flags
      ans = Num(+1, num_clas.int_radix_power(p+1)-1, -p-1)
    else
      # general case
      x_sign = self.sign
      x = self.copy_sign(+1)
      i, lasts, s, fact, num = 0, 0, 1, 1, 1
      elim = [context.emax, -context.emin, 10000].max
      xprec = num_class.radix==10 ? 3 : 4
      num_class.local_context(context, :extra_precision=>xprec, :rounding=>:half_even, :elimit=>elim) do
        while s != lasts
          lasts = s
          i += 1
          fact *= i
          num *= x
          s += num / fact
        end
        s = num_class.Num(1)/s if x_sign<0
      end
      ans = s
    end

    # at this stage, ans should round correctly with *any*
    # rounding mode, not just with ROUND_HALF_EVEN
    num_class.context(context, :rounding=>:half_even) do |local_context|
      ans = ans._fix(local_context)
      context.flags = local_context.flags
    end

    return ans
  end

  # Returns the natural (base e) logarithm
  def ln(context=nil)
    context = num_class.define_context(context)

    # ln(NaN) = NaN
    ans = _check_nans(context)
    return ans if ans

    # ln(0.0) == -Infinity
    return num_class.infinity(-1) if self.zero?

    # ln(Infinity) = Infinity
    return num_class.infinity if self.infinite? && self.sign == +1

    # ln(1.0) == 0.0
    return num_class.zero if self == Num(1)

    # ln(negative) raises InvalidOperation
    return context.exception(InvalidOperation, 'ln of a negative value') if self.sign==-1

    # result is irrational, so necessarily inexact
    return context.exception(Inexact, 'Inexact exp') if context.exact?

    elim = [context.emax, -context.emin, 10000].max
    xprec = num_class.radix==10 ? 3 : 4
    num_class.local_context(context, :extra_precision=>xprec, :rounding=>:half_even, :elimit=>elim) do

      one = num_class.Num(1)

      x = self
      if (expo = x.adjusted_exponent)<-1 || expo>=2
        x = x.scaleb(-expo)
      else
        expo = nil
      end

      x = (x-one)/(x+one)
      x2 = x*x
      ans = x
      d = ans
      i = one
      last_ans = nil
      while ans != last_ans
        last_ans = ans
        x = x2*x
        i += 2
        d = x/i
        ans += d
      end
      ans *= 2
      if expo
        ans += num_class.Num(num_class.radix).ln*expo
      end
    end

    num_class.context(context, :rounding=>:half_even) do |local_context|
      ans = ans._fix(local_context)
      context.flags = local_context.flags
    end
    return ans
  end

  # Ruby-style logarithm of arbitrary base, e (natural base) by default
  def log(b=nil, context=nil)
    if b.nil?
      self.ln(context)
    elsif b==10
      self.log10(context)
    elsif b==2
      self.log2(context)
    else
      context = num_class.define_context(context)
      +num_class.context(:extra_precision=>3){self.ln(context)/num_class[b].ln(context)}
    end
  end

  # Returns the base 10 logarithm
  def log10(context=nil)
    context = num_class.define_context(context)
    num_class.context(:extra_precision=>3){self.ln/num_class.Num(10).ln}
  end

  # Returns the base 2 logarithm
  def log2(context=nil)
    context = num_class.define_context(context)
    num_class.context(context, :extra_precision=>3){self.ln()/num_class.Num(2).ln}
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

  # Approximate conversion to Rational within given tolerance
  def rationalize(tol=nil)
    tol ||= Flt.Tolerance(Rational(1,2),:ulps)
    case tol
    when Integer
      Rational(*Support::Rationalizer.max_denominator(self, tol, num_class))
    else
      Rational(*Support::Rationalizer[tol].rationalize(self))
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
      # This is the ulp value for self.abs <= context.minimum_normal*num_class.context
      # Here we use it for self.abs < context.minimum_normal*num_class.context;
      #  because of the simple exponent check; the remaining cases are handled below.
      return context.minimum_nonzero
    else
      # The next can compute the ulp value for the values that
      #   self.abs > context.minimum_normal && self.abs <= context.maximum_finite
      # The cases self.abs < context.minimum_normal*num_class.context have been handled above.

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

  # For MRI this is unnecesary, but it is needed for Rubinius because of the coercion done in Numeric#< etc.
  def <=(other)
    (self<=>other) <= 0
  end
  def <(other)
    (self<=>other) < 0
  end
  def >=(other)
    (self<=>other) >= 0
  end
  def >(other)
    (self<=>other) > 0
  end

  include Comparable

  def hash
    ([num_class]+reduce.split).hash # TODO: optimize
  end

  def eql?(other)
    return false unless other.is_a?(num_class)
    reduce.split == other.reduce.split
  end

  # Compares like <=> but returns a Num value.
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

  # Synonym for Num#adjusted_exponent()
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

  # Integer part (as a Num)
  def integer_part
    ans = _check_nans
    return ans if ans
    return_as_num = {:places=>0}
    self.sign < 0 ? self.ceil(return_as_num) : self.floor(return_as_num)
  end

  # Fraction part (as a Num)
  def fraction_part
    ans = _check_nans
    return ans if ans
    self - self.integer_part
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
    sign = other.respond_to?(:sign) ? other.sign : ((other < 0) ? -1 : +1)
    Num(sign, @coeff, @exp)
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
  #   should be passed as a type convertible to Num.
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
  #   :rindex     7   6   5   4     3    2    1    0
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
      prec = adjusted_exponent + 1 - num_class.Num(v).adjusted_exponent
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
  # as Flt::Num#round()
  def ceil(opt={})
    opt[:rounding] = :ceiling
    round opt
  end

  # General floor operation (as for Float) with same options for precision
  # as Flt::Num#round()
  def floor(opt={})
    opt[:rounding] = :floor
    round opt
  end

  # General truncate operation (as for Float) with same options for precision
  # as Flt::Num#round()
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

  # Representation as text of a number: this is an alias of Num#format
  def to_s(*args)
    format *args
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
  # unbounded precision, but may be computed more efficiently.  It is
  # always exact.
  def power(other, modulo=nil, context=nil)
    if context.nil? && (modulo.kind_of?(ContextBase) || modulo.is_a?(Hash))
      context = modulo
      modulo = nil
    end

    context = num_class.define_context(context)
    other = _convert(other)

    ans = _check_nans(context, other)
    return ans if ans

    # 0**0 = NaN (!), x**0 = 1 for nonzero x (including +/-Infinity)
    if other.zero?
      if self.zero?
        return context.exception(InvalidOperation, '0 ** 0')
      else
        return Num(1)
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
      return (other.sign == +1) ? Num(result_sign, 0, 0) : num_class.infinity(result_sign)
    end

    # Inf**(+ve or Inf) = Inf; Inf**(-ve or -Inf) = 0
    if _self.infinite?
      return (other.sign == +1) ? num_class.infinity(result_sign) : Num(result_sign, 0, 0)
    end

    # 1**other = 1, but the choice of exponent and the flags
    # depend on the exponent of self, and on whether other is a
    # positive integer, a negative integer, or neither
    if _self == Num(1)
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

      return Num(result_sign, num_class.int_radix_power(-exp), exp)
    end

    # compute adjusted exponent of self
    self_adj = _self.adjusted_exponent

    # self ** infinity is infinity if self > 1, 0 if self < 1
    # self ** -infinity is infinity if self < 1, 0 if self > 1
    if other.infinite?
      if (other.sign == +1) == (self_adj < 0)
        return Num(result_sign, 0, 0)
      else
        return num_class.infinity(result_sign)
      end
    end

    # from here on, the result always goes through the call
    # to _fix at the end of this function.
    ans = nil

    # crude test to catch cases of extreme overflow/underflow.  If
    # log_radix(self)*other >= radix**bound and bound >= len(str(Emax))
    # then radixs**bound >= radix**len(str(Emax)) >= Emax+1 and hence
    # self**other >= radix**(Emax+1), so overflow occurs.  The test
    # for underflow is similar.
    bound = _self._log_radix_exp_bound + other.adjusted_exponent
    if (self_adj >= 0) == (other.sign == +1)
      # self > 1 and other +ve, or self < 1 and other -ve
      # possibility of overflow
      if bound >= _number_of_digits(context.emax)
        ans = Num(result_sign, 1, context.emax+1)
      end
    else
      # self > 1 and other -ve, or self < 1 and other +ve
      # possibility of underflow to 0
      etiny = context.etiny
      if bound >= _number_of_digits(-etiny)
        ans = Num(result_sign, 1, etiny-1)
      end
    end

    # try for an exact result with precision +1
    if ans.nil?
      if context.exact?
        if other.adjusted_exponent < 100 # ???? 4 ? ...
          test_precision = _self.number_of_digits*other.to_i+1
        else
          test_precision = _self.number_of_digits+1
        end
      else
        test_precision = context.precision + 1
      end
      ans = _self._power_exact(other, test_precision)
      if !ans.nil? && (result_sign == -1)
        ans = Num(-1, ans.coefficient, ans.exponent)
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
        coeff, exp = _power(xc, xe, yc, ye, p+extra)
        break if (coeff % (num_class.int_radix_power(_number_of_digits(coeff)-p)/2)) != 0 # base 2: (coeff % (10**(_number_of_digits(coeff)-p-1))) != 0
        extra += 3
      end
      ans = Num(result_sign, coeff, exp)
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
        ans = Num(ans.sign, num_class.int_mult_radix_power(ans.coefficient, expdiff), ans.exponent-expdiff)
      end
      context.exception Underflow if ans.adjusted_exponent < context.emin
    end

    ans = ans % modulo if modulo

    # unlike exp, ln and log10, the power function respects the
    # rounding mode; no need to use ROUND_HALF_EVEN here
    ans._fix(context)
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

    if context.normalized?
      exp = @exp
      coeff = @coeff
      if self_is_subnormal
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
      if exp != @exp || coeff != @coeff
        return Num(@sign, coeff, exp)
      end
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
          return num_class.Num([@sign, payload, @exp])
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

  # Internal method to allow format (and to_s) to admit legacy
  # parameters.
  def format_legacy_parameters(*args)
    eng = false
    context = nil

    # formerly the eng value and the context could be passed
    # as separate values in that order
    if [true,false].include?(args.first)
      eng = args.shift
    end
    if args.first.is_a?(Num::ContextBase)
      context = args.shift
    end

    # and the :eng symbol could be passed to enable it
    if args.first == :eng
      eng = true
      args.shift
    end

    if args.size > 1 || (args.size == 1 && !args.first.is_a?(Hash))
      raise TypeError, "Invalid arguments to #{num_class}#format"
    end

    # now all arguments should be passed in a hash
    options = args.first || {}
    { :eng => eng, :context => context }.merge(options)
  end
  private :format_legacy_parameters

  # Conversion to a text literal
  #
  # The base of the produced literal can be specified by the :base option,
  # which is 10 by default.
  #
  # ## Same base
  #
  # If the output base is the floating-point radix the actual internal value
  # of the number is produced, by default showing trailing zeros up to the
  # stored precision, e.g. 0.100.
  #
  # The :simplified option can be used in this case to remove the trailing
  # zeros, producing 0.1. The actual effect of this options is to regard
  # the number an *approximation* (see below) and show only as few digits
  # as possible while making sure that the result rounds back to the original
  # value (if rounded to its original precision).
  #
  # With the :all_digits option the number will be considered also an
  # approximation and all its 'significant' digits are shown. A digit
  # is considered significant here if when used on input, cannot
  # arbitrarily change its value and preserve the parsed value of the
  # floating point number (to the original precision).
  # In our case the result would be 0.1000, because the additional shown 0
  # is a digit that if changed arbitrarily could make the number round to
  # a different value from the original 0.100.
  #
  # ## Different bases
  #
  # For bases different from the radix, by default the floating-point number
  # is treated as an approximation and is redendered as if with the
  # :simplified option mention above.
  #
  # The :all_digits option acts as in the same-base case. Note that
  # aproximated values are formatted without introducing additional precision.
  #
  # The :exact options can be used to render the exact value in the output
  # base (by using Flt::Num.convert_exact)
  #
  # ## All available options:
  #
  # :base defines the output base, 10 by default. If the output base is defined
  # as :hex_bin, then the %A/%a format of printf is used, which shows the
  # significand as an hexadecimal number and the binary exponent in decimal.
  #
  # :exp_base allows to define a different base for the exponent
  # than for the coefficient, as occurs with the :hex_bin base; the base for the
  # coefficient must be a power of that of the exponent.
  #
  # :rounding is used to override the context rounding. It allows to
  # specify the :nearest as the rounding-mode, which means that the text
  # literal will have enough digits to be converted back to the original value
  # in any of the round-to-nearest rounding modes. Otherwise only enough
  # digits for conversion in a specific rounding mode are produced.
  #
  # :all_digits makes all 'significant' digits visible, considering
  # the number approximate as explained below.
  # Using :all_digits will show trailing zeros up to the precision of the
  # floating-point, so the output will preserve the input precision.
  # With :all_digits and the :down rounding-mode (truncation), the result will
  # be the exact value floating-point value in the output base
  # (if it is conmensurable with the floating-point radix).
  #
  # :simplify shows only the digits necessary to preserve the original value
  # (which is the default when output base differs from radix)
  #
  # :exact interprets the number as an exact value, not an approximation so
  # that the exact original value can be rendered in a different base.
  #
  # :format specifies the numeric format:
  #
  # * :sci selects scientific notation
  # * :fix selects fixed format (no exponent is shown)
  # * :eng is equivalent to :sci and setting the :eng option
  # * :auto selects :fix or :sci automatically (the default)
  #
  # ## Note: approximate vs exact values
  #
  # In order to represent a floating point value `x`, we can take
  # two approaches:
  #
  # * Consider it an *exact* value, namely:
  #   `x.sign*x.integral_significand*radix**x.integral_exponent`
  # * Consider it an *approximation* with its particular precision,
  #   that represents any value within its rounding range.
  #   The exact rounding range depends on the rounding mode used to create
  #   the floating point mode; in the case of nearest rounding it is the
  #   set of numbers that line closer to the floating point value than to
  #   any other floating point value.
  #
  def format(*args)
    options = format_legacy_parameters(*args)

    format_mode = options[:format] || :auto
    max_leading_zeros = 6

    num_context = options[:context]
    output_radix = options[:base] || 10
    output_exp_radix = options[:exp_base]
    if output_radix == :hex_bin
      output_radix = 16
      output_exp_radix = 2
      first_digit_1 = true
    end
    output_exp_radix ||= output_radix
    rounding = options[:rounding]
    all_digits = options[:all_digits]
    eng = options[:eng]
    if format_mode == :eng
      format_mode = :sci
      eng = true
    end
    output_rounding = options[:output_rounding]
    exact = options[:exact]
    simplified = options[:simplified]
    all_digits ||= output_rounding

    sgn = @sign<0 ? '-' : ''
    if special?
      if @exp==:inf
        return "#{sgn}Infinity"
      elsif @exp==:nan
        return "#{sgn}NaN#{@coeff}"
      else # exp==:snan
        return "#{sgn}sNaN#{@coeff}"
      end
    end

    context = define_context(num_context)
    inexact = true
    rounding ||= context.rounding
    output_rounding ||= rounding

    if output_radix != output_exp_radix
      k = Math.log(output_radix, output_exp_radix).round
      if output_radix != output_exp_radix**k
        raise "When different bases are used for the coefficient and exponent, the first must be a power of the second"
      end
    end

    if output_radix != num_class.radix && exact && !all_digits && !simplified
      value = Num[output_radix].context(exact: true){ Num.convert_exact(self, output_radix) }
      options = options.dup
      options.delete :context
      return value.format(options)
    end

    if output_exp_radix == num_class.radix && !all_digits && output_radix != output_exp_radix
      if first_digit_1
        # make the first digit a 1
        c = @coeff
        exp = integral_exponent
        nb = _nbits(c)
        r = (nb % k)
        d = (k + 1 - r) % k
        if d != 0
          c <<= d
          exp -= d
        end
      else
        c = @coeff
        exp = integral_exponent
      end
      ds = c.to_s(output_radix)
      n_ds = ds.size
      leftdigits = exp + n_ds
      exp_radix = num_class.radix
    elsif output_radix == num_class.radix && !all_digits && output_radix == output_exp_radix && !simplified
      # show exactly inner representation and precision
      ds = @coeff.to_s(output_radix)
      n_ds = ds.size
      exp = integral_exponent
      leftdigits = exp + n_ds
      exp_radix = num_class.radix
    else
      p = self.number_of_digits # context.precision
      formatter = Flt::Support::Formatter.new(num_class.radix, context.etiny, output_radix)
      formatter.format(self, @coeff, @exp, rounding, p, all_digits)
      dec_pos,digits = formatter.adjusted_digits(output_rounding)

      ds = digits.map{|d| d.to_s(output_radix)}.join
      n_ds = ds.size
      exp = dec_pos - n_ds
      leftdigits = dec_pos
      exp_radix = output_radix
    end

    ds = ds.upcase if context.capitals

    if output_exp_radix == 2 && output_radix == 16
      a_format = true
      digits_prefix = (context.capitals ? '0X' : '0x')
      exp_letter = (context.capitals ? 'P' : 'p')
      show_exp = true
    else
      a_format = false
      digits_prefix = ""
      exp_letter = (context.capitals ? 'E' : 'e')
      show_exp = false
    end

    if output_exp_radix != exp_radix
      # k = Math.log(exp_radix, output_exp_radix).round
      if leftdigits != 1
        exp += (ds.size - 1)
        leftdigits = 1
        dotplace = 1
      end
      exp *= k
    elsif a_format
      # k = Math.log(output_radix, output_exp_radix).round
      if leftdigits != 1
        exp += (ds.size - 1)*4
        leftdigits = 1
        dotplace = 1
        ds = ds[0...-1] while ds[-1,1] == '0' && ds.size>1
        n_ds = ds.size
      end
    else
      if format_mode == :auto
        fix = exp <= 0
        fix &&= leftdigits > -max_leading_zeros if max_leading_zeros
        if fix
          format_mode = :fix
        else
          format_mode = :sci
        end
      end
      if format_mode == :fix
        dotplace = leftdigits
      elsif !eng
        dotplace = 1
      elsif @coeff==0
        dotplace = (leftdigits+1)%3 - 1
      else
        dotplace = (leftdigits-1)%3 + 1
      end
      exp = leftdigits-dotplace
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

    if exp == 0 && !show_exp
      e = ''
    else
      e = exp_letter + "%+d"%(exp)
    end

    sgn + digits_prefix + intpart + fracpart + e
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

  # Compute a lower bound for the adjusted exponent of self.log10()
  # In other words, find r such that self.log10() >= 10**r.
  # Assumes that self is finite and positive and that self != 1.
  def _log_radix_exp_bound
    # For x >= radix or x < 1/radix we only need a bound on the integer
    # part of log_radix(self), and this comes directly from the
    # exponent of x.  For 1/radix <= x <= radix we use the inequalities
    # 1-1/x <= log(x) <= x-1. If x > 1 we have |log_radix(x)| >
    # (1-1/x)/k > 0.  If x < 1 then |log_radix(x)| > (1-x)/k > 0
    # with k = floor(log(radix)*radix**m)/radix**m (m = 3 for radix=10)
    #
    # The original Python cod used lexical order (having converted to strings) for (num < den) and (num < 231)
    # so the results would be different e.g. for num = 9; Can this happen? What is the correct way?

    adj = self.exponent + number_of_digits - 1
    return _number_of_digits(adj) - 1 if adj >= 1 # self >= radix
    return _number_of_digits(-1-adj)-1 if adj <= -2 # self < 1/radix

    k, m = {
      10 => [231, 3],
      2 => [89, 7]
    }[num_class.radix]
    raise InvalidOperation, "Base #{num_class.radix} not supported for _log_radix_exp_bound" if k.nil?

    c = self.coefficient
    e = self.exponent
    if adj == 0
      # 1 < self < 10
      num = (c - num_class.int_radix_power(-e))
      den = (k*c)
      return _number_of_digits(num) - _number_of_digits(den) - ((num < den) ? 1 : 0) + (m-1)
    end
    # adj == -1, 0.1 <= self < 1
    num = (num_class.int_radix_power(-e)-c)
    return _number_of_digits(num.to_i) + e - ((num < k) ? 1 : 0) - (m-2)
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
    while (xc % num_class.radix) == 0
      xc /= num_class.radix
      xe += 1
    end

    yc = other.coefficient
    ye = other.exponent
    while (yc % num_class.radix) == 0
      yc /= num_class.radix
      ye += 1
    end

    # case where xc == 1: result is 10**(xe*y), with xe*y
    # required to be an integer
    if xc == 1
      if ye >= 0
        exponent = xe*yc*num_class.int_radix_power(ye)
      else
        exponent, remainder = (xe*yc).divmod(num_class.int_radix_power(-ye))
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
      return Num(+1, num_class.int_radix_power(zeros), exponent-zeros)
    end

    # case where y is negative: xc must be either a power
    # of 2 or a power of 5.
    if other.sign == -1
      # TODO: detect powers of 2 or 5
      return nil
    end

    # now y is positive; find m and n such that y = m/n
    if ye >= 0
      m, n = num_class.int_mult_radix_power(yc,ye), 1
    else
      return nil if (xe != 0) and (_number_of_digits((yc*xe).abs) <= -ye)
      xc_bits = _nbits(xc)
      return nil if (xc != 1) and (_number_of_digits(yc.abs*xc_bits) <= -ye)
      m, n = yc, num_class.int_radix_power(-ye)
      while ((m % 2) == 0) && ((n % 2) == 0)
        m /= 2
        n /= 2
      end
      while ((m % 5) == 0) && ((n % 5) == 0)
        m /= 5
        n /= 5
      end
    end

    # compute nth root of xc*radix**xe
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

    # now xc*radix**xe is the nth root of the original xc*radix**xe
    # compute mth power of xc*radix**xe

    # if m > p*_log_radix_mult/_log_radix_lb(xc) then m > p/log_radix(xc),
    # hence xc**m > radix**p and the result is not representable.
    #return nil if (xc > 1) and (m > p*100/_log10_lb(xc))
    return nil if (xc > 1) and (m > p*_log_radix_mult/_log_radix_lb(xc))
    xc = xc**m
    xe *= m
    return nil if xc > num_class.int_radix_power(p)

    # by this point the result *is* exactly representable
    # adjust the exponent to get as close as possible to the ideal
    # exponent, if necessary
    if other.integral? && other.sign == +1
      ideal_exponent = self.exponent*other.to_i
      zeros = [xe-ideal_exponent, p-_number_of_digits(xc)].min
    else
      zeros = 0
    end
    return Num(+1, num_class.int_mult_radix_power(xc, zeros), xe-zeros)
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
    def _parser(txt, options={})
      base = options[:base]
      md = /^\s*([-+])?(?:(?:(\d+)(?:\.(\d*))?|\.(\d+))(?:E([-+]?\d+))?|Inf(?:inity)?|(s)?NaN(\d*))\s*$/i.match(txt)
      if md
        base ||= 10
        OpenStruct.new :sign=>md[1], :int=>md[2], :frac=>md[3], :onlyfrac=>md[4], :exp=>md[5],
                       :signal=>md[6], :diag=>md[7], :base=>base
      else
        md = /^\s*([-+])?0x(?:(?:([\da-f]+)(?:\.([\da-f]*))?|\.([\da-f]+))(?:P([-+]?\d+))?)\s*$/i.match(txt)
        if md
          base = 16
          OpenStruct.new :sign=>md[1], :int=>md[2], :frac=>md[3], :onlyfrac=>md[4], :exp=>md[5],
                         :signal=>nil, :diag=>nil, :base=>base, :exp_base=>2
        end
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

    # Given integers xc, xe, yc and ye representing Num x = xc*radix**xe and
    # y = yc*radix**ye, compute x**y.  Returns a pair of integers (c, e) such that:
    #
    #   radix**(p-1) <= c <= radix**p, and
    #   (c-1)*radix**e < x**y < (c+1)*radix**e
    #
    # in other words, c*radix**e is an approximation to x**y with p digits
    # of precision, and with an error in c of at most 1.  (This is
    # almost, but not quite, the same as the error being < 1ulp: when c
    # == radix**(p-1) we can only guarantee error < radix ulp.)
    #
    # We assume that: x is positive and not equal to 1, and y is nonzero.
    def _power(xc, xe, yc, ye, p)
      # Find b such that radix**(b-1) <= |y| <= radix**b
      b = _number_of_digits(yc.abs) + ye

      # log(x) = lxc*radix**(-p-b-1), to p+b+1 places after the decimal point
      lxc = _log(xc, xe, p+b+1)

      # compute product y*log(x) = yc*lxc*radix**(-p-b-1+ye) = pc*radix**(-p-1)
      shift = ye-b
      if shift >= 0
          pc = lxc*yc*num_class.int_radix_power(shift)
      else
          pc = _div_nearest(lxc*yc, num_class.int_radix_power(-shift))
      end

      if pc == 0
          # we prefer a result that isn't exactly 1; this makes it
          # easier to compute a correctly rounded result in __pow__
          if (_number_of_digits(xc) + xe >= 1) == (yc > 0) # if x**y > 1:
              coeff, exp = num_class.int_radix_power(p-1)+1, 1-p
          else
              coeff, exp = num_class.int_radix_power(p)-1, -p
          end
      else
          coeff, exp = _exp(pc, -(p+1), p+1)
          coeff = _div_nearest(coeff, num_class.radix)
          exp += 1
      end

      return coeff, exp
    end

    EXP_INC = 4
    # Compute an approximation to exp(c*radix**e), with p decimal places of precision.
    # Returns integers d, f such that:
    #
    #   radix**(p-1) <= d <= radix**p, and
    #   (d-1)*radix**f < exp(c*radix**e) < (d+1)*radix**f
    #
    # In other words, d*radix**f is an approximation to exp(c*radix**e) with p
    # digits of precision, and with an error in d of at most 1.  This is
    # almost, but not quite, the same as the error being < 1ulp: when d
    # = radix**(p-1) the error could be up to radix ulp.
    def _exp(c, e, p)
        # we'll call iexp with M = radix**(p+2), giving p+3 digits of precision
        p += EXP_INC

        # compute log(radix) with extra precision = adjusted exponent of c*radix**e
        # TODO: without the .abs tests fail because c is negative: c should not be negative!!
        extra = [0, e + _number_of_digits(c.abs) - 1].max
        q = p + extra

        # compute quotient c*radix**e/(log(radix)) = c*radix**(e+q)/(log(radix)*radix**q),
        # rounding down
        shift = e+q
        if shift >= 0
            cshift = c*num_class.int_radix_power(shift)
        else
            cshift = c/num_class.int_radix_power(-shift)
        end
        quot, rem = cshift.divmod(_log_radix_digits(q))

        # reduce remainder back to original precision
        rem = _div_nearest(rem, num_class.int_radix_power(extra))

        # for radix=10: error in result of _iexp < 120;  error after division < 0.62
        r = _div_nearest(_iexp(rem, num_class.int_radix_power(p)), num_class.int_radix_power(EXP_INC+1)), quot - p + (EXP_INC+1)
        return r
    end

    LOG_PREC_INC = 4
    # Given integers c, e and p with c > 0, compute an integer
    # approximation to radix**p * log(c*radix**e), with an absolute error of
    # at most 1.  Assumes that c*radix**e is not exactly 1.
    def _log(c, e, p)
        # Increase precision by 2. The precision increase is compensated
        # for at the end with a division
        p += LOG_PREC_INC

        # rewrite c*radix**e as d*radix**f with either f >= 0 and 1 <= d <= radix,
        # or f <= 0 and 1/radix <= d <= 1.  Then we can compute radix**p * log(c*radix**e)
        # as radix**p * log(d) + radix**p*f * log(radix).
        l = _number_of_digits(c)
        f = e+l - ((e+l >= 1) ? 1 : 0)

        # compute approximation to radix**p*log(d), with error < 27 for radix=10
        if p > 0
            k = e+p-f
            if k >= 0
                c *= num_class.int_radix_power(k)
            else
                c = _div_nearest(c, num_class.int_radix_power(-k))  # error of <= 0.5 in c for radix=10
            end

            # _ilog magnifies existing error in c by a factor of at most radix
            log_d = _ilog(c, num_class.int_radix_power(p)) # error < 5 + 22 = 27 for radix=10
        else
            # p <= 0: just approximate the whole thing by 0; error < 2.31 for radix=10
            log_d = 0
        end

        # compute approximation to f*radix**p*log(radix), with error < 11 for radix=10.
        if f
            extra = _number_of_digits(f.abs) - 1
            if p + extra >= 0
                # for radix=10:
                # error in f * _log10_digits(p+extra) < |f| * 1 = |f|
                # after division, error < |f|/10**extra + 0.5 < 10 + 0.5 < 11
                f_log_r = _div_nearest(f*_log_radix_digits(p+extra), num_class.int_radix_power(extra))
            else
                f_log_r = 0
            end
        else
            f_log_r = 0
        end

        # error in sum < 11+27 = 38; error after division < 0.38 + 0.5 < 1 for radix=10
        return _div_nearest(f_log_r + log_d, num_class.int_radix_power(LOG_PREC_INC)) # extra radix factor for base 2 ???
    end

    # Given integers x and M, M > 0, such that x/M is small in absolute
    # value, compute an integer approximation to M*exp(x/M).
    # For redix=10, and 0 <= x/M <= 2.4, the absolute error in the result is bounded by 60 (and
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
        t = -(-num_class.radix*_number_of_digits(m)/(3*l)).to_i
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

    # Integer approximation to M*log(x/M), with absolute error boundable
    # in terms only of x/M.
    #
    # Given positive integers x and M, return an integer approximation to
    # M * log(x/M).  For radix=10, L = 8 and 0.1 <= x/M <= 10 the difference
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
      t = -(-10*_number_of_digits(m)/(3*l)).to_i
      yshift = _rshift_nearest(y, r)
      w = _div_nearest(m, t)
      # (1...t).reverse_each do |k| # Ruby 1.9
      (1...t).to_a.reverse.each do |k|
         w = _div_nearest(m, k) - _div_nearest(yshift*w, m)
      end
      return _div_nearest(w*y, m)
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

    # Closest integer to a/b, a and b positive integers; rounds to even
    # in the case of a tie.
    def _div_nearest(a, b)
      q, r = a.divmod(b)
      q + (((2*r + (q&1)) > b) ? 1 : 0)
    end

    # We'll memoize the digits of log(10):
    @log_radix_digits = {
      # 10=>"23025850929940456840179914546843642076011014886",
      2=>""
    }
    class <<self
      attr_reader :log_radix_digits
    end
    LOG_RADIX_INC = 2
    LOG_RADIX_EXTRA = 3

    # Given an integer p >= 0, return floor(radix**p)*log(radix).
    def _log_radix_digits(p)
      # digits are stored as a string, for quick conversion to
      # integer in the case that we've already computed enough
      # digits; the stored digits should always bge correct
      # (truncated, not rounded to nearest).
      raise ArgumentError, "p should be nonnegative" if p<0
      stored_digits = (AuxiliarFunctions.log_radix_digits[num_class.radix] || "")
      if p >= stored_digits.length
          digits = nil
          # compute p+3, p+6, p+9, ... digits; continue until at
          # least one of the extra digits is nonzero
          extra = LOG_RADIX_EXTRA
          loop do
            # compute p+extra digits, correct to within 1ulp
            m = num_class.int_radix_power(p+extra+LOG_RADIX_INC)
            digits = _div_nearest(_ilog(num_class.radix*m, m), num_class.int_radix_power(LOG_RADIX_INC)).to_s(num_class.radix)
            break if digits[-extra..-1] != '0'*extra
            extra += LOG_RADIX_EXTRA
          end
          # if the radix < e (i.e. only for radix==2), we must prefix with a 0 because log(radix)<1
          # BUT THIS REDUCES PRECISION BY ONE? : may be avoid prefix and adjust scaling in the caller
          prefix = num_class.radix==2 ? '0' : ''
          # keep all reliable digits so far; remove trailing zeros
          # and next nonzero digit
          AuxiliarFunctions.log_radix_digits[num_class.radix] = prefix + digits.sub(/0*$/,'')[0...-1]
      end
      return (AuxiliarFunctions.log_radix_digits[num_class.radix][0..p]).to_i(num_class.radix)
    end

    LOG2_MULT = 100 # TODO: K=100? K=64? ...
    LOG2_LB_CORRECTION = [ # (1..15).map{|i| (LOG2_MULT*Math.log(16.0/i)/Math.log(2)).ceil}
      400, 300, 242, 200, 168, 142, 120, 100, 84, 68, 55, 42, 30, 20, 10
      # for LOG2_MULT=64: 256, 192, 155, 128, 108, 91, 77, 64, 54, 44, 35, 27, 20, 13, 6
    ]
    # Compute a lower bound for LOG2_MULT*log10(c) for a positive integer c.
    def log2_lb(c)
        raise ArgumentError, "The argument to _log2_lb should be nonnegative." if c <= 0
        str_c = c.to_s(16)
        return LOG2_MULT*4*str_c.length - LOG2_LB_CORRECTION[str_c[0,1].to_i(16)-1]
    end

    LOG10_MULT = 100
    LOG10_LB_CORRECTION = { # (1..9).map_hash{|i| LOG10_MULT - (LOG10_MULT*Math.log10(i)).floor}
      '1'=> 100, '2'=> 70, '3'=> 53, '4'=> 40, '5'=> 31,
      '6'=> 23, '7'=> 16, '8'=> 10, '9'=> 5
    }
    # Compute a lower bound for LOG10_MULT*log10(c) for a positive integer c.
    def log10_lb(c)
        raise ArgumentError, "The argument to _log10_lb should be nonnegative." if c <= 0
        str_c = c.to_s
        return LOG10_MULT*str_c.length - LOG10_LB_CORRECTION[str_c[0,1]]
    end

    def _log_radix_mult
      case num_class.radix
      when 10
        LOG10_MULT
      when 2
        LOG2_MULT
      else
        raise ArgumentError, "_log_radix_mult not implemented for base #{num_class.radix}"
      end
    end

    def _log_radix_lb(c)
      case num_class.radix
      when 10
        log10_lb(c)
      when 2
        log2_lb(c)
      else
        raise ArgumentError, "_log_radix_lb not implemented for base #{num_class.radix}"
      end
    end

    def _number_of_digits(v)
      _ndigits(v, num_class.radix)
    end

  end # AuxiliarFunctions

  include AuxiliarFunctions
  extend AuxiliarFunctions

  class <<self
    # Num[base] can be use to obtain a floating-point numeric class with radix base, so that, for example,
    # Num[2] is equivalent to BinNum and Num[10] to DecNum.
    #
    # If the base does not correspond to one of the predefined classes (DecNum, BinNum), a new class
    # is dynamically generated.
    #
    # The [] operator can also be applied to classes derived from Num to act as a constructor
    # (short hand for .new):
    #   Flt::Num[10]['0.1'] # same as FLt::DecNum['0.1'] or Flt.DecNum('0.1') or Flt::DecNum.new('0.1')
    def [](*args)
      return self.Num(*args) if self!=Num # && self.ancestors.include?(Num)
      raise RuntimeError, "Invalid number of arguments (#{args.size}) for Num.[]; 1 expected." unless args.size==1
      base = args.first

      case base
      when 10
        DecNum
      when 2
        BinNum
      else
        class_name = "Base#{base}Num"
        unless Flt.const_defined?(class_name)
          cls = Flt.const_set class_name, Class.new(Num) {
            def initialize(*args)
              super(*args)
            end
          }
          meta_cls = class <<cls;self;end
          meta_cls.send :define_method, :radix do
            base
          end

          cls.const_set :Context, Class.new(Num::ContextBase)
          cls::Context.send :define_method, :initialize do |*options|
            super(cls, *options)
          end

          default_digits = 10
          default_elimit = 100

          cls.const_set :DefaultContext, cls::Context.new(
            :exact=>false, :precision=>default_digits, :rounding=>:half_even,
            :elimit=>default_elimit,
            :flags=>[],
            :traps=>[DivisionByZero, Overflow, InvalidOperation],
            :ignored_flags=>[],
            :capitals=>true,
            :clamp=>true,
            :angle=>:rad
          )

        end
        Flt.const_get class_name

      end
    end
  end

  # Exact base conversion: preserve x value.
  #
  # Convert x to a Flt::Num of the specified base or class
  # If the dest_context is exact, this may raise the Inexact flag (and return NaN), for some cases
  # (e.g. converting DecNum('0.1') to BinNum)
  #
  # The current destination context (overriden by dest_context) determines the valid range and the precision
  # (if its is not :exact the result will be rounded)
  def self.convert_exact(x, dest_base_or_class, dest_context=nil)
    num_class = dest_base_or_class.is_a?(Integer) ? Num[dest_base_or_class] :  dest_base_or_class
    if x.special?
      if x.nan?
        num_class.nan
      else # x.infinite?
        num_class.infinity(x.sign)
      end
    elsif x.zero?
      num_class.zero(x.sign)
    else
      if dest_base_or_class == Float
        float = true
        num_class = BinNum
        dest_context = BinNum::FloatContext
      end
      y = num_class.context(dest_context) do
        sign, coeff, exp = x.split
        y = num_class.Num(sign*coeff)
        if exp < 0
          y /= x.num_class.int_radix_power(-exp)
        else
          y *= x.num_class.int_radix_power(exp)
        end
        # y.reduce
      end
      y = y.to_f if float
      y
    end
  end

  # Approximate base conversion.
  #
  # Convert x to another Flt::Num class, so that if the result is converted to back to
  # the original class with the same precision and rounding mode, the value is preserved,
  # but use as few decimal digits as possible.
  #
  # Optional parameters: a context and/or an options hash can be passed.
  #
  # The context should be a context for the type of x, and is used to specified the precision and rounding mode
  # requiered to restore the original value from the converted value.
  #
  # The options are:
  # * :rounding used to specify the rounding required for back conversion with precedence over the context;
  #   the value :nearest means any round-to-nearest.
  # * :all_digits to preserve the input precision by using all significant digits in the output, not
  #   just the minimum required
  # * :minimum_precision to specify a minimum for the precision
  #
  # To increment the result number of digits x can be normalized or its precision (quantum) changed,
  # or use the :minimum_precision option.
  def self.convert(x, dest_base_or_class, *args)
    origin_context = args.shift if args.first.is_a?(ContextBase)
    raise ArgumentError,"Invalid parameters for Num.convert" unless args.size<=1 && (args.empty? || args.first.is_a?(Hash))
    options = args.first || {}

    rounding = options[:rounding]
    all_digits = options[:all_digits] # :all_digits ? :shortest/:significative
    minimum_precision = options[:minimum_precision]

    num_class = dest_base_or_class.is_a?(Integer) ? Num[dest_base_or_class] :  dest_base_or_class
    if x.special?
      if x.nan?
        num_class.nan
      else # x.infinite?
        num_class.infinite(x.sign)
      end
    elsif x.zero?
      num_class.zero(x.sign)
    else
      context = x.num_class.define_context(origin_context)

      p = x.number_of_digits
      p = minimum_precision if minimum_precision && p<minimum_precision
      s,f,e = x.split
      rounding ||= context.rounding unless
      formatter = Flt::Support::Formatter.new(x.num_class.radix, num_class.context.etiny, num_class.radix)
      formatter.format(x, f, e, rounding, p, all_digits)
      dec_pos,digits = formatter.adjusted_digits(rounding)

      # f = digits.map{|d| d.to_s(num_class.radix)}.join.to_i(num_class.radix)
      f = digits.inject(0){|a,b| a*num_class.radix + b}
      e = dec_pos - digits.size
      num_class.Num(s, f, e)
    end
  end

end # Num

end # Flt
