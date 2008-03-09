require 'bigdecimal'
require 'forwardable'
require 'rational'
require 'monitor'
require 'ostruct'

# Decimal arbitrary precision floating point number.
class Decimal
  
  ROUND_HALF_EVEN = :half_even
  ROUND_HALF_DOWN = :half_down
  ROUND_HALF_UP = :half_up
  ROUND_FLOOR = :floor
  ROUND_CEILING = :ceiling
  ROUND_DOWN = :down
  ROUND_UP = :up
  ROUND_05UP = :up05
   
  class Error < StandardError
  end
  
  class Exception < StandardError
    attr :context
    def initialize(context=nil)
      @context = context
    end
    def self.handle(context, *args)
    end    
  end
  
  class InvalidOperation < Exception
    def self.handle(context=nil, *args)
      if args.size>0
        sign, coeff, exp = args.first.split
        Decimal(sign, exp, :nan)._fix_nan
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
          Decimal([sign, radix**context.precision - 1, context.emax - context.precision + 1])
        end
      elsif sign==-1
        if context_rounding == :floor
          Decimal.infinity(sign)
        else
          Decimal([sign, radix**context.precision - 1, context.emax - context.precision + 1])
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
  

  
  EXCEPTIONS = FlagValues(Clamped, InvalidOperation, DivisionByZero, Inexact, Overflow, Underflow, Rounded, Subnormal)


  # The context defines the arithmetic context: rounding mode, precision,...
  # Decimal.context is the current (thread-local) context.
  class Context
    def initialize(options = {})
      
      # default context:
      @rounding = ROUND_HALF_EVEN
      @precision = 28
      
      @emin = -99999999 
      @emax =  99999999 # BigDecimal misbehaves with expoonents such as 999999999
      
      @flags = Decimal::Flags(EXCEPTIONS)
      @traps = Decimal::Flags(EXCEPTIONS)      
      @ignored_flags = Decimal::Flags(EXCEPTIONS)
      
      @signal_flags = true # no flags updated if false
      @quiet = false # no traps or flags updated if ture
      
      #@ignore_flags = ...
            
      assign options
        
    end
    
    attr_accessor :rounding, :precision, :emin, :emax, :flags, :traps, :quiet, :signal_flags, :ignored_flags
    
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
        
    def self.Flags(*values)
      Decimal::Flags(EXCEPTIONS,*values)
    end    
    
    def assign(options)
      @rounding = options[:rounding] unless options[:rounding].nil?
      @precision = options[:precision] unless options[:precision].nil?        
      @traps = Flags(options[:rounding]) unless options[:rounding].nil?
      @signal_flags = options[:signal_flags] unless options[:signal_flags].nil?
      @quiet = options[:quiet] unless options[:quiet].nil?
    end
    
    
    
    CONDITION_MAP = {
      ConversionSyntax=>InvalidOperation,
      DivisionImpossible=>InvalidOperation,
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
      # ...
    end
    def substract(x,y)
      # ...
    end
    def multiply(x,y)
      # ...
    end
    def divide(x,y)
      # ...
    end
    
    def abs(x)
      # ...
    end
    
    def plus(x)
      # ...
    end
    
    def minus(x)
      # ...
    end
    
    def to_string(x)
      # ...
    end


    def reduce(x)
      # ...
    end
    
    # Adjusted exponent of x returned as a Decimal value.
    def logb(x)
      Decimal(x.adjusted_exponent,self)
    end

    # x*(radix**y) y must be an integer
    def scaleb(x, y)
      # x * radix**y
    end
    
    # Exponent in relation to the significand as an integer
    # normalized to precision digits. (minimum exponent)
    def normalized_integral_exponent(x)
      x.integral_exponent - (precision - x.number_of_digits)
    end

    # Significand normalized to precision digits
    # x == normalized_integral_significand(x) * radix**(normalized_integral_exponent)
    def normalized_integral_significand(x)
      x.integral_significand*(10**(precision - x.number_of_digits))
    end
    
    def to_normalized_int_scale(x)
      [x.sign*normalized_integral_significand(x), normalized_integral_exponent(x)]
    end


    # TO DO:
    # Ruby-style:
    #  ceil floor truncate round
    #  ** power
    # GDAS
    #  quantize, rescale: cannot be done with BigDecimal
    #  power
    #  exp log10 ln
    #  remainder_near
    #  fma: (not meaninful with BigDecimal bogus rounding)
    
    def sqrt(x)
      # ...
    end
   
    # Ruby-style integer division.
    def div(x,y)
      # ...
    end
    # Ruby-style modulo.
    def modulo(x,y)
      # ...
    end
    # Ruby-style integer division and modulo.
    def divmod(x,y)
      # ...
    end
            
    # General Decimal Arithmetic Specification integer division
    def divide_int(x,y)
      # ...
    end
    # General Decimal Arithmetic Specification remainder
    def remainder(x,y)
      # ...
    end
    # General Decimal Arithmetic Specification remainder-near
    def remainder_near(x,y)
      # ...
    end
    
            

    protected
            
    
    
  end
  
  
  # Context constructor
  def Decimal.Context(options={})
    case options
      when Context
        options
      else
        Decimal::Context.new(options)
    end
  end
  
  # The current context (thread-local).
  def Decimal.context
    Thread.current['Decimal.context'] ||= Decimal::Context.new
  end
  
  # Change the current context (thread-local).
  def Decimal.context=(c)
    Thread.current['Decimal.context'] = c    
  end
  
  # Defines a scope with a local context. A context can be passed which will be
  # set a the current context for the scope. Changes done to the current context
  # are reversed when the scope is exited.
  def Decimal.local_context(c=nil)
    keep = context.dup
    if c.kind_of?(Hash)
      Decimal.context.assign c
    else  
      Decimal.context = c unless c.nil?    
    end
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
    Decimal.new([+1, 0, :nan])
  end

  def _parser(txt)
    md = /^\s*([-+])?(?:(?:(\d+)(?:\.(\d*))?|\.(\d+))(?:[eE]([-+]?\d+))?|Inf(?:inity)?|(s)?NaN(\d*))\s*$/i.match(txt)
    if md
      OpenStruct.new :sign=>md[1], :int=>md[2], :frac=>md[3], :onlyfrac=>md[4], :exp=>md[5], 
                     :signal=>md[6], :diag=>md[7]
    end    
  end


  def initialize(*args)    
    if args.size>0 && args.last.instance_of?(Context)
      context = args.pop
    end
    context ||= Decimal.context
    
    case args.size
    when 3
      @sign, @coeff, @exp = args
      # TO DO: validate
      
    when 1              
      arg = args.first
      case arg
      when Decimal
        @sign, @coeff, @exp = arg.split
      when Integer
        if arg>0
          @sign = +1
          @int = arg
        else
          @sign = -1
          @int = -arg
        end
        @exp = 0
        
      #when Rational
        # set and  & validate
      
      when String
        m = _parser(arg)
        return (context.exception ConversionSyntax, "Invalid literal for Decimal: #{arg.inspect}") if m.nil?
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
            @coeff = m.diag.to_i
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
      error ArgumentError, "wrong number of arguments (#{args.size} for 1 or 3)"
    end                
  end


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
    !spacial?
  end
  
  def zero?
    @coeff==0 && !special?
  end
  
  def nonzero?
    @coeff>0 && finite?
  end


  
  
  def coerce(other)
    case other
      when Decimal,Integer,Rational
        [Decimal(other),self]
      else
        super
    end
  end
  
  def _bin_op(op, meth, other, context=nil)
    case other
      when Decimal,Integer,Rational
        (context || Decimal.context).send meth, self, Decimal(other)
      else
        x, y = other.coerce(self)
        x.send op, y
    end
  end
  private :_bin_op
  
  def -@(context=nil)
    (context || Decimal.context).minus(self)
  end

  def +@(context=nil)
    (context || Decimal.context).plus(self)
  end

  def +(other, context=nil)
    _bin_op :+, :add, other, context
  end
  
  def -(other, context=nil)
    _bin_op :-, :substract, other, context
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
    (context || Decimal.context).add(self,other)
  end
  
  def substract(other, context=nil)
    (context || Decimal.context).substract(self,other)
  end
  
  def multiply(other, context=nil)
    (context || Decimal.context).multiply(self,other)
  end
  
  def divide(other, context=nil)
    (context || Decimal.context).divide(self,other)
  end
  
  def abs(context=nil)
    (context || Decimal.context).abs(self)
  end

  def plus(context=nil)
    (context || Decimal.context).plus(self)
  end
  
  def minus(context=nil)
    (context || Decimal.context).minus(self)
  end

  def sqrt(context=nil)
    (context || Decimal.context).sqrt(self)
  end
  
  def div(other, context=nil)
    (context || Decimal.context).div(self,other)
  end

  def modulo(other, context=nil)
    (context || Decimal.context).modulo(self,other)
  end

  def divmod(other, context=nil)
    (context || Decimal.context).divmod(self,other)
  end

  def divide_int(other, context=nil)
    (context || Decimal.context).divide_int(self,other)
  end

  def remainder(other, context=nil)
    (context || Decimal.context).remainder(self,other)
  end
  
  def remainder_near(other, context=nil)
    (context || Decimal.context).remainder_near(self,other)
  end

  def reduce(context=nil)
    (context || Decimal.context).reduce(self)
  end

  def logb(context=nil)
    (context || Decimal.context).logb(self)
  end

  def scaleb(s, context=nil)
    (context || Decimal.context).scaleb(self, s)
  end


  def to_i
    # ...
  end

  def to_s(context=nil)
    # (context || Decimal.context).to_string(self)
  end    
  
  def inspect
    "Decimal('#{self}')"
  end
  
  def <=>(other)
    case other
      when Decimal,Integer,Rational
        # compare self with Decimal(other)
        # ...
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





      
    # adjust payload of a NaN to the context  
    def _fix_nan(context)      
      payload = @significand

      max_payload_len = context.precision
      max_payload_len -= 1 if context.clamp

      if number_of_digits > max_payload_len
          payload = payload.to_s[-max_payload_len..-1].to_i
          return Decimal([@sign, payload, @exp])
      end
      Decimal(self)
    end

    def _check_nans(other=nil, context=nil)
      self_is_nan = self.nan?
      other_is_nan = other.nil? ? false : other.nan?
      if self.nan? || (other && other.nan?)
        context ||= Decimal.context        
        return context.exception(InvalidOperation, 'sNan', self) if self.snan?
        return context.exception(InvalidOperation, 'sNan', other) if other.snan?
        return self._fix_nan(context) if self.nan?
        return other._fix_nan(context)
      else
        return nil
      end                
      
    end


  
end

# Decimal constructor
def Decimal(v)
  case v
    when Decimal
      v
    else
      Decimal.new(v)
  end
end  
