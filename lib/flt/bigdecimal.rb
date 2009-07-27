# This adds some extensions to BigDecimal for (limited) compatibility with Flt types

require 'flt'
require 'bigdecimal'
require 'bigdecimal/math'

module Flt::BigDecimalExtensions

  def self.included(base)
    base.extend(ClassMethods)
  end

  def num_class
    self.class
  end

  def ulp(mode=:low)
    if self.nan?
      return self
    elsif self.infinite?
      return nil
    elsif self.zero?
      return nil
    else
      if BigDecimal.limit != 0
        prec = BigDecimal.limit
      else
        prec = [self.precs[0], Float::DIG].max
      end
      exp = self.exponent - (prec-1)
      BigDecimal.new "1E#{exp}"
    end
  end

  module ClassMethods

    def Num(*args)
      Flt.BigDecimalNum(*args)
    end

    def radix
      10
    end

    # This provides an common interface (with Flt classes) to radix, etc.
    def context
      self
    end

  end

  # module Math
  #   extend BigMath
  # end

end

class Flt::BigDecimalNum  < DelegateClass(BigDecimal)

  include Flt::BigDecimalExtensions

  def initialize(*args)
    super BigDecimal.new(*args)
  end

end

def Flt.extend_big_decimal
  BigDecimal.send :include, Flt::BigDecimalExtensions unless BigDecimal < Flt::BigDecimalExtensions
end

def Flt.BigDecimalNum(*args)
  if args.size==3
    x = BigDecimal.new("#{args[0]*args[1]}E#{args[2]}")
  elsif args.size==2
    x = BigDecimal.new("#{args[0]}E#{args[1]}")
  elsif args.size==1
    arg = args.first
    case arg
    when BigDecimal
      x = arg
    when Rational
      x = BigDecimal.new(arg.numerator.to_s)/BigDecimal.new(arg.denominator.to_s)
    else
      x = BigDecimal.new(arg.to_s)
    end
  else
    raise ArgumentError, "wrong number of arguments (#{args.size} for 1, 2 or 3)"
  end
  BigDecimal < Flt::BigDecimalExtensions ? x : Flt::BigDecimalNum.new(x)
end

def Flt.BigDecimalNumClass
  BigDecimal < Flt::BigDecimalExtensions ? BigDecimal : Flt::BigDecimalExtensions
end
Flt.extend_big_decimal

