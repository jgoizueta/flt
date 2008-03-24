require 'bigdecimal'
require 'forwardable'
require 'rational'
require 'monitor'


module FPNum


# BigDecimal-based Decimal implementation
module BD

# Decimal arbitrary precision floating point number.
class Decimal
  
  extend FPNum # allows use of unqualified FlagValues(), Flags()
  include BD # allows use of unqualified Decimal()

  ROUND_HALF_EVEN = BigDecimal::ROUND_HALF_EVEN
  ROUND_HALF_DOWN = BigDecimal::ROUND_HALF_DOWN
  ROUND_HALF_UP = BigDecimal::ROUND_HALF_UP
  ROUND_FLOOR = BigDecimal::ROUND_FLOOR
  ROUND_CEILING = BigDecimal::ROUND_CEILING
  ROUND_DOWN = BigDecimal::ROUND_DOWN
  ROUND_UP = BigDecimal::ROUND_UP
  ROUND_05UP = nil
   
  class Error < StandardError
  end
  
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
  
  class DivisionImpossible < Exception
  end

  class DivisionUndefined < Exception
  end
    
  class Inexact < Exception
  end
  
  class Overflow < Exception
  end
  
  class Underflow < Exception
  end

  class Clamped < Exception
  end
  
  class InvalidContext < Exception
  end
  
  class Rounded < Exception
  end

  class Subnormal < Exception
  end
  
  class ConversionSyntax < InvalidOperation
  end

  EXCEPTIONS = FlagValues(Clamped, InvalidOperation, DivisionByZero, Inexact, Overflow, Underflow, Rounded, Subnormal, DivisionImpossible)

  def self.Flags(*values)
    FPNum::Flags(EXCEPTIONS,*values)
  end


  # The context defines the arithmetic context: rounding mode, precision,...
  # Decimal.context is the current (thread-local) context.
  class Context
    
    include BD # allows use of unqualified Decimal()
    
    def initialize(options = {})
      
      # default context:
      @exact = false
      @rounding = ROUND_HALF_EVEN
      @precision = 28
      
      @emin = -99999999 
      @emax =  99999999 # BigDecimal misbehaves with expoonents such as 999999999
      
      @flags = Decimal::Flags()
      @traps = Decimal::Flags()      
      @ignored_flags = Decimal::Flags()
      
      @signal_flags = true # no flags updated if false
      @quiet = false # no traps or flags updated if ture
            
      @capitals = true
      
      @clamp = false
            
      assign options
        
    end
    attr_accessor :rounding, :precision, :emin, :emax, :flags, :traps, :quiet, :signal_flags, :ignored_flags, :capitals, :clamp, :exact

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
      update_precision
      n
    end
    def exact=(v)
      @exact = v
      update_precision
      v
    end
    def exact?
      @exact
    end
    
    
    def assign(options)
      @rounding = options[:rounding] unless options[:rounding].nil?
      @precision = options[:precision] unless options[:precision].nil?        
      @traps = Decimal::Flags(options[:rounding]) unless options[:rounding].nil?
      @ignored_flags = options[:ignored_flags] unless options[:ignored_flags].nil?
      @signal_flags = options[:signal_flags] unless options[:signal_flags].nil?
      @quiet = options[:quiet] unless options[:quiet].nil?
      @emin = options[:emin] unless options[:emin].nil?
      @emax = options[:emax] unless options[:emax].nil?
      @capitals = options[:capitals ] unless options[:capitals ].nil?
      @clamp = options[:clamp ] unless options[:clamp ].nil?
      @exact = options[:exact ] unless options[:exact ].nil?
      update_precision
    end
    
    def _fix_bd(x)
      if x.finite? && !@exact
        compute { x*BigDecimal('1') }
      else
        x
      end
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
      if exact?
        prec = x.number_of_digits + 4*y.number_of_digits
        compute {
          z = x._value.div(y._value, prec)
          raise Decimal::Inexact if z*y._value != x._value
          Decimal(z)
        }
      else
        compute { Decimal(x._value.div(y._value,@precision)) }
      end
    end
    
    def abs(x)
      compute { Decimal(x._value.abs) }
    end
    
    def plus(x)      
      x._fix(self)
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
      i = y.to_i
      if i
        compute { Decimal(Decimal(x)._value * (BigDecimal('10')**y.to_i)) }
      else
        nan
      end
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
    #  ** power
    # GDAS
    #  quantize, rescale: cannot be done with BigDecimal
    #  power
    #  exp log10 ln
    #  remainder_near
    
    def sqrt(x)
      if exact?
        # TO DO...
        context.raise Decimal::Inexact
      else
        compute { Decimal(x._value.sqrt(@precision)) }
      end
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
        if exact?
          # TO DO....
          raise Decimal::Inexact
        else
          z = (x._value.div(y._value, @precision)).round
          Decimal(x._value - y._value*z)
        end
      end
    end
    
    
    def zero(sign=+1)
      Decimal.zero(sign)
    end
    def infinity(sign=+1)
      Decimal.infinity(sign)
    end
    def nan
      Decimal.nan
    end
        

    def compare(x,y)
      cmp = x<=>y
      cmp.nil? ? nan : Decimal(cmp)
    end
    
    def copy_abs(x)
      Decimal(x._value.abs)
    end

    def copy_negate(x)
      Decimal(-(x._value))
    end
    
    def copy_sign(x,y)
      txt = y._value.to_s
      if txt[0,1]=='-'
        txt = txt[1..-1]
      else
        txt = '-'+txt
      end
      Decimal(txt)
    end
    
    def rescale(x,exp)
      x
    end
    
    def quantize(x,y)
      x
    end
    
    def same_quantum?(x,y)
      true
    end
    
    def to_integral_value(x)
      i = x.to_i
      if i
        Decimal(x.to_i)
      else
        nan
      end
    end
    
    def to_integral_exact(x)
      i = x.to_i
      if i
        Decimal(x.to_i)
      else
        nan
      end
    end
    
    def integral?(x)
      x.integral?
    end
    
    def fma(x,y,z)
      exact_context = self.dup
      exact_context.exact = true
      product = exact_context.multiply(x,y)
      add(product,z)
    end
    
    def Context.round(x, opt={})
      opt = { :places=>opt } if opt.kind_of?(Integer)
      r = opt[:rounding] || :half_up
      as_int = false
      if v=(opt[:precision] || opt[:significant_digits])
        places = v - x.adjusted_exponent - 1
      elsif v=(opt[:places])
        places = v
      else
        places = 0
        as_int = true
      end
      result = x._value.round(places, big_decimal_rounding(r))
      return as_int ? result.to_i : Decimal.new(result)
    end
    
    protected
            
    @@compute_lock = Monitor.new  
    # Use of BigDecimal is done in blocks passed to this method, which sets
    # the rounding mode and precision defined in the context.
    # Since the BigDecimal rounding mode and precision is a global resource,
    # a lock must be used to prevent other threads from modifiying it.
    UPDATE_FLAGS = true
    
    def compute(options={})
      rnd = Context.big_decimal_rounding(options[:rounding] || @rounding)
      prc = options[:precision] || options[:digits] || @precision
      trp = Decimal.Flags(options[:traps] || @traps)
      quiet = options[:quiet] || @quiet
      result = nil
      @@compute_lock.synchronize do
        keep_limit = BigDecimal.limit(prc)
        keep_round_mode = BigDecimal.mode(BigDecimal::ROUND_MODE, rnd)
        BigDecimal.mode BigDecimal::ROUND_MODE, rnd
        keep_exceptions = BigDecimal.mode(BigDecimal::EXCEPTION_ALL)
        if (trp.any? || @signal_flags) && !quiet
          BigDecimal.mode(BigDecimal::EXCEPTION_ALL, true)
          BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, true)
          BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, true)
        else 
          BigDecimal.mode(BigDecimal::EXCEPTION_ALL, false)
          BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
          BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, false)
        end
        begin
          result = yield
        rescue FloatDomainError=>err
          case err.message
            when "(VpDivd) Divide by zero"
              @flags << DivisionByZero
              raise DivisionByZero if trp[DivisionByZero]
              BigDecimal.mode(BigDecimal::EXCEPTION_ZERODIVIDE, false)
              retry # to set the result value
            when "exponent overflow", "Computation results to 'Infinity'", "Computation results to '-Infinity'", "Exponent overflow"            
              @flags << Overflow
              raise Overflow if trp[Overflow]
              BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
              retry # to set the result value
            when "(VpDivd) 0/0 not defined(NaN)", "Computation results to 'NaN'(Not a Number)", "Computation results to 'NaN'",  "(VpSqrt) SQRT(NaN or negative value)",
                  "(VpSqrt) SQRT(negative value)"
              @flags << InvalidOperation
              raise InvalidOperation if trp[InvalidOperation]
              #BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
              #retry # to set the result value
              BigDecimal.mode(BigDecimal::EXCEPTION_ALL, false)
              result = nan
            when "BigDecimal to Float conversion"
              @flags << InvalidOperation
              raise InvalidOperation if trp[InvalidOperation]
              BigDecimal.mode(BigDecimal::EXCEPTION_ALL, false)
              result = nan
            when "Exponent underflow"
              @flags << Underflow
              raise Underflow if trp[Underflow]
              BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, false)
              retry # to set the result value
          end
        end
        BigDecimal.limit keep_limit
        BigDecimal.mode BigDecimal::ROUND_MODE, keep_round_mode            
        [BigDecimal::EXCEPTION_NaN, BigDecimal::EXCEPTION_INFINITY, BigDecimal::EXCEPTION_UNDERFLOW,
         BigDecimal::EXCEPTION_OVERFLOW, BigDecimal::EXCEPTION_ZERODIVIDE].each do |exc|
           value =  ((keep_exceptions & exc)!=0)
           BigDecimal.mode(exc, value)               
        end
      end   
      if result.instance_of?(Decimal)
        if result.finite?
          e =  result.adjusted_exponent
          if e>@emax 
            #result = infinity(result.sign)
            result = nan
            @flags << Overflow if @signal_flags && !quiet
            raise Overflow if trp[Overflow]
          elsif e<@emin
            result = zero(result.sign)
            @flags << Underflow if @signal_flags && !quiet
            raise Underflow if trp[Underflow]
          end
        elsif @signal_flags && !quiet
          @flags << InvalidOperation if result.nan?        
        end
      end
      result
    end          
    
    def update_precision
      if @exact || @precision==0
        @exact = true         
        @precision = 0
        @traps << Inexact
        @ignored_flags[Inexact] = false
      end
    end
    
    ROUNDING_MODES_NAMES = {  
      :half_even=>ROUND_HALF_EVEN,
      :half_up=>ROUND_HALF_UP,
      :half_down=>ROUND_HALF_DOWN,
      :floor=>ROUND_FLOOR,
      :ceiling=>ROUND_CEILING,
      :down=>ROUND_DOWN,
      :up=>ROUND_UP,
      :up05=>ROUND_05UP    
    }
    ROUNDING_MODES = [
      ROUND_HALF_EVEN, 
      ROUND_HALF_DOWN,
      ROUND_HALF_UP,
      ROUND_FLOOR,
      ROUND_CEILING,
      ROUND_DOWN,
      ROUND_UP,
      ROUND_05UP
    ]
    def Context.big_decimal_rounding(m)
      mode = m      
      if mode.kind_of?(Symbol)
        mode = ROUNDING_MODES_NAMES[mode]
      end
      raise Error,"Invalid rounding mode #{m.inspect}"  unless mode && ROUNDING_MODES.include?(mode)
      mode
    end
    
  end
  
  
  # Context constructor
  def Decimal.Context(options=:default)
    case options
      when :default
        Decimal::Context.new
      when Context
        options
      when nil
        Decimal.context
      else
        Decimal::Context.new(options)
    end
  end
  
  # The current context (thread-local).
  def Decimal.context
    Thread.current['FPNum::BD::Decimal.context'] ||= Decimal::Context.new
  end
  
  # Change the current context (thread-local).
  def Decimal.context=(c)
    Thread.current['FPNum::BD::Decimal.context'] = c    
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

  DefaultContext = Decimal::Context()

  def zero(sign=+1)
  end
  def infinity(sign=+1)
    compute(:quiet=>true) { Decimal(BigDecimal(sign.to_s)/BigDecimal('0')) }
  end
  def nan
    compute(:quiet=>true) { Decimal(BigDecimal('0')/BigDecimal('0')) }
  end
        
  def Decimal._sign_symbol(sign)
    sign<0 ? '-' : '+'
  end

  def Decimal.zero(sign=+1)
    Decimal.new("#{_sign_symbol(sign)}0")
  end
  def Decimal.infinity(sign=+1)
    Decimal.new("#{_sign_symbol(sign)}Infinity")
  end
  def Decimal.nan()
    Decimal.new('NaN')
  end
    
  def initialize(*args)
    context = nil
    if args.size>0 && args.last.instance_of?(Context)
      context ||= args.pop
    elsif args.size>1 && args.last.instance_of?(Hash)
      context ||= args.pop
    elsif args.size==1 && args.last.instance_of?(Hash)
      arg = args.last
      args = [arg[:sign], args[:coefficient], args[:exponent]]
      context ||= Context(arg) # TO DO: remove sign, coeff, exp form arg
    end
    
    context = Decimal.Context(context)
        
    case args.size
    when 3
      @value = BigDecimal.new("#{_sign_symbol(args[0])}#{args[1]}E#{args[2]}")
      _fix!(context)
      
    when 1              
      arg = args.first
      case arg
        
      when BigDecimal
        @value = arg
        _fix!(context)
        
      when Decimal
        @value = arg._value
        _fix!(context)
      when Integer
        @value = BigDecimal.new(arg.to_s)
        _fix!(context)
        
      when Rational      
        if !context.exact? || ((arg.numerator % arg.denominator)==0)
          num = arg.numerator.to_s
          den = arg.denominator.to_s
          prec = context.exact? ? num.size + 4*den.size : context.precision
          @value = BigDecimal.new(num).div(BigDecimal.new(den), prec)        
          _fix!(context)
        else  
          raise Inexact
        end
      
      when String
        arg = arg.to_s.sub(/Inf(?:\s|\Z)/i, 'Infinity')
        @value = BigDecimal.new(arg.to_s)
        _fix!(context)
        
      when Array
        @value = BigDecimal.new("#{_sign_symbol(arg[0])}#{arg[1]}E#{arg[2]}")
        
      else
        raise TypeError, "invalid argument #{arg.inspect}"
      end
    else
      raise ArgumentError, "wrong number of arguments (#{args.size} for 1 or 3)"
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
        other = Decimal.new(other) unless other.instance_of?(Decimal)
        Decimal.Context(context).send meth, self, other
      else
        x, y = other.coerce(self)
        x.send op, y
    end
  end
  private :_bin_op
  
  def -@(context=nil)
    Decimal.Context(context).minus(self)
  end

  def +@(context=nil)
    Decimal.Context(context).plus(self)
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
    Decimal.Context(context).add(self,other)
  end
  
  def substract(other, context=nil)
    Decimal.Context(context).substract(self,other)
  end
  
  def multiply(other, context=nil)
    Decimal.Context(context).multiply(self,other)
  end
  
  def divide(other, context=nil)
    Decimal.Context(context).divide(self,other)
  end
  
  def abs(context=nil)
    Decimal.Context(context).abs(self)
  end

  def plus(context=nil)
    Decimal.Context(context).plus(self)
  end
  
  def minus(context=nil)
    Decimal.Context(context).minus(self)
  end

  def sqrt(context=nil)
    Decimal.Context(context).sqrt(self)
  end
  
  def div(other, context=nil)
    Decimal.Context(context).div(self,other)
  end

  def modulo(other, context=nil)
    Decimal.Context(context).modulo(self,other)
  end

  def divmod(other, context=nil)
    Decimal.Context(context).divmod(self,other)
  end

  def divide_int(other, context=nil)
    Decimal.Context(context).divide_int(self,other)
  end

  def remainder(other, context=nil)
    Decimal.Context(context).remainder(self,other)
  end
  
  def remainder_near(other, context=nil)
    Decimal.Context(context).remainder_near(self,other)
  end

  def reduce(context=nil)
    Decimal.Context(context).reduce(self)
  end

  def logb(context=nil)
    Decimal.Context(context).logb(self)
  end

  def scaleb(s, context=nil)
    Decimal.Context(context).scaleb(self, s)
  end

  def compare(other, context=nil)
    Decimal.Context(context).compare(self, other)
  end

  def copy_abs(context=nil)
    Decimal.Context(context).copy_abs(self)
  end
  def copy_negate(context=nil)
    Decimal.Context(context).copy_negate(self)
  end
  def copy_sign(other,context=nil)
    Decimal.Context(context).copy_sign(self,other)
  end
  def rescale(exp,context=nil)
    Decimal.Context(context).rescale(self,exp)
  end
  def quantize(other,context=nil)
    Decimal.Context(context).quantize(self,other)
  end
  def same_quantum?(other,context=nil)
    Decimal.Context(context).same_quantum?(self,other)
  end
  def to_integral_value(context=nil)
    Decimal.Context(context).to_integral_value(self)
  end
  def to_integral_exact(context=nil)
    Decimal.Context(context).to_integral_exact(self)
  end

  def fma(other, third, context=nil)
    Decimal.Context(context).fma(self, other, third)
  end

  def round(opt={})
    Context.round(self, opt)
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

  def to_i
    @value.to_i
  end

  def to_s(context=nil)
    Decimal.Context(context).to_string(self)
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
  [:infinite?, :nan?, :zero?, :nonzero?].each do |m|
    def_delegator :@value, m, m
  end
  def finite?
    _value.finite? || _value.zero?
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
 
  def _fix(context)
    Decimal.new(context._fix_bd(@value))
  end

  def integral?
    @value.frac == 0
  end

  private
  
  def _fix!(context)
    @value = context._fix_bd(@value) if @value.finite?
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
module_function :Decimal

end
end
