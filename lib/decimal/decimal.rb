require 'bigdecimal'
require 'forwardable'
require 'rational'
require 'monitor'
require 'ostruct'

# Decimal arbitrary precision floating point number.
# This implementation of Decimal is based on the Decimal module of Python,
# written by Eric Price, Facundo Batista, Raymond Hettinger, Aahz and Tim Peters.
class Decimal

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
  @base_coercible_types = {
    Integer=>lambda{|x, context| x>=0 ? [+1,x,0] : [-1,-x,0]},
    Rational=>lambda{|x, context|
      x, y = Decimal.new(x.numerator), Decimal.new(x.denominator)
      x.divide(y, context)
    }
  }
  @base_conversions = {
    Integer=>:to_i, Rational=>:to_r, Float=>:to_f
  }
  class <<self
    attr_reader :base_coercible_types
    attr_reader :base_conversions
  end

  # Numerical base of Decimal.
  def self.radix
    10
  end

  # Integral power of the base: radix**n for integer n; returns an integer.
  def self.int_radix_power(n)
    10**n
  end

  # Multiply by an integral power of the base: x*(radix**n) for x,n integer;
  # returns an integer.
  def self.int_mult_radix_power(x,n)
    x * (10**n)
  end

  # Divide by an integral power of the base: x/(radix**n) for x,n integer;
  # returns an integer.
  def self.int_div_radix_power(x,n)
    x / (10**n)
  end


  # Base class for errors
  class Error < StandardError
  end

  # All exception conditions derive from this class.
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
      super
    end
  end

  class DivisionByZero < Exception
    def self.handle(context,sign,*args)
      Decimal.infinity(sign)
    end
    def initialize(context=nil, sign=nil, *args)
      @sign = sign
      super
    end
  end

  class DivisionImpossible < Exception
    def self.handle(context,*args)
      Decimal.nan
    end
  end

  class DivisionUndefined < Exception
    def self.handle(context,*args)
      Decimal.nan
    end
  end

  class Inexact < Exception
  end

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
      super
    end
  end

  class Underflow < Exception
  end

  # Clamped exception: exponent changed to fit bounds.
  class Clamped < Exception
  end

  class InvalidContext < Exception
    def self.handle(context,*args)
      Decimal.nan
    end
  end

  class Rounded < Exception
  end

  class Subnormal < Exception
  end

  class ConversionSyntax < InvalidOperation
    def self.handle(context, *args)
      Decimal.nan
    end
  end



  #EXCEPTIONS = FlagValues(Clamped, InvalidOperation, DivisionByZero, Inexact, Overflow, Underflow, Rounded, Subnormal)
  EXCEPTIONS = FlagValues(Clamped, InvalidOperation, DivisionByZero, Inexact, Overflow, Underflow, Rounded, Subnormal, DivisionImpossible, ConversionSyntax)

  def self.Flags(*values)
    DecimalSupport::Flags(EXCEPTIONS,*values)
  end


  # The context defines the arithmetic context: rounding mode, precision,...
  # Decimal.context is the current (thread-local) context.
  class Context

    def initialize(*options)

      if options.first.instance_of?(Context)
        base = options.shift
        copy_from base
      else
        @ignored_flags = Decimal::Flags()
        @traps = Decimal::Flags()
        @flags = Decimal::Flags()
        @coercible_type_handlers = Decimal.base_coercible_types.dup
        @conversions = Decimal.base_conversions.dup
      end
      assign options.first

    end

    attr_accessor :rounding, :emin, :emax, :flags, :traps, :ignored_flags, :capitals, :clamp

    def ignore_all_flags
      #@ignored_flags << EXCEPTIONS
      @ignored_flags.set!
    end
    def ignore_flags(*flags)
      #@ignored_flags << flags
      @ignored_flags.set(*flags)
    end
    def regard_flags(*flags)
      @ignored_flags.clear(*flags)
    end

    def etiny
      emin - precision + 1
    end
    def etop
      emax - precision + 1
    end

    def digits
      self.precision
    end
    def digits=(n)
      self.precision=n
    end
    def prec
      self.precision
    end
    def prec=(n)
      self.precision = n
    end
    def clamp?
      @clamp
    end
    def precision=(n)
      @precision = n
      @exact = false unless n==0
      update_precision
      n
    end
    def precision
      @precision
    end
    def exact=(v)
      @exact = v
      update_precision
      v
    end
    def exact
      @exact
    end
    def exact?
      @exact
    end

    def assign(options)
      if options
        @rounding = options[:rounding] unless options[:rounding].nil?
        @precision = options[:precision] unless options[:precision].nil?
        @traps = Decimal::Flags(options[:traps]) unless options[:traps].nil?
        @flags = Decimal::Flags(options[:flags]) unless options[:flags].nil?
        @ignored_flags = Decimal::Flags(options[:ignored_flags]) unless options[:ignored_flags].nil?
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

    def copy_from(other)
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
      Context.new(self)
    end

    CONDITION_MAP = {
      #ConversionSyntax=>InvalidOperation,
      #DivisionImpossible=>InvalidOperation,
      DivisionUndefined=>InvalidOperation,
      InvalidContext=>InvalidOperation
    }

    def exception(cond, msg='', *params)
      err = (CONDITION_MAP[cond] || cond)
      return err.handle(self, *params) if @ignored_flags[err]
      @flags << err # @flags[err] = true
      return cond.handle(self, *params) if !@traps[err]
      raise err.new(*params), msg
    end

    def add(x,y)
      Decimal._convert(x).add(y,self)
    end
    def subtract(x,y)
      Decimal._convert(x).subtract(y,self)
    end
    def multiply(x,y)
      Decimal._convert(x).multiply(y,self)
    end
    def divide(x,y)
      Decimal._convert(x).divide(y,self)
    end

    def abs(x)
      Decimal._convert(x).abs(self)
    end

    def plus(x)
      Decimal._convert(x).plus(self)
    end

    def minus(x)
      Decimal._convert(x)._neg(self)
    end

    def to_string(x, eng=false)
      Decimal._convert(x)._fix(self).to_s(eng, self)
    end

    def to_sci_string(x)
      to_string x, false
    end

    def to_eng_string(x)
      to_string x, true
    end

    def reduce(x)
      Decimal._convert(x).reduce(self)
    end


    # Adjusted exponent of x returned as a Decimal value.
    def logb(x)
      Decimal._convert(x).logb(self)
    end

    # x*(radix**y) y must be an integer
    def scaleb(x, y)
      Decimal._convert(x).scaleb(y,self)
    end


    # Exponent in relation to the significand as an integer
    # normalized to precision digits. (minimum exponent)
    def normalized_integral_exponent(x)
      x = Decimal._convert(x)
      x.integral_exponent - (precision - x.number_of_digits)
    end

    # Significand normalized to precision digits
    # x == normalized_integral_significand(x) * radix**(normalized_integral_exponent)
    def normalized_integral_significand(x)
      x = Decimal._convert(x)
      x.integral_significand*(Decimal.int_radix_power(precision - x.number_of_digits))
    end

    def to_normalized_int_scale(x)
      x = Decimal._convert(x)
      [x.sign*normalized_integral_significand(x), normalized_integral_exponent(x)]
    end


    # TO DO:
    # Ruby-style:
    #  ** power
    # GDAS
    #  power
    #  exp log10 ln

    def normal?(x)
      Decimal._convert(x).normal?(self)
    end

    def subnormal?(x)
      Decimal._convert(x).subnormal?(self)
    end

    def number_class(x)
      Decimal._convert(x).number_class(self)
    end

    def sqrt(x)
      Decimal._convert(x).sqrt(self)
    end

    # Ruby-style integer division: (x/y).floor
    def div(x,y)
      Decimal._convert(x).div(y,self)
    end
    # Ruby-style modulo: x - y*div(x,y)
    def modulo(x,y)
      Decimal._convert(x).modulo(y,self)
    end
    # Ruby-style integer division and modulo: (x/y).floor, x - y*(x/y).floor
    def divmod(x,y)
      Decimal._convert(x).divmod(y,self)
    end

    # General Decimal Arithmetic Specification integer division: (x/y).truncate
    def divide_int(x,y)
      Decimal._convert(x).divide_int(y,self)
    end
    # General Decimal Arithmetic Specification remainder: x - y*divide_int(x,y)
    def remainder(x,y)
      Decimal._convert(x).remainder(y,self)
    end
    # General Decimal Arithmetic Specification remainder-near
    #  x - y*round_half_even(x/y)
    def remainder_near(x,y)
      Decimal._convert(x).remainder_near(y,self)
    end
    # General Decimal Arithmetic Specification integer division and remainder:
    #  (x/y).truncate, x - y*(x/y).truncate
    def divrem(x,y)
      Decimal._convert(x).divrem(y,self)
    end

    def fma(x,y,z)
      Decimal._convert(x).fma(y,z,self)
    end

    def compare(x,y)
      Decimal._convert(x).compare(y, self)
    end


    def copy_abs(x)
      Decimal._convert(x).copy_abs
    end

    def copy_negate(x)
      Decimal._convert(x).copy_negate
    end

    def copy_sign(x,y)
      Decimal._convert(x).copy_sign(y)
    end

    def rescale(x, exp, watch_exp=true)
      Decimal._convert(x).rescale(exp, self, watch_exp)
    end

    def quantize(x, y, watch_exp=true)
      Decimal._convert(x).quantize(y, self, watch_exp)
    end

    def same_quantum?(x,y)
      Decimal._convert(x).same_quantum?(y)
    end

    def to_integral_exact(x)
      Decimal._convert(x).to_integral_exact(self)
    end

    def to_integral_value(x)
      Decimal._convert(x).to_integral_value(self)
    end

    def next_minus(x)
      Decimal._convert(x).next_minus(self)
    end

    def next_plus(x)
      Decimal._convert(x).next_plus(self)
    end

    def next_toward(x, y)
      Decimal._convert(x).next_toward(y, self)
    end

    def to_s
      inspect
    end
    def inspect
      "<#{self.class}:\n" +
      instance_variables.map { |v| "  #{v}: #{eval(v)}"}.join("\n") +
      ">\n"
    end

    def maximum_significand
      if exact?
        exception(InvalidOperation, 'Exact maximum significand')
        nil
      else
        Decimal.int_radix_power(precision)-1
      end
    end

    def maximum_nan_diagnostic_digits
      if exact?
        nil # ?
      else
        precision - (clamp ? 1 : 0)
      end
    end

    def coercible_types
      @coercible_type_handlers.keys
    end
    def coercible_types_or_decimal
      [Decimal] + coercible_types
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
    def update_precision
      if @exact || @precision==0
        @exact = true
        @precision = 0
        @traps << Inexact
        @ignored_flags[Inexact] = false
      else
        @traps[Inexact] = false
      end
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

  # Context constructor; if an options hash is passed, the options are
  # applied to the default context; if a Context is passed as the first
  # argument, it is used as the base instead of the default context.
  def Decimal.Context(*args)
    case args.size
      when 0
        base = DefaultContext
      when 1
        arg = args.first
        if arg.instance_of?(Context)
          base = arg
          options = nil
        elsif arg.instance_of?(Hash)
          base = DefaultContext
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
      Context.new(base, options)
    end

  end

  # Define a context by passing either of:
  # * A Context object
  # * A hash of options (or nothing) to alter a copy of the current context.
  # * A Context object and a hash of options to alter a copy of it
  def Decimal.define_context(*options)
    context = options.shift if options.first.instance_of?(Context)
    if context && options.empty?
      context
    else
      context ||= Decimal.context
      Context(context, *options)
    end
  end

  # The current context (thread-local).
  def Decimal.context
    Thread.current['Decimal.context'] ||= DefaultContext.dup
  end

  # Change the current context (thread-local).
  def Decimal.context=(c)
    Thread.current['Decimal.context'] = c.dup
  end

  # Defines a scope with a local context. A context can be passed which will be
  # set a the current context for the scope; also a hash can be passed with
  # options to apply to the local scope.
  # Changes done to the current context are reversed when the scope is exited.
  def Decimal.local_context(*args)
    keep = context.dup
    Decimal.context = define_context(*args)
    result = yield Decimal.context
    Decimal.context = keep
    result
  end

  def Decimal.zero(sign=+1)
    Decimal.new([sign, 0, 0])
  end
  def Decimal.infinity(sign=+1)
    Decimal.new([sign, 0, :inf])
  end
  def Decimal.nan()
    Decimal.new([+1, nil, :nan])
  end

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
  # =Interoperatibility with other numeric types
  #
  # For some numeric types implicit conversion to Decimal is defined through these methods:
  # * Decimal#coerce() is used when a Decimal is the right hand of an operator
  #   and the left hand is another numeric type
  # * Decimal#_bin_op() used internally to define binary operators and use the Ruby coerce protocol:
  #   if the right-hand operand is of known type it is converted with Decimal; otherwise use coerce
  # * Decimal._convert() converts known types to Decimal with Decimal() or raises an exception.
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
    context = nil
    if args.size>0 && args.last.instance_of?(Context)
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

    context = Decimal.define_context(context)

    case args.size
    when 3
      @sign, @coeff, @exp = args
      # TO DO: validate

    when 1
      arg = args.first
      case arg

      when Decimal
        @sign, @coeff, @exp = arg.split

      when *context.coercible_types
        v = context._coerce(arg)
        @sign, @coeff, @exp = v.is_a?(Decimal) ? v.split : v

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
          @exp = m.exp.to_i
          if fracpart
            @coeff = (intpart+fracpart).to_i
            @exp -= fracpart.size
          else
            @coeff = intpart.to_i
          end
        else
          if m.diag
            # NaN
            @coeff = (m.diag.nil? || m.diag.empty?) ? nil : m.diag.to_i
            @coeff = nil if @coeff==0
             if @coeff
               max_diag_len = context.maximum_nan_diagnostic_digits
               if max_diag_len && @coeff >= Decimal.int_radix_power(max_diag_len)
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
      when Array
        @sign, @coeff, @exp = arg
      else
        raise TypeError, "invalid argument #{arg.inspect}"
      end
    else
      raise ArgumentError, "wrong number of arguments (#{args.size} for 1 or 3)"
    end
  end

  # Returns the internal representation of the number, composed of:
  # * a sign which is +1 for plus and -1 for minus
  # * a coefficient (significand) which is an integer
  # * an exponent (an integer) or :inf, :nan or :snan for special values
  # The value of non-special numbers is sign*coefficient*10^exponent
  def split
    [@sign, @coeff, @exp]
  end

  def special?
    @exp.instance_of?(Symbol)
  end

  def nan?
    @exp==:nan || @exp==:snan
  end

  def qnan?
    @exp == :nan
  end

  def snan?
    @exp == :snan
  end

  def infinite?
    @exp == :inf
  end

  def finite?
    !special?
  end

  def zero?
    @coeff==0 && !special?
  end

  def nonzero?
    special? || @coeff>0
  end

  def subnormal?(context=nil)
    return false if special? || zero?
    context = Decimal.define_context(context)
    self.adjusted_exponent < context.emin
  end

  def normal?(context=nil)
    return true if special? || zero?
    context = Decimal.define_context(context)
    (context.emin <= self.adjusted_exponent) &&  (self.adjusted_exponent <= context.emax)
  end

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
    context = Decimal.define_context(context)
    if subnormal?(context)
      return '+Subnormal' if @sign==+1
      return '-Subnormal' # if @sign==-1
    end
    return '+Normal' if @sign==+1
    return '-Normal' if @sign==-1
  end

  def coerce(other)
    case other
      when *Decimal.context.coercible_types_or_decimal
        [Decimal(other),self]
      else
        super
    end
  end

  def _bin_op(op, meth, other, context=nil)
    context = Decimal.define_context(context)
    case other
      when *context.coercible_types_or_decimal
        self.send meth, Decimal(other, context), context
      else
        x, y = other.coerce(self)
        x.send op, y
    end
  end
  private :_bin_op

  def -@(context=nil)
    #(context || Decimal.context).minus(self)
    _neg(context)
  end

  def +@(context=nil)
    #(context || Decimal.context).plus(self)
    _pos(context)
  end

  def +(other, context=nil)
    _bin_op :+, :add, other, context
  end

  def -(other, context=nil)
    _bin_op :-, :subtract, other, context
  end

  def *(other, context=nil)
    _bin_op :*, :multiply, other, context
  end

  def /(other, context=nil)
    _bin_op :/, :divide, other, context
  end

  def %(other, context=nil)
    _bin_op :%, :modulo, other, context
  end


  def add(other, context=nil)

    context = Decimal.define_context(context)
    other = Decimal._convert(other)

    if self.special? || other.special?
      ans = _check_nans(context,other)
      return ans if ans

      if self.infinite?
        if self.sign != other.sign && other.infinite?
          return context.exception(InvalidOperation, '-INF + INF')
        end
        return Decimal(self)
      end

      return Decimal(other) if other.infinite?
    end

    exp = [self.integral_exponent, other.integral_exponent].min
    negativezero = (context.rounding == ROUND_FLOOR && self.sign != other.sign)

    if self.zero? && other.zero?
      sign = [self.sign, other.sign].max
      sign = -1 if negativezero
      ans = Decimal.new([sign, 0, exp])._fix(context)
      return ans
    end

    if self.zero?
      exp = [exp, other.integral_exponent - context.precision - 1].max unless context.exact?
      return other._rescale(exp, context.rounding)._fix(context)
    end

    if other.zero?
      exp = [exp, self.integral_exponent - context.precision - 1].max unless context.exact?
      return self._rescale(exp, context.rounding)._fix(context)
    end

    op1, op2 = Decimal._normalize(self, other, context.precision)

    result_sign = result_coeff = result_exp = nil
    if op1.sign != op2.sign
      return ans = Decimal.new([negativezero ? -1 : +1, 0, exp])._fix(context) if op1.integral_significand == op2.integral_significand
      op1,op2 = op2,op1 if op1.integral_significand < op2.integral_significand
      result_sign = op1.sign
      op1,op2 = op1.copy_negate, op2.copy_negate if result_sign < 0
    elsif op1.sign < 0
      result_sign = -1
      op1,op2 = op1.copy_negate, op2.copy_negate
    else
      result_sign = +1
    end

    #puts "op1=#{op1.inspect} op2=#{op2.inspect}"


    if op2.sign == +1
      result_coeff = op1.integral_significand + op2.integral_significand
    else
      result_coeff = op1.integral_significand - op2.integral_significand
    end

    result_exp = op1.integral_exponent

    #puts "->#{Decimal([result_sign, result_coeff, result_exp]).inspect}"

    return Decimal([result_sign, result_coeff, result_exp])._fix(context)

  end


  def subtract(other, context=nil)

    context = Decimal.define_context(context)
    other = Decimal._convert(other)

    if self.special? || other.special?
      ans = _check_nans(context,other)
      return ans if ans
    end
    return add(other.copy_negate, context)
  end


  def multiply(other, context=nil)
    context = Decimal.define_context(context)
    other = Decimal._convert(other)
    resultsign = self.sign * other.sign
    if self.special? || other.special?
      ans = _check_nans(context,other)
      return ans if ans

      if self.infinite?
        return context.exception(InvalidOperation,"(+-)INF * 0") if other.zero?
        return Decimal.infinity(resultsign)
      end
      if other.infinite?
        return context.exception(InvalidOperation,"0 * (+-)INF") if self.zero?
        return Decimal.infinity(resultsign)
      end
    end

    resultexp = self.integral_exponent + other.integral_exponent

    return Decimal([resultsign, 0, resultexp])._fix(context) if self.zero? || other.zero?
    #return Decimal([resultsign, other.integral_significand, resultexp])._fix(context) if self.integral_significand==1
    #return Decimal([resultsign, self.integral_significand, resultexp])._fix(context) if other.integral_significand==1

    return Decimal([resultsign, other.integral_significand*self.integral_significand, resultexp])._fix(context)

  end

  def divide(other, context=nil)
    context = Decimal.define_context(context)
    other = Decimal._convert(other)
    resultsign = self.sign * other.sign
    if self.special? || other.special?
      ans = _check_nans(context,other)
      return ans if ans
      if self.infinite?
        return context.exception(InvalidOperation,"(+-)INF/(+-)INF") if other.infinite?
        return Decimal.infinity(resultsign)
      end
      if other.infinite?
        context.exception(Clamped,"Division by infinity")
        return Decimal.new([resultsign, 0, context.etiny])
      end
    end

    if other.zero?
      return context.exception(DivisionUndefined, '0 / 0') if self.zero?
      return context.exception(DivisionByZero, 'x / 0', resultsign)
    end

    if self.zero?
      exp = self.integral_exponent - other.integral_exponent
      coeff = 0
    else
      prec = context.exact? ? self.number_of_digits + 4*other.number_of_digits : context.precision # this assumes radix==10
      shift = other.number_of_digits - self.number_of_digits + prec + 1
      exp = self.integral_exponent - other.integral_exponent - shift
      if shift >= 0
        coeff, remainder = (self.integral_significand*Decimal.int_radix_power(shift)).divmod(other.integral_significand)
      else
        coeff, remainder = self.integral_significand.divmod(other.integral_significand*Decimal.int_radix_power(-shift))
      end
      if remainder != 0
        return context.exception(Inexact) if context.exact?
        coeff += 1 if (coeff%(Decimal.radix/2)) == 0
      else
        ideal_exp = self.integral_exponent - other.integral_exponent
        while (exp < ideal_exp) && ((coeff % Decimal.radix)==0)
          coeff /= Decimal.radix
          exp += 1
        end
      end

    end
    return Decimal([resultsign, coeff, exp])._fix(context)

  end




  def abs(context=nil)
    if special?
      ans = _check_nans(context)
      return ans if ans
    end
    sign<0 ? _neg(context) : _pos(context)
  end

  def plus(context=nil)
    _pos(context)
  end

  def minus(context=nil)
    _neg(context)
  end

  # Largest representable number smaller than itself
  def next_minus(context=nil)
    context = Decimal.define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
      if infinite?
        return Decimal.new(self) if @sign == -1
        # @sign == +1
        if context.exact?
           return context.exception(InvalidOperation, 'Exact +INF next minus')
        else
          return Decimal.new(+1, context.maximum_significand, context.etop)
        end
      end
    end

    result = nil
    Decimal.local_context(context) do |local|
      local.rounding = :floor
      local.ignore_all_flags
      result = self._fix(local)
      if result == self
        result = self - Decimal(+1, 1, local.etiny-1)
      end
    end
    result
  end

  # Smallest representable number larger than itself
  def next_plus(context=nil)
    context = Decimal.define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
      if infinite?
        return Decimal.new(self) if @sign == +1
        # @sign == -1
        if context.exact?
           return context.exception(InvalidOperation, 'Exact -INF next plus')
        else
          return Decimal.new(-1, context.maximum_significand, context.etop)
        end
      end
    end

    result = nil
    Decimal.local_context(context) do |local|
      local.rounding = :ceiling
      local.ignore_all_flags
      result = self._fix(local)
      if result == self
        result = self + Decimal(+1, 1, local.etiny-1)
      end
    end
    result

  end

  # Returns the number closest to self, in the direction towards other.
  def next_toward(other, context=nil)
    context = Decimal.define_context(context)
    other = Decimal._convert(other)
    ans = _check_nans(context,other)
    return ans if ans

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

  def sqrt(context=nil)
    context = Decimal.define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
      return Decimal.new(self) if infinite? && @sign==+1
    end
    return Decimal.new([@sign, 0, @exp/2])._fix(context) if zero?
    return context.exception(InvalidOperation, 'sqrt(-x), x>0') if @sign<0
    prec = context.precision + 1
    e = (@exp >> 1)
    if (@exp & 1)!=0
      c = @coeff*Decimal.radix
      l = (number_of_digits >> 1) + 1
    else
      c = @coeff
      l = (number_of_digits+1) >> 1
    end
    shift = prec - l
    if shift >= 0
      c = Decimal.int_mult_radix_power(c, (shift<<1))
      exact = true
    else
      c, remainder = c.divmod(Decimal.int_radix_power((-shift)<<1))
      exact = (remainder==0)
    end
    e -= shift

    n = Decimal.int_radix_power(prec)
    while true
      q = c / n
      break if n <= q
      n = ((n + q) >> 1)
    end
    exact = exact && (n*n == c)

    if exact
      if shift >= 0
        n = Decimal.int_div_radix_power(n, shift)
      else
        n = Decimal.int_mult_radix_power(n, -shift)
      end
      e += shift
    else
      return context.exception(Inexact) if context.exact?
      n += 1 if (n%5)==0
    end
    ans = Decimal.new([+1,n,e])
    Decimal.local_context(:rounding=>:half_even) do
      ans = ans._fix(context)
    end
    return ans
  end

  # General Decimal Arithmetic Specification integer division and remainder:
  #  (x/y).truncate, x - y*(x/y).truncate
  def divrem(other, context=nil)
    context = Decimal.define_context(context)
    other = Decimal._convert(other)

    ans = _check_nans(context,other)
    return [ans,ans] if ans

    sign = self.sign * other.sign

    if self.infinite?
      if other.infinite?
        ans = context.exception(InvalidOperation, 'divmod(INF,INF)')
        return [ans,ans]
      else
        return [Decimal.infinity(sign), context.exception(InvalidOperation, 'INF % x')]
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
    context = Decimal.define_context(context)
    other = Decimal._convert(other)

    ans = _check_nans(context,other)
    return [ans,ans] if ans

    sign = self.sign * other.sign

    if self.infinite?
      if other.infinite?
        ans = context.exception(InvalidOperation, 'divmod(INF,INF)')
        return [ans,ans]
      else
        return [Decimal.infinity(sign), context.exception(InvalidOperation, 'INF % x')]
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
    context = Decimal.define_context(context)
    other = Decimal._convert(other)

    ans = _check_nans(context,other)
    return ans if ans

    sign = self.sign * other.sign

    if self.infinite?
      return context.exception(InvalidOperation, 'INF // INF') if other.infinite?
      return Decimal.infinity(sign)
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
    context = Decimal.define_context(context)
    other = Decimal._convert(other)

    ans = _check_nans(context,other)
    return [ans,ans] if ans

    sign = self.sign * other.sign

    if self.infinite?
      return context.exception(InvalidOperation, 'INF // INF') if other.infinite?
      return Decimal.infinity(sign)
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
    context = Decimal.define_context(context)
    other = Decimal._convert(other)

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
    context = Decimal.define_context(context)
    other = Decimal._convert(other)

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
    context = Decimal.define_context(context)
    other = Decimal._convert(other)

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
      return Decimal.new(self)._fix(context)
    end

    ideal_exp = [self.integral_exponent, other.integral_exponent].min
    if self.zero?
      return Decimal([self.sign, 0, ideal_exp])._fix(context)
    end

    expdiff = self.adjusted_exponent - other.adjusted_exponent
    if (expdiff >= context.precision+1) && !context.exact?
      return context.exception(DivisionImpossible)
    elsif expdiff <= -2
      return self._rescale(ideal_exp, context.rounding)._fix(context)
    end

      self_coeff = self.integral_significand
      other_coeff = other.integral_significand
      de = self.integral_exponent - other.integral_exponent
      if de >= 0
        self_coeff = Decimal.int_mult_radix_power(self_coeff, de)
      else
        other_coeff = Decimal.int_mult_radix_power(other_coeff, -de)
      end
      q, r = self_coeff.divmod(other_coeff)
      if 2*r + (q&1) > other_coeff
        r -= other_coeff
        q += 1
      end

      return context.exception(DivisionImpossible) if q >= Decimal.int_radix_power(context.precision) && !context.exact?

      sign = self.sign
      if r < 0
        sign = -sign
        r = -r
      end

    return Decimal.new([sign, r, ideal_exp])._fix(context)

  end


  def reduce(context=nil)
    context = Decimal.define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
    end
    dup = _fix(context)
    return dup if dup.infinite?

    return Decimal.new([dup.sign, 0, 0]) if dup.zero?

    exp_max = context.clamp? ? context.etop : context.emax
    end_d = nd = dup.number_of_digits
    exp = dup.integral_exponent
    coeff = dup.integral_significand
    dgs = dup.digits
    while (dgs[end_d-1]==0) && (exp < exp_max)
      exp += 1
      end_d -= 1
    end
    return Decimal.new([dup.sign, coeff/Decimal.int_radix_power(nd-end_d), exp])

  end

  def logb(context=nil)
    context = Decimal.define_context(context)
    ans = _check_nans(context)
    return ans if ans
    return Decimal.infinity if infinite?
    return context.exception(DivisionByZero,'logb(0)',-1) if zero?
    Decimal.new(adjusted_exponent)
  end

  def scaleb(other, context=nil)

    context = Decimal.define_context(context)
    other = Decimal._convert(other)
    ans = _check_nans(context, other)
    return ans if ans
    return context.exception(InvalidOperation) if other.infinite? || other.integral_exponent != 0
    unless context.exact?
      liminf = -2 * (context.emax + context.precision)
      limsup =  2 * (context.emax + context.precision)
      i = other.to_i
      return context.exception(InvalidOperation) if !((liminf <= i) && (i <= limsup))
    end
    return Decimal.new(self) if infinite?
    return Decimal.new(@sign, @coeff, @exp+i)._fix(context)

  end

  def convert_to(type, context=nil)
    context = Decimal.define_context(context)
    context.convert_to(type, self)
  end

  def to_i
    if special?
      return nil if nan?
      raise Error, "Cannot convert infinity to Integer"
    end
    if @exp >= 0
      return @sign*Decimal.int_mult_radix_power(@coeff,@exp)
    else
      return @sign*Decimal.int_div_radix_power(@coeff,-@exp)
    end
  end

  def to_s(eng=false,context=nil)
    # (context || Decimal.context).to_string(self)
    context = Decimal.define_context(context)
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

  # Conversion to Rational.
  # Conversion of special values will raise an exception under Ruby 1.9
  def to_r
    if special?
      num = (@exp == :inf) ? @sign : 0
      Rational.respond_to?(:new!) ? Rational.new!(num,0) : Rational(num,0)
    else
      if @exp < 0
        Rational(@sign*@coeff, Decimal.int_radix_power(-@exp))
      else
        Rational(Decimal.int_mult_radix_power(@sign*@coeff,@exp), 1)
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
      @sign*@coeff*(10.0**@exp)
    end
  end

  def inspect
    #"Decimal('#{self}')"
    #debug:
    "Decimal('#{self}') [coeff:#{@coeff.inspect} exp:#{@exp.inspect} s:#{@sign.inspect}]"
  end

  def <=>(other)
    case other
    when *Decimal.context.coercible_types_or_decimal
      other = Decimal(other)
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
            self_padded,other_padded = self.integral_significand,other.integral_significand
            d = self.integral_exponent - other.integral_exponent
            if d>0
              self_padded *= Decimal.int_radix_power(d)
            else
              other_padded *= Decimal.int_radix_power(-d)
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
      if defined? other.coerce
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
    ([Decimal]+reduce.split).hash # TODO: optimize
  end
  def eql?(other)
    return false unless other.is_a?(Decimal)
    reduce.split == other.reduce.split
  end

  def compare(other, context=nil)

    other = Decimal._convert(other)

    if self.special? || other.special?
      ans = _check_nans(context, other)
      return ans if ans
    end

    return Decimal(self <=> other)

  end

  # Digits of the significand as an array of integers
  def digits
    @coeff.to_s.split('').map{|d| d.to_i}
  end




  # Exponent of the magnitude of the most significant digit of the operand
  def adjusted_exponent
    if special?
      0
    else
      @exp + number_of_digits - 1
    end
  end

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
    @coeff.to_s.size
  end

  # Significand as an integer
  def integral_significand
    @coeff
  end

  # Exponent of the significand as an integer
  def integral_exponent
    fractional_exponent - number_of_digits
  end

  # +1 / -1
  def sign
    @sign
  end

  def to_int_scale
    if special?
      nil
    else
      [@sign*integral_significand, integral_exponent]
    end
  end




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
    context = Decimal.define_context(context)
    ans._fix(context)
  end

  def _pos(context=nil)
    if special?
      ans = _check_nans(context)
      return ans if ans
    end
    if zero?
      ans = copy_abs
    else
      ans = Decimal.new(self)
    end
    context = Decimal.define_context(context)
    ans._fix(context)
  end

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

  def _fix(context)
    return self if context.exact?

    if special?
      if nan?
        return _fix_nan(context)
      else
        return Decimal.new(self)
      end
    end

    etiny = context.etiny
    etop  = context.etop
    if zero?
      exp_max = context.clamp? ? etop : context.emax
      new_exp = [[@exp, etiny].max, exp_max].min
      if new_exp!=@exp
        context.exception Clamped
        return Decimal.new([sign,0,new_exp])
      else
        return Decimal.new(self)
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
      #puts "_fix(#{self}) rounded; e=#{@exp} em=#{exp_min}"
      context.exception Rounded
      # dig is the digits number from 0 (MS) to number_of_digits-1 (LS)
      # dg = numberof_digits-dig is from 1 (LS) to number_of_digits (MS)
      dg = exp_min - @exp # dig = number_of_digits + exp - exp_min
      if dg > number_of_digits # dig<0
        d = Decimal.new([sign,1,exp_min-1])
        dg = number_of_digits # dig = 0
      else
        d = Decimal.new(self)
      end
      changed = d._round(context.rounding, dg)
      coeff = Decimal.int_div_radix_power(d.integral_significand, dg)
      coeff += 1 if changed==1
      ans = Decimal.new([sign, coeff, exp_min])
      if changed!=0
        context.exception Inexact
        if self_is_subnormal
          context.exception Underflow
          if ans.zero?
            context.exception Clamped
          end
        elsif ans.number_of_digits == context.precision+1
          if ans.integral_exponent< etop
            ans = Decimal.new([ans.sign, Decimal.int_div_radix_power(ans.integral_significand,1), ans.integral_exponent+1])
          else
            ans = context.exception(Overflow, 'above Emax', d.sign)
          end
        end
      end
      return ans
    end

    if context.clamp? &&  @exp>etop
      context.exception Clamped
      self_padded = Decimal.int_mult_radix_power(@coeff, @exp-etop)
      return Decimal.new([sign,self_padded,etop])
    end

    return Decimal.new(self)

  end


  ROUND_ARITHMETIC = true

  def _round(rounding, i)
    send("_round_#{rounding}", i)
  end

  def _round_down(i)
    if ROUND_ARITHMETIC
      (@coeff % Decimal.int_radix_power(i))==0 ? 0 : -1
    else
      d = @coeff.to_s
      p = d.size - i
      d[p..-1].match(/\A0+\Z/) ? 0 : -1
    end
  end
  def _round_up(i)
    -_round_down(i)
  end

  def _round_half_down(i)
    if ROUND_ARITHMETIC
      m = Decimal.int_radix_power(i)
      if (m>1) && ((@coeff%m) == m/2)
        -1
      else
        _round_half_up(i)
      end
    else
      d = @coeff.to_s
      p = d.size - i
      d[p..-1].match(/^5d*$/) ? -1 : _round_half_up(i)
    end

  end

  def _round_half_up(i)
    if ROUND_ARITHMETIC
      m = Decimal.int_radix_power(i)
      if (m>1) && ((@coeff%m) >= m/2)
        1
      else
        (@coeff % m)==0 ? 0 : -1
      end
    else
      d = @coeff.to_s
      p = d.size - i
      if '56789'.include?(d[p,1])
        1
      else
        d[p..-1].match(/^0+$/) ? 0 : -1
      end
    end

  end

  def _round_half_even(i)
    if ROUND_ARITHMETIC
      m = Decimal.int_radix_power(i)
      if (m>1) && ((@coeff%m) == m/2 && ((@coeff/m)%2)==0)
        -1
      else
        _round_half_up(i)
      end
    else
      d = @coeff.to_s
      p = d.size - i

      if d[p..-1].match(/\A#{radix/2}0*\Z/) && (p==0 || ((d[p-1,1].to_i%2)==0))
        -1
      else
        _round_half_up(i)
      end

    end
  end


  def _round_ceiling(i)
    sign<0 ? _round_down(i) : -_round_down(i)
  end
  def _round_floor(i)
    sign>0 ? _round_down(i) : -_round_down(i)
  end
  def _round_up05(i)
    if ROUND_ARITHMETIC
      dg = (@coeff%Decimal.int_radix_power(i+1))/Decimal.int_radix_power(i)
    else
      d = @coeff.to_s
      p = d.size - i
      dg = (p>0) ? d[p-1,1].to_i : 0
    end
    if [0,Decimal.radix/2].include?(dg)
      -_round_down(i)
    else
      _round_down(i)
    end
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
      Decimal(self)
    end

    def _check_nans(context=nil, other=nil)
      #self_is_nan = self.nan?
      #other_is_nan = other.nil? ? false : other.nan?
      if self.nan? || (other && other.nan?)
        context = Decimal.define_context(context)
        return context.exception(InvalidOperation, 'sNaN', self) if self.snan?
        return context.exception(InvalidOperation, 'sNaN', other) if other && other.snan?
        return self._fix_nan(context) if self.nan?
        return other._fix_nan(context)
      else
        return nil
      end

    end


  def _rescale(exp,rounding)

    return Decimal.new(self) if special?
    return Decimal.new([sign, 0, exp]) if zero?
    return Decimal.new([sign, @coeff*Decimal.int_radix_power(self.integral_exponent - exp), exp]) if self.integral_exponent > exp
    #nd = number_of_digits + self.integral_exponent - exp
    nd = exp - self.integral_exponent
    if number_of_digits < nd
      slf = Decimal.new([sign, 1, exp-1])
      nd = number_of_digits
    else
      slf = Decimal.new(self)
    end
    changed = slf._round(rounding, nd)
    coeff = Decimal.int_div_radix_power(@coeff, nd)
    coeff += 1 if changed==1
    Decimal.new([slf.sign, coeff, exp])

  end

  def Decimal._normalize(op1, op2, prec=0)
    #puts "N: #{op1.inspect} #{op2.inspect} p=#{prec}"
    if op1.integral_exponent < op2.integral_exponent
      swap = true
      tmp,other = op2,op1
    else
      swap = false
      tmp,other = op1,op2
    end
    tmp_len = tmp.number_of_digits
    other_len = other.number_of_digits
    exp = tmp.integral_exponent + [-1, tmp_len - prec - 2].min
    #puts "exp=#{exp}"
    if (other_len+other.integral_exponent-1 < exp) && prec>0
      other = Decimal.new([other.sign, 1, exp])
      #puts "other = #{other.inspect}"
    end
    tmp = Decimal.new([tmp.sign, int_mult_radix_power(tmp.integral_significand, tmp.integral_exponent-other.integral_exponent), other.integral_exponent])
    #puts "tmp=#{tmp.inspect}"
    return swap ? [other, tmp] : [tmp, other]
  end


  def copy_abs
    Decimal.new([+1,@coeff,@exp])
  end

  def copy_negate
    Decimal.new([-@sign,@coeff,@exp])
  end

  def copy_sign(other)
    Decimal.new([other.sign, @coeff, @exp])
  end

  def integral?
    if finite?
      if @exp>=0 || @coeff==0
        true
      else
        if @exp <= -number_of_digits
          false
        else
          m = Decimal.int_radix_power(-@exp)
          (@coeff % m) == 0
        end
      end
    else
      false
    end
  end

  def rescale(exp, context=nil, watch_exp=true)
    context = Decimal.define_context(context)
    exp = Decimal._convert(exp)
    if self.special? || exp.special?
      ans = _check_nans(context, exp)
      return ans if ans
      if exp.infinite? || self.infinite?
        return Decimal.new(self) if exp.infinite? && self.infinite?
        return context.exception(InvalidOperation, 'rescale with one INF')
      end
    end
    return context.exception(InvalidOperation,"exponent of rescale is not integral") unless exp.integral?
    exp = exp.to_i
    _watched_rescale(exp, context, watch_exp)
  end


  def quantize(exp, context=nil, watch_exp=true)
    exp = Decimal._convert(exp)
    context = Decimal.define_context(context)
    if self.special? || exp.special?
      ans = _check_nans(context, exp)
      return ans if ans
      if exp.infinite? || self.infinite?
        return Decimal.new(self) if exp.infinite? && self.infinite?
        return context.exception(InvalidOperation, 'quantize with one INF')
      end
    end
    exp = exp.integral_exponent
    _watched_rescale(exp, context, watch_exp)
  end

  def _watched_rescale(exp, context, watch_exp)
    if !watch_exp
      ans = _rescale(exp, context.rounding)
      context.exception(Rounded) if ans.integral_exponent > self.integral_exponent
      context.exception(Inexact) if ans != self
      return ans
    end

    if exp < context.etiny || exp > context.emax
      return context.exception(InvalidOperation, "target operation out of bounds in quantize/rescale")
    end

    return Decimal.new([@sign, 0, exp])._fix(context) if zero?

    self_adjusted = adjusted_exponent
    return context.exception(InvalidOperation,"exponent of quantize/rescale result too large for current context") if self_adjusted > context.emax
    return context.exception(InvalidOperation,"quantize/rescale has too many digits for current context") if (self_adjusted - exp + 1 > context.precision) && !context.exact?

    ans = _rescale(exp, context.rounding)
    return context.exception(InvalidOperation,"exponent of rescale result too large for current context") if ans.adjusted_exponent > context.emax
    return context.exception(InvalidOperation,"rescale result has too many digits for current context") if (ans.number_of_digits > context.precision) && !context.exact?
    if ans.integral_exponent > self.integral_exponent
      context.exception(Rounded)
      context.exception(Inexact) if ans!=self
    end
    context.exception(Subnormal) if !ans.zero? && (ans.adjusted_exponent < context.emin)
    return ans._fix(context)
  end

  def same_quantum?(other)
    other = Decimal._convert(other)
    if self.special? || other.special?
      return (self.nan? && other.nan?) || (self.infinite? && other.infinite?)
    end
    return self.integral_exponent == other.integral_exponent
  end

  def to_integral_exact(context=nil)
    context = Decimal.define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
      return Decimal.new(self)
    end
    return Decimal.new(self) if @exp >= 0
    return Decimal.new([@sign, 0, 0]) if zero?
    context.exception Rounded
    ans = _rescale(0, context.rounding)
    context.exception Inexact if ans != self
    return ans
  end

  def to_integral_value(context=nil)
    context = Decimal.define_context(context)
    if special?
      ans = _check_nans(context)
      return ans if ans
      return Decimal.new(self)
    end
    return Decimal.new(self) if @exp >= 0
    return _rescale(0, context.rounding)
  end


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

  def ceil(opt={})
    opt[:rounding] = :ceiling
    round opt
  end

  def floor(opt={})
    opt[:rounding] = :floor
    round opt
  end

  def truncate(opt={})
    opt[:rounding] = :down
    round opt
  end

  def fma(other, third, context=nil)
    context = Decimal.define_context(context)
    other = Decimal._convert(other)
    third = Decimal._convert(third)
    if self.special? || other.special?
      return context.exception(InvalidOperation, 'sNaN', self) if self.snan?
      return context.exception(InvalidOperation, 'sNaN', other) if other.snan?
      if self.nan?
        product = self
      elsif other.nan?
        product = other
      elsif self.infinite?
        return context.exception(InvalidOperation, 'INF * 0 in fma') if other.zero?
        product = Decimal.infinity(self.sign*other.sign)
      elsif other.infinite?
        return context.exception(InvalidOperation, '0 * INF  in fma') if self.zero?
        product = Decimal.infinity(self.sign*other.sign)
      end
    else
      product = Decimal.new([self.sign*other.sign,self.integral_significand*other.integral_significand, self.integral_exponent+other.integral_exponent])
    end
    return product.add(third, context)
  end

  def _divide_truncate(other, context)
    context = Decimal.define_context(context)
    sign = self.sign * other.sign
    if other.infinite?
      ideal_exp = self.integral_exponent
    else
      ideal_exp = [self.integral_exponent, other.integral_exponent].min
    end

    expdiff = self.adjusted_exponent - other.adjusted_exponent
    if self.zero? || other.infinite? || (expdiff <= -2)
      return [Decimal.new([sign, 0, 0]), _rescale(ideal_exp, context.rounding)]
    end
    if (expdiff <= context.precision) || context.exact?
      self_coeff = self.integral_significand
      other_coeff = other.integral_significand
      de = self.integral_exponent - other.integral_exponent
      if de >= 0
        self_coeff = Decimal.int_mult_radix_power(self_coeff, de)
      else
        other_coeff = Decimal.int_mult_radix_power(other_coeff, -de)
      end
      q, r = self_coeff.divmod(other_coeff)
      if (q < Decimal.int_radix_power(context.precision)) || context.exact?
        return [Decimal([sign, q, 0]),Decimal([self.sign, r, ideal_exp])]
      end
    end
    # Here the quotient is too large to be representable
    ans = context.exception(DivisionImpossible, 'quotient too large in //, % or divmod')
    return [ans, ans]

  end

  def _divide_floor(other, context)
    context = Decimal.define_context(context)
    sign = self.sign * other.sign
    if other.infinite?
      ideal_exp = self.integral_exponent
    else
      ideal_exp = [self.integral_exponent, other.integral_exponent].min
    end

    expdiff = self.adjusted_exponent - other.adjusted_exponent
    if self.zero? || other.infinite? || (expdiff <= -2)
      return [Decimal.new([sign, 0, 0]), _rescale(ideal_exp, context.rounding)]
    end
    if (expdiff <= context.precision) || context.exact?
      self_coeff = self.integral_significand*self.sign
      other_coeff = other.integral_significand*other.sign
      de = self.integral_exponent - other.integral_exponent
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
      if (q < Decimal.int_radix_power(context.precision)) || context.exact?
        return [Decimal([qs, q, 0]),Decimal([rs, r, ideal_exp])]
      end
    end
    # Here the quotient is too large to be representable
    ans = context.exception(DivisionImpossible, 'quotient too large in //, % or divmod')
    return [ans, ans]

  end

  def Decimal._convert(x, error=true)
    case x
    when Decimal
      x
    when *Decimal.context.coercible_types
      Decimal.new(x)
    else
      raise TypeError, "Unable to convert #{x.class} to Decimal" if error
      nil
    end
  end


  def _parser(txt)
    md = /^\s*([-+])?(?:(?:(\d+)(?:\.(\d*))?|\.(\d+))(?:[eE]([-+]?\d+))?|Inf(?:inity)?|(s)?NaN(\d*))\s*$/i.match(txt)
    if md
      OpenStruct.new :sign=>md[1], :int=>md[2], :frac=>md[3], :onlyfrac=>md[4], :exp=>md[5],
                     :signal=>md[6], :diag=>md[7]
    end
  end

end

# Decimal constructor. See Decimal#new for the parameters.
# If a Decimal is passed a reference to it is returned (no new object is created).
def Decimal(*args)
  if args.size==1 && args.first.instance_of?(Decimal)
    args.first
  else
    Decimal.new(*args)
  end
end
