require 'flt/dec_num'

module Flt
  class DecNum
    module Math

      extend Flt # to access constructor methods DecNum

      module_function

      # Trigonometry

      HALF = DecNum('0.5')

      # Pi
      @pi_cache = nil # truncated pi digits as a string
      @pi_cache_digits = 0
      class << self
        attr_accessor :pi_cache, :pi_cache_digits
      end
      PI_MARGIN = 10
      def pi(round_digits=nil)

        round_digits ||= DecNum.context.precision
        digits = round_digits
          if Math.pi_cache_digits <= digits # we need at least one more truncated digit
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
             Math.pi_cache_digits = digits + margin - PI_MARGIN # Math.pi_cache.size
             Math.pi_cache = v # DecNum(+1, v, 1-digits) # cache truncated value
          end
          # Now we avoid rounding too much because it is slow
          l = round_digits + 1
          while (l<Math.pi_cache_digits) && [0,5].include?(Math.pi_cache[l-1,1].to_i)
            l += 1
          end
          v = Math.pi_cache[0,l]
          DecNum.context(:precision=>round_digits){+DecNum(+1,v.to_i,1-l)}
      end

      def e(decimals=nil)
        DecNum.context do |local_context|
          local_context.precision = decimals if decimals
          DecNum(1).exp
        end
      end

      # Cosine of angle in radians
      def cos(x)
        x = x.copy_sign(+1)
        x, k, pi_4 = reduce_angle2(x, 4)
        x = pi_4 - x if (k % 2)==1 # we need at least twice the precision digits in pi_3; we have thrice.
        s = case k
        when 0
          # cos(x)
          cos_series(+x)
        when 1
          # sin(pi/2-x)
          sin_series(+x)
        when 2
          # -sin(x-pi/2)
          -sin_series(+x)
        when 3
          # -cos(pi-x)
          -cos_series(+x)
        when 4
          # -cos(x-pi)
          -cos_series(+x)
        when 5
          # -sin(3*pi/2-x)
          -sin_series(+x)
        when 6
          # sin(x-3*pi/2)
          sin_series(+x)
        when 7
          # cos(2*pi-x)
          cos_series(+x)
        end
        +s
      end

      # Sine of angle in radians
      def sin(x)
        sign = x.sign
        x = x.copy_sign(+1)
        x, k, pi_4 = reduce_angle2(x, 4)
        x = pi_4 - x if (k % 2)==1 # we need at least twice the precision digits in pi_3; we have thrice.
        s = case k
        when 0
          # sin(x)
          sin_series(+x)
        when 1
          # cos(pi/2-x)
          cos_series(+x)
        when 2
          # cos(x-pi/2)
          cos_series(+x)
        when 3
          # sin(pi-x)
          sin_series(+x)
        when 4
          # -sin(x-pi)
          -sin_series(+x)
        when 5
          # -cos(3*pi/2-x)
          -cos_series(+x)
        when 6
          # -cos(x-3*pi/2)
          -cos_series(+x)
        when 7
          # -sin(2*pi-x)
          -sin_series(+x)
        end
        s = -s if sign<0 # s = s.copy_sign(sign*s.sign)
        s
      end

      def sincos(x)
        sign = x.sign
        x = x.copy_sign(+1)
        x, k, pi_4 = reduce_angle2(x, 4)
        x = pi_4 - x if (k % 2)==1 # we need at least twice the precision digits in pi_3; we have thrice.
        s,c = sincos_series(+x)
        s,c = case k
        when 0
          [s,c]
        when 1
          [c,s]
        when 2
          [c,-s]
        when 3
          [s,-c]
        when 4
          [-s,-c]
        when 5
          [-c,-s]
        when 6
          [-c,s]
        when 7
          [-s,c]
        end
        s = -s if sign<0
        [s,c]
      end

      def tan(x)
        +DecNum.context do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
          # s,c = sincos(2*x)
          # s/(c+1)

          # sec = 1/c
          # (sec*sec - 1).sqrt

          s,c = sincos(x)
          s/c
        end
      end

      # Inverse trigonometric functions 1: reference implementation

      # Arc-tangent.
      def atan(x)
        s = nil
        DecNum.context do |local_context|
          local_context.precision += 2
          if x == 0
            return DecNum.zero
          elsif x.abs > 1
            if x.infinite?
              s = (pi*HALF).copy_sign(x)
              break
            else
              c = (pi*HALF).copy_sign(x)
              x = 1 / x
            end
          end
          local_context.precision += 2
          x_squared = x ** 2
          y = x_squared / (1 + x_squared)
          y_over_x = y / x
          i = DecNum.zero; lasts = 0; s = y_over_x; coeff = 1; num = y_over_x
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
        return +s
      end

      def atan2(y, x)
          abs_y = y.abs
          abs_x = x.abs
          y_is_real = !x.infinite?

          if x != 0
              if y_is_real
                  a = y!=0 ? atan(y / x) : DecNum.zero
                  a += pi.copy_sign(y) if x < 0
                  return a
              elsif abs_y == abs_x
                  x = DecNum(1).copy_sign(x)
                  y = DecNum(1).copy_sign(y)
                  return pi * (2 - x) / (4 * y)
              end
          end

          if y != 0
              return atan(DecNum.infinity(y.sign))
          elsif x < 0
              return pi.copy_sign(x)
          else
              return DecNum.zero
          end
      end

      def asin(x)
        x = +x
        return DecNum.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1

          if x == -1
              return -pi*HALF
          elsif x == 0
              return DecNum.zero
          elsif x == 1
              return pi*HALF
          end

          DecNum.context do |local_context|
            local_context.precision += 3
            x = x/(1-x*x).sqrt
            x = atan(x)
          end
          +x
      end

      def acos(x)

        return DecNum.context.exception(Num::InvalidOperation, 'acos needs -1 <= x <= 2') if x.abs > 1

        if x == -1
            return pi
        elsif x == 0
            return +DecNum.context(:precision=>DecNum.context.precision+3){pi*HALF}
        elsif x == 1
            return DecNum.zero
        end

        if x < HALF
          DecNum.context do |local_context|
            local_context.precision += 3
            x = x/(1-x*x).sqrt
            x = pi*HALF - atan(x)
          end
        else
          # valid for x>=0
          DecNum.context do |local_context|
            local_context.precision += 3
            x = (1-x*x).sqrt
            x = asin(x)
          end
        end
        +x

      end

      # TODO: add angular units to context; add support for degrees

      def pi2(decimals=nil)
        decimals ||= DecNum.context.precision
        DecNum.context(:precision=>decimals) do
          pi(decimals)*2
        end
      end

      def invpi(decimals=nil)
        decimals ||= DecNum.context.precision
        DecNum.context(:precision=>decimals) do
          DecNum(1)/pi(decimals)
        end
      end

      def inv2pi(decimals=nil)
        decimals ||= DecNum.context.precision
        DecNum.context(:precision=>decimals) do
          DecNum(1)/pi2(decimals)
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
          return +DecNum.context(:precision=>DecNum.context.precision*3){x.modulo(pi2)}
        end

        # Reduce angle to [0,2Pi)
        def reduce_angle(a)
          modtwopi(a)
        end

        # Reduce angle to [0,Pi/k0) (result is not rounded to precision)
        def reduce_angle2(a,k0=nil) # divisor of pi or nil for pi*2
          # we could reduce first to pi*2 to avoid the mod k0 operation
          k,r, divisor = DecNum.context do
            DecNum.context.precision *= 3
            m = k0.nil? ? pi2 : pi/k0
            k0 = k0.nil? ?   1 : 2*k0
            a.divmod(m) + [m]
          end
          [r, k.modulo(k0).to_i, divisor]
        end

      #end

      def cos_series(x)
        s = nil
        DecNum.context do |local_context|
          local_context.precision += 3 # extra digits for intermediate steps

          i, lasts, fact, num = 0, 0, 1, DecNum(1)
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
        return +s
      end

      def sin_series(x) # inaccurate near pi
        s = nil
        DecNum.context do |local_context|
          local_context.precision += 3

          i, lasts, fact, num = 1, 0, 1, DecNum(x)
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
        return +s
      end

      def sincos_series(x)
        s = DecNum(0)
        c = DecNum(1)
        DecNum.context do |local_context|
          local_context.precision += 3

           i = 1
           done_s = false; done_c = false

           d = 1
           f = 1
           sign = 1
           num = x
           while (!done_s && !done_c)
               new_s = s + sign * num / f
               d += 1
               f *= d
               sign = -sign
               num *= x
               new_c = c + sign * num / f
               d += 1
               f *= d
               num *= x
               done_c = true if (new_c - c == 0)
               done_s = true if (new_s - s == 0)
               c = new_c
               s = new_s
               i = i + 2
           end
        end
        return +s, +c
      end

    end # Math

    class <<self
      private
      # declare math functions and inject them into the context class
      def math_function(*functions)
        functions.each do |f|
          # TODO: consider injecting the math methods into the numeric class
          # define_method(f) do |*args|
          #   Math.send(f, self, *args)
          # end
          Num::ContextBase.send :define_method,f do |*args|
            x = Num(args.shift)
            Math.send(f, x, *args)
          end
        end
      end
    end

    math_function :sin, :cos, :tan, :atan, :asin, :acos

    def pi
      Math.pi
    end

    def e
      Math.e
    end

  end # DecNum
end # Flt