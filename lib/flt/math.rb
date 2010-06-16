require 'flt/dec_num'

module Flt

  # Mathematical functions. The angular units used by these functions can be specified
  # with the +angle+ attribute of the context. The accepted values are:
  # * :rad for radians
  # * :deg for degrees
  # * :grad for gradians
  module MathBase

    # Cosine of an angle given in the units specified by DecNum.context.angle.
    def cos(x)
      cos_base(num_class.Num(x))
    end

    # Sine of an angle given in the units specified by DecNum.context.angle.
    def sin(x)
      sin_base(num_class.Num(x))
    end

    # Tangent of an angle given in the units specified by DecNum.context.angle.
    def tan(x)
      tan_base(num_class.Num(x))
    end

    # Arc-tangent. The result is in the units specified by DecNum.context.angle.
    # If the angular units are radians the result is in [-pi/2, pi/2]; it is in [-90,90] in degrees.
    def atan(x)
      atan_base(num_class.Num(x))
    end

    # Arc-tangent with two arguments (principal value of the argument of the complex number x+i*y).
    # The result is in the units specified by DecNum.context.angle.
    # If the angular units are radians the result is in [-pi, pi]; it is in [-180,180] in degrees.
    def atan2(y, x)
      atan2_base(num_class.Num(y), num_class.Num(x))
    end

    # Arc-sine. The result is in the units specified by DecNum.context.angle.
    # If the angular units are radians the result is in [-pi/2, pi/2]; it is in [-90,90] in degrees.
    def asin(x)
      asin_base(num_class.Num(x))
    end

    # Arc-cosine. The result is in the units specified by DecNum.context.angle.
    # If the angular units are radians the result is in [-pi/2, pi/2]; it is in [-90,90] in degrees.
    def acos(x)
      acos_base(num_class.Num(x))
    end

    # Length of the hypotenuse of a right-angle triangle (modulus or absolute value of the complex x+i*y).
    def hypot(x, y)
      hypot_base(num_class.Num(x), num_class.Num(y))
    end

    private

    def cos_base(x)
      x = x.abs
      rev_sign = false
      s = nil
      num_class.context do |local_context|
        local_context.precision += 3 # extra digits for intermediate steps
        x,k,pi_2 = reduce_angle2(x,2)
        rev_sign = true if k>1
        if k % 2 == 0
          x = pi_2 - x
        else
          rev_sign = !rev_sign
        end
        x = to_rad(x)
        i, lasts, fact, num = 1, 0, 1, num_class.Num(x)
        s = num
        x2 = -x*x
        while s != lasts
          lasts = s
          i += 2
          fact *= i * (i-1)
          num *= x2
          s += num / fact
        end
      end
      return rev_sign ? (-s) : (+s)
    end

    def sin_base(x)
      sign = x.sign
      s = nil
      num_class.context do |local_context|
        local_context.precision += 3 # extra digits for intermediate steps
        x = x.abs if sign<0
        x,k,pi_2 = reduce_angle2(x,2)
        sign = -sign if k>1
        x = pi_2 - x if k % 2 == 1
        x = to_rad(x)
        i, lasts, fact, num = 1, 0, 1, num_class.Num(x)
        s = num
        x2 = -x*x
        while s != lasts
          lasts = s
          i += 2
          fact *= i * (i-1)
          num *= x2
          s += num / fact
        end
      end
      return (+s).copy_sign(sign)
    end

    def tan_base(x)
      +num_class.context do |local_context|
        local_context.precision += 2 # extra digits for intermediate steps
        s,c = sin(x), cos(x)
        s/c
      end
    end

    def atan_base(x)
      s = nil
      conversion = true
      extra_prec = num_class.radix==2 ? 4 : 2
      num_class.context do |local_context|
        local_context.precision += extra_prec
        if x == 0
          return DecNum.zero
        elsif x.abs > 1
          if x.infinite?
            s = (quarter_cycle).copy_sign(x)
            conversion = false
            break
          else
            # c = (quarter_cycle).copy_sign(x)
            c = (half*pi).copy_sign(x)
            x = 1 / x
          end
        end
        local_context.precision += extra_prec
        x_squared = x ** 2
        if x_squared.zero? || x_squared.subnormal?
          s = x
          s = c - s if c && c!=0
          break
        end
        y = x_squared / (1 + x_squared)
        y_over_x = y / x
        i = num_class.zero; lasts = 0; s = y_over_x; coeff = 1; num = y_over_x
        while s != lasts
          lasts = s
          i += 2
          coeff *= i / (i + 1)
          num *= y
          s += coeff * num
        end
        if c && c!= 0
          s = c - s
        end
      end
      return conversion ? rad_to(s) : +s
    end

    def atan2_base(y, x)
        abs_y = y.abs
        abs_x = x.abs
        y_is_real = !x.infinite?

        if x != 0
            if y_is_real
                a = y!=0 ? atan(y / x) : num_class.zero
                a += half_cycle.copy_sign(y) if x < 0
                return a
            elsif abs_y == abs_x
                x = num_class.Num(1).copy_sign(x)
                y = num_class.Num(1).copy_sign(y)
                return half_cycle * (2 - x) / (4 * y)
            end
        end

        if y != 0
            return atan(num_class.infinity(y.sign))
        elsif x < 0
            return half_cycle.copy_sign(x)
        else
            return num_class.zero
        end
    end

    def asin_base(x)
      x = +x
      return num_class.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1

        if x == -1
            return -quarter_cycle
        elsif x == 0
            return num_class.zero
        elsif x == 1
            return quarter_cycle
        end

        num_class.context do |local_context|
          local_context.precision += 3
          x = x/(1-x*x).sqrt
          x = atan(x)
        end
        +x
    end

    def acos_base(x)

      return num_class.context.exception(Num::InvalidOperation, 'acos needs -1 <= x <= 2') if x.abs > 1

      if x == -1
          return half_cycle
      elsif x == 0
          return quarter_cycle
      elsif x == 1
          return num_class.zero
      end

      required_precision = num_class.context.precision

      if x < half
        num_class.context(:precision=>required_precision+2) do
          x = x/(1-x*x).sqrt
          x = quarter_cycle - atan(x)
        end
      else
        # valid for x>=0
        num_class.context(:precision=>required_precision+3) do

          # x = (1-x*x).sqrt # x*x may require double precision if x*x is near 1
          x = (1-BinNum.context(:precision=>required_precision*2){x*x}).sqrt

          x = asin(x)
        end
      end
      +x

    end

    def hypot_base(x, y)
      num_class.context do |local_context|
        local_context.precision += 3
        (x*x + y*y).sqrt
      end
    end

    def e(digits=nil)
      num_class.context do |local_context|
        local_context.precision = digits if digits
        num_class.Num(1).exp
      end
    end

    def pi2(decimals=nil)
      decimals ||= DecNum.context.precision
      num_class.context(:precision=>decimals) do
        pi(decimals)*2
      end
    end

    def invpi(decimals=nil)
      decimals ||= DecNum.context.precision
      num_class.context(:precision=>decimals) do
        num_class.Num(1)/pi(decimals)
      end
    end

    def inv2pi(decimals=nil)
      decimals ||= DecNum.context.precision
      num_class.context(:precision=>decimals) do
        num_class.Num(1)/pi2(decimals)
      end
    end

    # class <<self
    #   private

      def iarccot(x, unity)
        xpow = unity / x
        n = 1
        sign = 1
        sum = 0
        loop do
            term = xpow / n
            break if term == 0
            sum += sign * (xpow/n)
            xpow /= x*x
            n += 2
            sign = -sign
        end
        sum
      end

      def modtwopi(x)
        return +num_class.context(:precision=>num_class.context.precision*3){x.modulo(one_cycle)}
      end

      # Reduce angle to [0,2Pi)
      def reduce_angle(a)
        modtwopi(a)
      end

      # Reduce angle to [0,Pi/k0) (result is not rounded to precision)
      def reduce_angle2(a,k0=nil) # divisor of pi or nil for pi*2
        # we could reduce first to pi*2 to avoid the mod k0 operation
        k,r,divisor = DecNum.context do
          num_class.context.precision *= 3
          m = k0.nil? ? one_cycle : half_cycle/k0
          a.divmod(m)+[m]
        end
        [r, k.modulo(k0*2).to_i, divisor]
      end

      def one_cycle
        case num_class.context.angle
        when :rad
          pi2
        when :deg
          num_class.Num(360)
        when :grad
          num_class.Num(400)
        end
      end

      def half_cycle
        case num_class.context.angle
        when :rad
          pi
        when :deg
          num_class.Num(180)
        when :grad
          num_class.Num(200)
        end
      end

      def quarter_cycle
        case DecNum.context.angle
        when :rad
          half*pi
        when :deg
          num_class.Num(90)
        when :grad
          num_class.Num(100)
        end
      end

      def to_rad(x)
        case num_class.context.angle
        when :rad
          +x
        else
          +num_class.context(:precision=>num_class.context.precision+3){x*pi/half_cycle}
        end
      end

      def to_deg(x)
        case num_class.context.angle
        when :deg
          +x
        else
          +num_class.context(:precision=>num_class.context.precision+3){x*num_class.Num(180)/half_cycle}
        end
      end

      def to_grad(x)
        case DecNum.context.angle
        when :deg
          +x
        else
          +num_class.context(:precision=>num_class.context.precision+3){x*num_class.Num(200)/half_cycle}
        end
      end

      def to_angle(angular_units, x)
        return +x if angular_units == num_class.context.angle
        case angular_units
        when :rad
          to_rad(x)
        when :deg
          to_deg(x)
        when :grad
          to_grad(x)
        end
      end

      def rad_to(x)
        case num_class.context.angle
        when :rad
          +x
        else
          +num_class.context(:precision=>num_class.context.precision+3){x*half_cycle/pi}
        end
      end

      def deg_to(x)
        case num_class.context.angle
        when :deg
          +x
        else
          +num_class.context(:precision=>num_class.context.precision+3){x*half_cycle/num_class.Num(180)}
        end
      end

      def grad_to(x)
        case num_class.context.angle
        when :grad
          +x
        else
          +num_class.context(:precision=>num_class.context.precision+3){x*half_cycle/num_class.Num(200)}
        end
      end

      def angle_to(x, angular_units)
        return +x if angular_units == num_class.context.angle
        case angular_units
        when :rad
          rad_to(x)
        when :deg
          deg_to(x)
        when :grad
          grad_to(x)
        end
      end

    #end

  end


  class DecNum

    module Math

      extend Flt # to access constructor methods DecNum

      include MathBase # make available for instance methods
      extend MathBase # make available for class methods

      module Support
        #private
        def num_class
          DecNum
        end

        def half
          num_class.Num('0.5')
        end
      end

      include Support
      extend Support

      module_function


      # Pi
      @@pi_cache = nil # truncated pi digits as a string
      @@pi_cache_digits = 0
      PI_MARGIN = 10
      def pi(round_digits=nil)

        round_digits ||= DecNum.context.precision
        digits = round_digits
          if @@pi_cache_digits <= digits # we need at least one more truncated digit
             continue = true
             while continue
               margin = PI_MARGIN # margin to reduce recomputing with more digits to avoid ending in 0 or 5
               digits += margin + 1
               fudge = 10
               unity = 10**(digits+fudge)
               v = 4*(4*iarccot(5, unity) - iarccot(239, unity))
               v = v.to_s[0,digits]
               # if the last digit is 0 or 5 the truncated value may not be good for rounding
               loop do
                 #last_digit = v%10
                 last_digit = v[-1,1].to_i
                 continue = (last_digit==5 || last_digit==0)
                 if continue && margin>0
                   # if we have margin we back-up one digit
                   margin -= 1
                   v = v[0...-1]
                 else
                   break
                 end
               end
             end
             @@pi_cache_digits = digits + margin - PI_MARGIN # @pi_cache.size
             @@pi_cache = v # DecNum(+1, v, 1-digits) # cache truncated value
          end
          # Now we avoid rounding too much because it is slow
          l = round_digits + 1
          while (l<@@pi_cache_digits) && [0,5].include?(@@pi_cache[l-1,1].to_i)
            l += 1
          end
          v = @@pi_cache[0,l]
          num_class.context(:precision=>round_digits){+num_class.Num(+1,v.to_i,1-l)}
      end


    end # DecNum::Math

    class DecNum::Context
      include DecNum::Math
      public :sin, :cos, :tan, :atan, :asin, :acos, :atan2, :hypot, :pi, :e
    end

    def self.pi
      self::Math.pi
    end

    def self.e
      self::Math.e
    end

  end # DecNum

  class BinNum

    module Math

      extend Flt # to access constructor methods DecNum

      include MathBase # make available for instance methods
      extend MathBase # make available for class methods

      module Support
        #private
        def num_class
          BinNum
        end

        def half
          num_class.Num('0.5')
        end
      end

      include Support
      extend Support

      module_function

      # Pi
      @@pi = nil
      @@pi_cache = [num_class.Num(3), 3, 1, 0, 0, 24]
      @@pi_digits = 0
      def pi(round_digits=nil)
        round_digits ||= num_class.context.precision
        if @@pi_digits < round_digits
          # provisional implementation (very slow)
          lasts = 0
          t, s, n, na, d, da = @@pi_cache
          num_class.context do |local_context|
            local_context.precision = round_digits + 6
            while s != lasts
              lasts = s
              n, na = n+na, na+8
              d, da = d+da, da+32
              t = (t * n) / d
              s += t
            end
          end
          @pi_cache = [t, s, n, na, d, da]
          @@pi = s
          @@pi_digits = round_digits
        end
        num_class.context(:precision=>round_digits){+@@pi}
      end

    end # BinNum::Math

    class BinNum::Context
      include BinNum::Math
      public :sin, :cos, :tan, :atan, :asin, :acos, :atan2, :hypot, :pi, :e
    end

    def self.pi
      self::Math.pi
    end

    def self.e
      self::Math.e
    end

  end # BinNum

end # Flt