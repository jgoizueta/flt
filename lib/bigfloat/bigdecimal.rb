# This adds some extensions to BigDecimal for (limited) compatibility with Flt types

require 'bigdecimal'
require 'bigdecimal/math'

class BigDecimal

  class <<self
    def build(sign, coeff, exp)
      BigDecimal.new("#{sign*coeff}E#{exp}")
    end

    def Num(*args)
      if args.size==3
        build *args
      elsif args.size==2
        build +1, *args
      elsif args.size==1
        arg = args.first
        case arg
        when Rational
          BigDecimal.new(arg.numerator.to_s)/BigDecimal.new(arg.denominator.to_s)
        else
          BigDecimal.new(arg.to_s)
        end
      else
        raise ArgumentError, "wrong number of arguments (#{args.size} for 1, 2 or 3)"
      end
    end

    def radix
      10
    end

    # This provides an common interface (with Flt classes) to radix, etc.
    def context
      self
    end

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

  module Math
    extend BigMath
  end

end
