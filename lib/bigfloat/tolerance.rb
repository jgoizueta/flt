require 'bigfloat'
require 'bigfloat/float'

module BigFloat

  # Tolerance for floating-point types (Float, BigFloat::BinFloat, BigFloat::Decimal)
  class Tolerance

    def initialize(value)
      @value = value
    end

    def value(x=nil)
      if x
        relative_to(x)
      else
        @value
      end
    end

    def [](x)
      value(x)
    end

    def to_s
      descr_value
    end

    def zero?(x, y=nil)
      x.zero? || x.abs < value(y) # value(y || x)
    end

    def less_than?(x,y)
      y-x > relative_to_many(:max, x, y)
    end

    def greater_than?(x,y)
      x-y > relative_to_many(:max, x, y)
    end

    def equals?(x, y)
      (x-y).abs <= relative_to_many(:min, x, y)
    end

    def nearly_equals?
      (x-y).abs <= relative_to_many(:max, x, y)
    end

    # Returns true if the argument is approximately an integer
    def apprx_i?(x)
      equals?(x, x.round)
    end

    # If the argument is close to an integer it rounds it
    def apprx_i(x)
      r = x.round
      return equals?(x,r) ? r : nil
    end

    # Derived classes must implement at least one of the methods
    # relative_to or relative_to_many
    # (this offers opportunities for optimization)

    # Compute the tolerance value in relation to the value x;
    def relative_to(x)
      relative_to_many(:max, x)
    end

    # Compute the tolerance value in relation to the values xs;
    # mode must be either :max or :min, and determines if the
    # largerst (relaxed condition) or smallest (strict condition) of the
    # relative tolerances is returned
    def relative_to_many(mode, *xs)
      xs.map{|x| relative_to(x)}.send(mode)
    end

    # Returns the tolerance reference value for a numeric class; in derived classes this
    # can be redefined to allow for values which change in value or precision depending
    # on the numeric class or context.
    def cast_value(num_class)
      num_class.Num(@value)
    end

    # Descriptionof the reference value (can be redefined in derived classes)
    def descr_value
      @value.to_s
    end

    class <<self

      def digits(base, n, rounded=true)
        v = base**(-n)
        v /= 2 if rounded
        v
      end

      def decimals(n, rounded=true)
        digits 10, n, rounded
      end

      def bits(n, rounded=true)
        digits 10, n, rounded
      end

      def epsilon(num_class, mult=1)
        num_class.context.epsilon*mult
      end

      # This is a tolerance that makes multiplication associative (if used with FloatingTolerance)
      def big_epsilon(num_class, mult=1)
        e0 = num_class.context.epsilon
        # we could compute with round-up instead of using next_plus, but we can't do that with Float
        den = (num_class.Num(1)-e0/2)
        big_eps = (e0*2/(den*den)).next_plus
        big_eps*mult
      end

    end

  end

  class AbsoluteTolerance < Tolerance
    def initialize(value)
      super
    end
    def relative_to(x)
      cast_value(x.class)
    end
    def relative_to_many(mode, *xs)
      cast_value(xs.first.class)
    end
  end

  class RelativeTolerance < Tolerance
    def initialize(value)
      super
    end
    def relative_to(x)
      x.abs*cast_value(x.class)
    end
    def to_s
      "#{descr_value}/1"
    end
  end

  class PercentTolerance < RelativeTolerance
    def initialize(value)
      super(value/100)
    end
    def to_s
      "#{descr_value}%"
    end
  end

  class PermilleTolerance < RelativeTolerance
    def initialize(value)
      super(value/1000)
    end
    def to_s
      "#{descr_value}/1000"
    end
  end

  # TODO: special values

  class FloatingTolerance < Tolerance
    def initialize(value, radix=:native)
      super(value)
      @radix = radix
    end

    def to_s
      if @radix==:native
        "#{descr_value} flt."
      else
        "#{descr_value} flt.(#{radix})"
      end
    end

    @float_minimum_normalized_fraction = Math.ldexp(1,-1)
    def self.float_minimum_normalized_fraction
      @float_minimum_normalized_fraction
    end

    def self.ref_adjusted_exp
      -1
    end

    def relative_to_many(mode, *xs)
      exp = nil

      num_class = xs.first.class
      xs = xs.map{|x| num_class.Num(x)} if xs.size>1
      v = cast_value(num_class)

      case xs.first
      when BigFloat::Num
        if @radix == :native || @radix == num_class.radix
          exp = xs.map do |x|
            x = x.normalize
            exp = x.adjusted_exponent
            exp -= 1 if x.coefficient == x.class.context.minimum_normalized_coefficient # if :low mode
            exp -= FloatingTolerance.ref_adjusted_exp
            exp
          end.send(mode)
          num_class.new(+1, v.coefficient, v.exponent+exp)
        elsif @radix==10
          # assert x.class==BinFloat
          raise "Decimal tolerance with BinFloat not yet supported"
        else
          # assert x.class==Decimal && @radix==2
          exp = xs.map do |x|
            exp = (x.ln/Decimal(2).ln).ceil.to_i - 1 # (x.ln/Decimal(2).ln).floor+1 - 1 if :high mode
            exp -= FloatingTolerance.ref_adjusted_exp
            exp
          end.send(mode)
          v*Decimal(2)**exp
        end
      when Float
        if @radix == :native || @radix == Float.context.radix
          exp = xs.map do |x|
            f,e = Math.frexp(x)
            exp = e-1
            exp -= 1 if f==FloatingTolerance.float_minimum_normalized_fraction # if :low mode
            exp -= FloatingTolerance.ref_adjusted_exp
          end.send(mode)
          Math.ldexp(v, exp)
        else
          # assert @radix==10
          exp = xs.map do |x|
            exp = Math.log10(x.abs).ceil - 1 # Math.log10(x.abs).floor+1 - 1 if :high mode
            exp -= FloatingTolerance.ref_adjusted_exp
          end.send(mode)
          v*10.0**exp
        end
      end
    end

  end

  class UlpsTolerance < FloatingTolerance
    def initialize(n=nil, num_class=nil)
      @ulps = n || 1
      num_class ||= Float
      unit = num_class.new(1)
      super(unit.ulp*@ulps)
    end
    def to_s
      "#{ulps} ulp#{ulps > 1 ? 's' : ''}"
    end
    def relative_to(x)
      @ulps*x.ulp
    end
    def relative_to_many(mode, *xs)
      xs.map{|x| relative_to(x)}.send(mode)
    end
  end

  class SigDecimalsTolerance < FloatingTolerance
    def initialize(ndec, rounded = true)
      super Tolerance.decimals(ndec, rounded), 10
      @decimals = ndec
      @rounded = rounded
    end
    def to_s
      "#{@decimals} sig. #{@rounded ? 'r.' : 'r'}dec."
    end
  end


  class DecimalsTolerance < AbsoluteTolerance
    def initialize(ndec, rounded = true)
      super Tolerance.decimals(ndec, rounded)
      @decimals = ndec
      @rounded = rounded
    end
    def to_s
      "#{@decimals} #{@rounded ? 'r.' : 'r'}dec."
    end
  end

  class SigBitsTolerance < FloatingTolerance
    def initialize(ndec, rounded = true)
      super Tolerance.bits(ndec, rounded), 2
      @bits = ndec
      @rounded = rounded
    end
    def to_s
      "#{@bits} sig. #{@rounded ? 'r.' : 'r'}bits"
    end
  end

  module EpsilonMixin
    def initialize(mult=nil)
      @mult = mult || 1
      super nil
    end
    def cast_value(num_class)
      Tolerance.epsilon(x.class, @mult)
    end
    def descr_value
      "#{@mult==1 ? '' : "#{@mult} "} eps."
    end
  end

  class EpsilonTolerance < RelativeTolerance
    include EpsilonMixin
  end

  class AbsEpsilonTolerance < AbsoluteTolerance
    include EpsilonMixin
  end

  class FltEpsilonTolerance < FloatingTolerance
    include EpsilonMixin
  end

  module BigEpsilonMixin
    def initialize(mult=nil)
      @mult = mult || 1
      super nil
    end
    def cast_value(num_class)
      Tolerance.big_epsilon(x.class, @mult)
    end
    def descr_value
      "#{@mult==1 ? '' : "#{@mult} "} big eps."
    end
  end

  class BigEpsilonTolerance < RelativeTolerance
    include BigEpsilonMixin
  end

  class AbsBigEpsilonTolerance < AbsoluteTolerance
    include EpsilonMixin
  end

  class FltBigEpsilonTolerance < FloatingTolerance
    include BigEpsilonMixin
  end

  def Tolerance(*args)
    if args.first.is_a?(Symbol)
      value = nil
    else
      value = args.shift
    end
    cls_name = args.shift.to_s.gsub(/(^|_)(.)/){$2.upcase} + "Tolerance"
    BigFloat.const_get(cls_name).new(value, *args)
  end

end # BigFloat

