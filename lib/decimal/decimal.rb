# quick & dirty Decimal implemention using BigDecimal to experiment with the interface
# development plan:
# -experiment and define API with this BigDecimal based implementation
# -write compliant implementation (use tests from decNumber) either by porting the Python code
#  or by writing an extension using decNumber (or do both, using the pure ruby version if
#  decNumber is not available or cannot compile extensions)

require 'bigdecimal'
require 'forwardable'
require 'rational'
require 'monitor'


# Decimal arbitrary precision floating point number.
class Decimal
  
  # TO DO: use Flags for rounding modes (and a hash from symbols to BigDecimal constants)
  ROUND_HALF_EVEN = BigDecimal::ROUND_HALF_EVEN
  ROUND_HALF_DOWN = BigDecimal::ROUND_HALF_DOWN
  ROUND_HALF_UP = BigDecimal::ROUND_HALF_UP
  ROUND_FLOOR = BigDecimal::ROUND_FLOOR
  ROUND_CEILING = BigDecimal::ROUND_CEILING
  ROUND_DOWN = BigDecimal::ROUND_DOWN
  ROUND_UP = BigDecimal::ROUND_UP
  
 
  class Exception < StandardError
    attr :context
    def initialize(context=nil)
      @context = context
    end
  end
  
  class InvalidOperation < Exception
  end
  
  class DivisionByZero < Exception
  end
  
  class Inexact < Exception
  end
  
  class Overflow < Exception
  end
  
  class Underflow < Exception
  end

  EXCEPTIONS = FlagValues(:invalid_operation, :division_by_zero, :inexact, :overflow, :underflow)


  # The context defines the arithmetic context: rounding mode, precision,...
  # Decimal.context is the current (thread-local) context.
  class Context
    def initialize(options = {})
      
      # default context:
      @rounding = ROUND_HALF_EVEN
      @precision = 28
      
      @emin = -999999999
      @emax =  999999999
      
      @flags = Decimal::Flags(EXCEPTIONS)
      @traps = Decimal::Flags(EXCEPTIONS)
            
      assign options
        
    end
    attr_accessor :rounding, :precision, :emin, :emax, :flags, :traps
    def digits
      self.precision
    end
    def digits=(n)
      self.precision=n
    end
    
    def self.Flags(*values)
      Decimal::Flags(EXCEPTIONS,*values)
    end
    
    def assign(options)
      @rounding = options[:rounding] unless options[:rounding].nil?
      @precision = options[:precision] unless options[:precision].nil?        
      @traps = Flags(options[:rounding]) unless options[:rounding].nil?
    end
    
    def add(x,y)
      compute { Decimal(x._value+y._value) }
    end
    def substract(x,y)
      compute { Decimal(x._value-y._value) }
    end
    def multiply(x,y)
      compute { Decimal(x._value*y._value) }
    end
    def divide(x,y)
      compute { Decimal(x._value.div(y._value,@precision)) }
    end
    
    def abs(x)
      compute { Decimal(x._value.abs) }
    end
    
    def plus(x)
      compute do
        Decimal(x._value*BigDecimal('1')) # to force rounding
      end
    end
    
    def minus(x)
      compute { Decimal(-x._value) }
    end
    
    def to_string(x)
      x._value.to_s('F')
    end


    def reduce(x)
      # nop: BigDecimals are always in reduced form
      x
    end
    
    # Adjusted exponent of x returned as a Decimal value.
    def logb(x)
      compute { Decimal(x.adjusted_exponent) }
    end

    # x*(radix**y) y must be an integer
    def scaleb(x, y)
      compute { Decimal(Decimal(x)._value * (BigDecimal('10')**y.to_i)) }
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
      compute { Decimal(x._value.sqrt(@precision)) }
    end
   
    # Ruby-style integer division.
    def div(x,y)
      compute { Decimal(x._value.div(y._value)) }
    end
    # Ruby-style modulo.
    def modulo(x,y)
      compute { Decimal(x._value.modulo(y._value)) }
    end
    # Ruby-style integer division and modulo.
    def divmod(x,y)
      compute { x._value.divmod(y._value).map{|z| Decimal(z)} }
    end
            
    # General Decimal Arithmetic Specification integer division
    def divide_int(x,y)
      # compute { Decimal(x._value/y._value).truncate }      
      compute(:rounding=>ROUND_DOWN) { Decimal((x._value/y._value).truncate) }      
    end
    # General Decimal Arithmetic Specification remainder
    def remainder(x,y)
      compute { Decimal(x._value.remainder(y._value)) }      
    end
    # General Decimal Arithmetic Specification remainder-near
    def remainder_near(x,y)
      compute do
        z = (x._value.div(y._value, @precision)).round
        Decimal(x._value - y._value*z)
      end
    end
    
    
    def zero(sign=+1)
      Decimal("#{sign<0 ? '-' : '+'}0")
    end
    def infinity(sign=+1)
      compute(:traps=>0) { Decimal(BigDecimal(sign.to_s)/BigDecimal('0')) }
    end
    def nan
      compute(:traps=>0) { Decimal(BigDecimal('0')/BigDecimal('0')) }
    end
        

    protected
    @@compute_lock = Monitor.new  
    # Use of BigDecimal is done in blocks passed to this method, which sets
    # the rounding mode and precision defined in the context.
    # Since the BigDecimal rounding mode and precision is a global resource,
    # a lock must be used to prevent other threads from modifiying it.
        
    # TO DO:
    # implement UPDATE_FLAGS
    # decide how to store flags & traps: integer (bit_field) - constants or Set of exc. classes
    #        Decimal::EXCEPTION_NAN || Decimal::EXCEPTION_OVERFLOW
    #        Decimal::FLAG_NAN || Decimal::FLAG_OVERFLOW              vs Set.new[NanException, OverflowException]
    UPDATE_FLAGS = false
    
    def compute(options={})
      rnd = options[:rounding] || @rounding
      prc = options[:precision] || options[:digits] || @precision
      trp = Context::Flags(options[:traps] || @traps)
      result = nil
      @@compute_lock.synchronize do
        keep_limit = BigDecimal.limit(prc)
        keep_round_mode = BigDecimal.mode(BigDecimal::ROUND_MODE, rnd)
        BigDecimal.mode BigDecimal::ROUND_MODE, rnd
        if trp.any? || UPDATE_FLAGS
          keep_exceptions = BigDecimal.mode(BigDecimal::EXCEPTION_ALL)
          BigDecimal.mode(BigDecimal::EXCEPTION_ALL, true)
        end
        begin
          result = yield
        rescue FloatDomainError=>err
          case err.message
            when "(VpDivd) Divide by zero"
              @flags << :division_by_zero
              raise DivisionByZero if trp[:division_by_zero]
              result = infinity
            when "exponent overflow", "Computation results to 'Infinity'", "Computation results to '-Infinity'", "Exponent overflow"
              @flags << :overflow
              raise Overflow if trp[:overflow]
              result = infinity            
            when "(VpDivd) 0/0 not defined(NaN)", "Computation results to 'NaN'(Not a Number)", "Computation results to 'NaN'",  "(VpSqrt) SQRT(NaN or negative value)",
                  "(VpSqrt) SQRT(negative value)"
              @flags << :invalid_operation
              raise InvalidOperation if trp[:invalid_operation]
              result = nan                         
            when "BigDecimal to Float conversion"
              @flags << :invalid_operation
              raise InvalidOperation if trp[:invalid_operation]
              result = nan                         
            when "Exponent underflow"
              @flags << :underflow
              raise Undrflow if trp[:underflow]
              result = zero            
          end
        end
        BigDecimal.limit keep_limit
        BigDecimal.mode BigDecimal::ROUND_MODE, keep_round_mode            
        if trp.any? || UPDATE_FLAGS
          [BigDecimal::EXCEPTION_NaN, BigDecimal::EXCEPTION_INFINITY, BigDecimal::EXCEPTION_UNDERFLOW,
           BigDecimal::EXCEPTION_OVERFLOW, BigDecimal::EXCEPTION_ZERODIVIDE].each do |exc|
             value =  ((keep_exceptions & exc)!=0)
             BigDecimal.mode(exc, value)               
          end
        end
      end   
      e = result.adjusted_exponent
      if e>@emax 
        result = infinity(result.sign)
        @flags << :infinity
        raise Overflow if trp[:overflow]
      elsif e<@emin
        result = zero(result.sign)
        @flags << :underflow
        raise Overflow if trp[:underflow]
      end
      result
    end          
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
    
  def Decimal.zero(sign=+1, c=nil)
    (c || context).zero(sign)
  end
  def Decimal.infinity(sign=+1, c=nil)
    (c || context).infinity(sign)
  end
  def Decimal.nan
    (c || context).nan
  end
    
  def initialize(v)
    case v
      when BigDecimal
        @value = v
      when Decimal
        @value = v._value
      when Integer
        @value = BigDecimal(v.to_s)
      when Rational
        @value = BigDecimal.new(v.numerator.to_s)/BigDecimal.new(v.denominator.to_s)
      else
        @value = BigDecimal(v)
    end
  end
  
  def _value # :nodoc:
    @value
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
    @value.to_i
  end

  def to_s(context=nil)
    (context || Decimal.context).to_string(self)
  end    
  
  def inspect
    "Decimal('#{self}')"
  end
  
  def <=>(other)
    case other
      when Decimal,Integer,Rational
        self._value <=> Decimal(other)._value
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
  
  extend Forwardable
  [:finite?, :infinite?, :nan?, :zero?, :nonzero?].each do |m|
    def_delegator :@value, m, m
  end
  
  def special?
    !finite?
  end
  
  
  # Exponent of the magnitude of the most significant digit of the operand 
  def adjusted_exponent
    @value.exponent - 1
  end
  
  def scientific_exponent
    adjusted_exponent
  end
  # Exponent as though the significand were a fraction (the decimal point before its first digit)
  def fractional_exponent
    # scientific_exponent + 1
    @value.exponent
  end  
    
  # Number of digits in the significand
  def number_of_digits
    @value.split[1].size
  end
  
  # Significand as an integer
  def integral_significand
    @value.split[1].to_i
  end
  
  # Exponent of the significand as an integer
  def integral_exponent
    fractional_exponent - number_of_digits
  end
  
  # +1 / -1 (also for zero and infinity); nil for NaN
  def sign
    if nan?
      nil
    else
      @value.sign < 0 ? -1 : +1
    end
  end
  
  def to_int_scale
    if special?
      nil
    else
      [sign*integral_significand, integral_exponent]
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
