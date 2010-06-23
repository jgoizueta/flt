require 'flt/dec_num'

module Flt

  # Trigonometry functions. The angular units used by these functions can be specified
  # with the +angle+ attribute of the context. The accepted values are:
  # * :rad for radians
  # * :deg for degrees
  # * :grad for gradians
  #
  # These functions are injected in Context objects.
  module Trigonometry

    # Cosine of an angle given in the units specified by the context +angle+ attribute.
    def cos(x)
      cos_base(num_class[x])
    end

    # Sine of an angle given in the units specified by the context +angle+ attribute.
    def sin(x)
      sin_base(num_class[x])
    end

    # Tangent of an angle given in the units specified by the context +angle+ attribute.
    def tan(x)
      tan_base(num_class[x])
    end

    # Arc-tangent. The result is in the units specified by the context +angle+ attribute.
    # If the angular units are radians the result is in [-pi/2, pi/2]; it is in [-90,90] in degrees.
    def atan(x)
      atan_base(num_class[x])
    end

    # Arc-tangent with two arguments (principal value of the argument of the complex number x+i*y).
    # The result is in the units specified by the context +angle+ attribute.
    # If the angular units are radians the result is in [-pi, pi]; it is in [-180,180] in degrees.
    def atan2(y, x)
      atan2_base(num_class[y], num_class[x])
    end

    # Arc-sine. The result is in the units specified by the context +angle+ attribute.
    # If the angular units are radians the result is in [-pi/2, pi/2]; it is in [-90,90] in degrees.
    def asin(x)
      asin_base(num_class[x])
    end

    # Arc-cosine. The result is in the units specified by the context +angle+ attribute.
    # If the angular units are radians the result is in [-pi/2, pi/2]; it is in [-90,90] in degrees.
    def acos(x)
      acos_base(num_class[x])
    end

    # Length of the hypotenuse of a right-angle triangle (modulus or absolute value of the complex x+i*y).
    def hypot(x, y)
      hypot_base(num_class[x], num_class[y])
    end

    # Pi
    def pi(round_digits=nil)
      round_digits ||= self.precision
      if Trigonometry.pi_digits < round_digits
        # provisional implementation (very slow)
        lasts = 0
        t, s, n, na, d, da = Trigonometry.pi_cache
        num_class.context(self) do |local_context|
          local_context.precision = round_digits + 6
          tol = Rational(1,num_class.int_radix_power(local_context.precision+1))
          while (s-lasts)>tol
            lasts = s
            n, na = n+na, na+8
            d, da = d+da, da+32
            t = (t * n) / d
            s += t
          end
          Trigonometry.pi_value = num_class[s]
          Trigonometry.pi_digits = round_digits
          Trigonometry.pi_cache = [t, s, n, na, d, da]
        end
      end
      num_class.context(self, :precision=>round_digits){+Trigonometry.pi_value}
    end

    def e(digits=nil)
      num_class.context(self) do |local_context|
        local_context.precision = digits if digits
        num_class.Num(1).exp
      end
    end

    def half
      @half ||= num_class.one_half
    end

    # Hyperbolic sine
    def sinh(x)
      sinh_base(num_class[x])
    end

    # Hyperbolic cosine
    def cosh(x)
      cosh_base(num_class[x])
    end

    # Hyperbolic tangent
    def tanh(x)
      tanh_base(num_class[x])
    end

    # Hyperbolic arcsine
    def asinh(x)
      asinh_base(num_class[x])
    end

    # Hyperbolic arccosine
    def acosh(x)
      acosh_base(num_class[x])
    end

    # Hyperbolic arctangent
    def atanh(x)
      atanh_base(num_class[x])
    end

    protected

    @pi_value = nil
    @pi_digits = 0
    @pi_cache = [Rational(3), Rational(3), 1, 0, 0, 24]
    class <<self
      attr_accessor :pi_value, :pi_digits, :pi_cache
    end

    def cos_base(x)
      x = x.copy_sign(+1) # note that abs rounds; copy_sign does not.
      rev_sign = false
      s = nil
      num_class.context(self) do |local_context|
        local_context.precision += 3 # extra digits for intermediate steps
        x,k,pi_2 = local_context.reduce_angle2(x,2)
        rev_sign = true if k>1
        if k % 2 == 0
          x = pi_2 - x
        else
          rev_sign = !rev_sign
        end
        x = local_context.to_rad(x)
        i, lasts, fact, num = 1, 0, 1, num_class[x]
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
      return rev_sign ? minus(s) : plus(s)
    end

    def sin_base(x)
      sign = x.sign
      s = nil
      num_class.context(self) do |local_context|
        local_context.precision += 3 # extra digits for intermediate steps
        x = x.copy_sign(+1) if sign<0
        x,k,pi_2 = local_context.reduce_angle2(x,2)
        sign = -sign if k>1
        x = pi_2 - x if k % 2 == 1
        x = local_context.to_rad(x)
        i, lasts, fact, num = 1, 0, 1, num_class[x]
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
      return plus(s).copy_sign(sign)
    end

    def tan_base(x)
      plus(num_class.context(self) do |local_context|
        local_context.precision += 2 # extra digits for intermediate steps
        s,c = local_context.sin(x), local_context.cos(x)
        s/c
      end)
    end

    def atan_base(x)
      s = nil
      conversion = true
      extra_prec = num_class.radix==2 ? 4 : 2
      num_class.context(self) do |local_context|
        local_context.precision += extra_prec
        if x == 0
          return num_class.zero
        elsif x.abs > 1
          if x.infinite?
            s = local_context.quarter_cycle.copy_sign(x)
            conversion = false
            break
          else
            # c = (quarter_cycle).copy_sign(x)
            c = (half*local_context.pi).copy_sign(x)
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
      return conversion ? rad_to(s) : plus(s)
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
                one = num_class[1]
                x = one.copy_sign(x)
                y = one.copy_sign(y)
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
      return self.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1

        if x == -1
            return -quarter_cycle
        elsif x == 0
            return num_class.zero
        elsif x == 1
            return quarter_cycle
        end

        num_class.context(self) do |local_context|
          local_context.precision += 3
          x = x/(1-x*x).sqrt
          x = local_context.atan(x)
        end
        +x
    end

    def acos_base(x)

      return self.exception(Num::InvalidOperation, 'acos needs -1 <= x <= 2') if x.abs > 1

      if x == -1
          return half_cycle
      elsif x == 0
          return quarter_cycle
      elsif x == 1
          return num_class.zero
      end

      required_precision = self.precision

      if x < half
        num_class.context(self, :precision=>required_precision+2) do
          x = x/(1-x*x).sqrt
          x = num_class.context.quarter_cycle - num_class.context.atan(x)
        end
      else
        # valid for x>=0
        num_class.context(self, :precision=>required_precision+3) do

          # x = (1-x*x).sqrt # x*x may require double precision if x*x is near 1
          x = (1-num_class.context(self, :precision=>required_precision*2){x*x}).sqrt

          x = num_class.context.asin(x)
        end
      end
      +x

    end

    def hypot_base(x, y)
      +num_class.context(self) do |local_context|
        local_context.precision += 3
        (x*x + y*y).sqrt
      end
    end

    def sinh_base(x)
      sign = x.sign
      s = nil
      num_class.context(self) do |local_context|
        local_context.precision += 3 # extra digits for intermediate steps
        x = x.copy_sign(+1) if sign<0
        if x > 1
          s = half*(x.exp - (-x).exp)
        else
          i, lasts, fact, num = 1, 0, 1, num_class[x]
          s = num
          x2 = x*x
          while s != lasts
            lasts = s
            i += 2
            fact *= i * (i-1)
            num *= x2
            s += num / fact
          end
        end
      end
      return plus(s).copy_sign(sign)
    end

    def cosh_base(x)
      s = nil
      num_class.context(self) do |local_context|
        local_context.precision += 3 # extra digits for intermediate steps
        x = x.copy_sign(+1)
        s = half*(x.exp + (-x).exp)
      end
      return plus(s)
    end

    def tanh_base(x)
      s = nil
      num_class.context(self) do |local_context|
        local_context.precision += 3 # extra digits for intermediate steps
        s = sinh_base(x)/cosh_base(x)
      end
      return plus(s)
    end

    def asinh_base(x)
      sign = x.sign
      x = x.copy_sign(+1)
      s = nil

      num_class.context(self) do |local_context|
        x_squared = x ** 2
        if x_squared.zero? || x_squared.subnormal?
          s = x
        else
          # TODO: more accurate formula for small x: if x<...
          if x.adjusted_exponent >= local_context.precision
            s = local_context.ln(x+x)
          else
            s = local_context.ln(x + local_context.sqrt(x_squared + 1))
          end
        end
      end
      return plus(s).copy_sign(sign)
    end

    def acosh_base(x)

      return self.exception(Num::InvalidOperation, 'acosh needs x >= 1') if x < 1

      x = x.copy_sign(+1)
      s = nil

      num_class.context(self) do |local_context|
        if x == 1
          s = num_class.zero
        else
          if x.adjusted_exponent >= local_context.precision
            s = x+x
          else
            s = x + local_context.sqrt((x+1)*(x-1))
          end
          s = local_context.ln(s)
        end
      end
      return plus(s)
    end

    def atanh_base(x)
      sign = x.sign
      x = x.copy_sign(+1)
      s = nil

      return self.exception(Num::InvalidOperation, 'asinh needs -1 <= x <= 1') if x > 1

      num_class.context(self) do |local_context|
        if x.adjusted_exponent <= -local_context.precision
          s = x
        else
          s = (1 + x) / (1 - x)
          s = half*local_context.ln(s)
        end
      end
      return plus(s).copy_sign(sign)
    end

    def pi2(decimals=nil)
      num_class.context(self, :precision=>decimals) do |local_context|
        local_context.pi*2
      end
    end

    def invpi(decimals=nil)
      num_class.context(self, :precision=>decimals) do |local_context|
        num_class[1]/local_context.pi
      end
    end

    def inv2pi(decimals=nil)
      num_class.context(self, :precision=>decimals) do |local_context|
        num_class.Num(1)/local_context.pi2
      end
    end

    # class <<self
    #   private

      def modtwopi(x)
        return plus(num_class.context(self, :precision=>self.precision*3){x.modulo(one_cycle)})
      end

      # Reduce angle to [0,2Pi)
      def reduce_angle(a)
        modtwopi(a)
      end

      # Reduce angle to [0,Pi/k0) (result is not rounded to precision)
      def reduce_angle2(a,k0=nil) # divisor of pi or nil for pi*2
        # we could reduce first to pi*2 to avoid the mod k0 operation
        k,r,divisor = num_class.context do
          num_class.context.precision *= 3
          m = k0.nil? ? one_cycle : half_cycle/k0
          a.divmod(m)+[m]
        end
        [r, k.modulo(k0*2).to_i, divisor]
      end

      def one_cycle
        case self.angle
        when :rad
          pi2
        when :deg
          num_class.Num(360)
        when :grad
          num_class.Num(400)
        end
      end

      def half_cycle
        case self.angle
        when :rad
          pi(num_class.context.precision)
        when :deg
          num_class.Num(180)
        when :grad
          num_class.Num(200)
        end
      end

      def quarter_cycle
        case self.angle
        when :rad
          half*pi(num_class.context.precision)
        when :deg
          num_class.Num(90)
        when :grad
          num_class.Num(100)
        end
      end

      def to_rad(x)
        case self.angle
        when :rad
          plus(x)
        else
          plus(num_class.context(self, :extra_precision=>3){|lc| x*lc.pi/half_cycle})
        end
      end

      def to_deg(x)
        case self.angle
        when :deg
          plus(x)
        else
          plus(num_class.context(self, :extra_precision=>3){x*num_class[180]/half_cycle})
        end
      end

      def to_grad(x)
        case self.angle
        when :deg
          plus(x)
        else
          plus(num_class.context(self, :extra_precision=>3){x*num_class[200]/half_cycle})
        end
      end

      def to_angle(angular_units, x)
        return plus(x) if angular_units == self.angle
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
        case self.angle
        when :rad
          plus(x)
        else
          plus(num_class.context(self, :extra_precision=>3){|lc| x*half_cycle/lc.pi})
        end
      end

      def deg_to(x)
        case self.angle
        when :deg
          plus(x)
        else
          plus(num_class.context(self, :extra_precision=>3){x*half_cycle/num_class[180]})
        end
      end

      def grad_to(x)
        case self.angle
        when :grad
          plus(x)
        else
          plus(num_class.context(self, :extra_precision=>3){x*half_cycle/num_class[200]})
        end
      end

      def angle_to(x, angular_units)
        return plus(x) if angular_units == self.angle
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

    module Support
      module_function
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
    end

  end # Trigonometry

  Num::ContextBase.class_eval{include Trigonometry}

  class DecNum

    module Trigonometry

      include Flt::Trigonometry::Support

      # Pi
      @pi_cache = nil # truncated pi digits as a string
      @pi_cache_digits = 0
      PI_MARGIN = 10
      class <<self
        attr_accessor :pi_cache, :pi_cache_digits
      end

      def pi(round_digits=nil)
        round_digits ||= self.precision
        digits = round_digits
          if Trigonometry.pi_cache_digits <= digits # we need at least one more truncated digit
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
             Trigonometry.pi_cache_digits = digits + margin - PI_MARGIN # @pi_cache.size
             Trigonometry.pi_cache = v # DecNum(+1, v, 1-digits) # cache truncated value
          end
          # Now we avoid rounding too much because it is slow
          l = round_digits + 1
          while (l<Num[16]::Trigonometry.pi_cache_digits) && [0,5].include?(Trigonometry.pi_cache[l-1,1].to_i)
            l += 1
          end
          v = Trigonometry.pi_cache[0,l]
          num_class.context(self, :precision=>round_digits){+num_class.Num(+1,v.to_i,1-l)}
      end

    end # DecNum::Trigonometry

    DecNum::Context.class_eval{include DecNum::Trigonometry}

  end # DecNum

  Num[16].class_eval do

    module Num[16]::Trigonometry

      extend Flt::Trigonometry::Support

      # Pi
      @pi_cache = nil # truncated pi digits as a string
      @pi_cache_digits = 0
      PI_MARGIN = 10
      class <<self
        attr_accessor :pi_cache, :pi_cache_digits
      end

      # truncated hex digits for rounding hexadecimally at round_digits
      def self.pi_hex_digits(round_digits=nil)
        round_digits ||= self.precision
        digits = round_digits
          if Num[16]::Trigonometry.pi_cache_digits <= digits # we need at least one more truncated digit
             continue = true
             while continue
               margin = PI_MARGIN # margin to reduce recomputing with more digits to avoid ending in 0 or 5
               digits += margin + 1
               fudge = 16
               unity = 16**(digits+fudge)
               v = 4*(4*iarccot(5, unity) - iarccot(239, unity))
               v = v.to_s(16)[0,digits]
               # if the last digit is 0 or 8 the truncated value may not be good for rounding
               loop do
                 #last_digit = v%16
                 last_digit = v[-1,1].to_i(16)
                 continue = (last_digit==8 || last_digit==0)
                 if continue && margin>0
                   # if we have margin we back-up one digit
                   margin -= 1
                   v = v[0...-1]
                 else
                   break
                 end
               end
             end
             Num[16]::Trigonometry.pi_cache_digits = digits + margin - PI_MARGIN # @pi_cache.size
             Num[16]::Trigonometry.pi_cache = v # DecNum(+1, v, 1-digits) # cache truncated value
          end
          # Now we avoid rounding too much because it is slow
          l = round_digits + 1
          while (l<Num[16]::Trigonometry.pi_cache_digits) && [0,8].include?(Num[16]::Trigonometry.pi_cache[l-1,1].to_i(16))
            l += 1
          end
          Num[16]::Trigonometry.pi_cache[0,l]
      end

      def pi(round_digits=nil)
        v = Num[16]::Trigonometry.pi_hex_digits(round_digits)
        l = v.size
        num_class.context(self, :precision=>round_digits){+num_class.Num(+1,v.to_i(16),1-l)}
      end

    end # Num[16]::Trigonometry

    Num[16]::Context.class_eval{include Num[16]::Trigonometry}

  end # Num[16]

  class BinNum
    module Trigonometry
      def pi(round_digits=nil)
        round_digits ||= self.precision
        nhexd = (round_digits+3)/4 + 1
        v = Num[16]::Trigonometry.pi_hex_digits(nhexd)
        l = v.size
        v = v.to_i(16)
        e = (1-l)*4
        # add trailing 01 for rounding (there always be some non null digit beyond the rounding point)
        v <<= 2
        v |= 1
        e -= 2
        num_class.context(self, :precision=>round_digits){+num_class.Num(+1,v,e)}
      end
    end
    BinNum::Context.class_eval{include BinNum::Trigonometry}
  end

end # Flt