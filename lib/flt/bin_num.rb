require 'flt/num'
require 'flt/float'

module Flt

class BinNum < Num

  class << self
    # Numerical base.
    def radix
      2
    end

    def one_half
      new [+1, 1, -1]
    end

    # Integral power of the base: radix**n for integer n; returns an integer.
    def int_radix_power(n)
      (n < 0) ? (2**n) : (1<<n)
    end

    # Multiply by an integral power of the base: x*(radix**n) for x,n integer;
    # returns an integer.
    def int_mult_radix_power(x,n)
      n < 0 ? (x / (1<<(-n))) : (x * (1<<n))
    end

    # Divide by an integral power of the base: x/(radix**n) for x,n integer;
    # returns an integer.
    def int_div_radix_power(x,n)
      n < 0 ? (x * (1<<(-n))) : (x / (1<<n))
    end
  end

  # This is the Context class for Flt::BinNum.
  #
  # The context defines the arithmetic context: rounding mode, precision,...
  #
  # BinNum.context is the current (thread-local) context for DecNum numbers.
  class Context < Num::ContextBase

    # See Flt::Num::ContextBase#new() for the valid options
    #
    # See also the context constructor method Flt::Num.Context().
    def initialize(*options)
      super(BinNum, *options)
    end

    # The special values are normalized for binary floats: this keeps the context precision in the values
    # which will be used in conversion to decimal text to yield more natural results.

    # Normalized epsilon; see Num::Context.epsilon()
    def epsilon(sign=+1)
      super.normalize
    end

    # Normalized strict epsilon; see Num::Context.epsilon()
    def strict_epsilon(sign=+1)
      super.normalize
    end

    # Normalized strict epsilon; see Num::Context.epsilon()
    def half_epsilon(sign=+1)
      super.normalize
    end

  end # BinNum::Context

  class <<self # BinNum class methods

    def base_coercible_types
      unless defined? @base_coercible_types
        @base_coercible_types = super.merge(
          Float=>lambda{|x, context|
            if x.nan?
              BinNum.nan
            elsif x.infinite?
              BinNum.infinity(x<0 ? -1 : +1)
            elsif x.zero?
              BinNum.zero(Float.context.sign(x))
            else
              Float.context.split(x)
            end
          }
        )
      end
      @base_coercible_types
    end

  end

  # the DefaultContext is the base for new contexts; it can be changed.
  # DefaultContext = BinNum::Context.new(
  #                            :precision=>113,
  #                            :emin=> -16382, :emax=>+16383,
  #                            :rounding=>:half_even,
  #                            :flags=>[],
  #                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
  #                            :ignored_flags=>[],
  #                            :capitals=>true,
  #                            :clamp=>true)
  DefaultContext = BinNum::Context.new(
                             :exact=>false, :precision=>53, :rounding=>:half_even,
                             :emin=> -1025, :emax=>+1023,                             :flags=>[],
                             :traps=>[DivisionByZero, Overflow, InvalidOperation],
                             :ignored_flags=>[],
                             :capitals=>true,
                             :clamp=>true)

  ExtendedContext = BinNum::Context.new(DefaultContext,
                             :traps=>[], :flags=>[], :clamp=>false)

  IEEEHalfContext = BinNum::Context.new(
                            :precision=>1,
                            :emin=> -14, :emax=>+15,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  IEEESingleContext = BinNum::Context.new(
                            :precision=>24,
                            :emin=> -126, :emax=>+127,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  IEEEDoubleContext = BinNum::Context.new(
                            :precision=>53,
                            :emin=> -1022, :emax=>+1023,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  IEEEQuadContext = BinNum::Context.new(
                            :precision=>113,
                            :emin=> -16382, :emax=>+16383,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  IEEEExtendedContext = BinNum::Context.new(
                            :precision=>64,
                            :emin=> -16382, :emax=>+16383,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  if Float::RADIX==2
    FloatContext = BinNum::Context.new(
                               :precision=>Float::MANT_DIG,
                               :rounding=>Support::AuxiliarFunctions.detect_float_rounding,
                               :emin=>Float::MIN_EXP-1, :emax=>Float::MAX_EXP-1,
                               :flags=>[],
                               :traps=>[DivisionByZero, Overflow, InvalidOperation],
                               :ignored_flags=>[],
                               :capitals=>true,
                               :clamp=>true)
  end


  # A BinNum value can be defined by:
  # * A String containing a decimal text representation of the number
  # * An Integer
  # * A Rational
  # * A Float
  # * Another BinNum value.
  # * A sign, coefficient and exponent (either as separate arguments, as an array or as a Hash with symbolic keys).
  #   This is the internal representation of DecNum, as returned by DecNum#split.
  #   The sign is +1 for plus and -1 for minus; the coefficient and exponent are
  #   integers, except for special values which are defined by :inf, :nan or :snan for the exponent.
  # * Any other type for which custom conversion is defined in the context.
  #
  # An optional Context can be passed as the last argument to override the current context; also a hash can be passed
  # to override specific context parameters.
  #
  # Except for custome defined conversions and text (String) input, BinNums are constructed with the precision
  # specified by the input parameters (i.e. with the exact value specified by the parameters)
  # and the context precision is ignored. If the BinNum is defined by a decimal text numeral, it is converted
  # to a binary BinNum using the context precision.
  #
  # The Flt.BinNum() constructor admits the same parameters and can be used as a shortcut for DecNum creation.
  def initialize(*args)
    super(*args)
  end

  def number_of_digits
    @coeff.is_a?(Integer) ? _nbits(@coeff) : 0
  end

  # Specific to_f conversion TODO: check if it represents an optimization
  if Float::RADIX==2
    def to_f
      if special?
        super
      else
        ::Math.ldexp(@sign*@coeff, @exp)
      end
    end
  end

  # Exact BinNum to DecNum conversion: preserve BinNum value.
  #
  # The current DecNum.context determines the valid range and the precision
  # (if its is not :exact the result will be rounded)
  def to_decimal_exact(dec_context=nil)
    Num.convert_exact(self, DecNum, dec_context)
  end

  # Approximate BinNum to DecNum conversion.
  #
  # Convert to decimal so that if the decimal is converted to a BinNum of the same precision
  # and with same rounding (i.e. BinNum.from_decimal(x, context)) the value of the BinNum
  # is preserved, but use as few decimal digits as possible.
  def to_decimal(*args)
    Num.convert(self, DecNum, *args)
  end

  # DecNum to BinNum conversion.
  def BinNum.from_decimal(x, binfloat_context=nil)
    Flt.BinNum(x.to_s, binfloat_context)
  end

  # Unit in the last place: see Flt::Num#ulp()
  #
  # For BinNum the result is normalized
  def ulp(context=nil, mode=:low)
    super(context, mode).normalize(context)
  end

end

module_function
def BinNum(*args)
  BinNum.Num(*args)
end


end # Flt
