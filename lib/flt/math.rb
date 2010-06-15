require 'flt/dec_num'

module Flt
  class DecNum
    module Math

      extend Flt # to access constructor methods DecNum

      module_function

      # Trigonometry

      HALF = DecNum('0.5')

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
          DecNum.context(:precision=>round_digits){+DecNum(+1,v.to_i,1-l)}
      end

      def e(decimals=nil)
        DecNum.context do |local_context|
          local_context.precision = decimals if decimals
          DecNum(1).exp
        end
      end

      # Cosine of an angle given in the units specified by DecNum.context.angle:
      # * :rad for radians
      # * :deg for degrees
      # * :grad for gradians
      def cos(x)
        x = x.abs
        rev_sign = false
        s = nil
        DecNum.context do |local_context|
          local_context.precision += 3 # extra digits for intermediate steps
          x,k,pi_2 = reduce_angle2(x,2)
          rev_sign = true if k>1
          if k % 2 == 0
            x = pi_2 - x
          else
            rev_sign = !rev_sign
          end
          x = to_rad(x)
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
        return rev_sign ? (-s) : (+s)
      end

      # Sine of an angle given in the units specified by DecNum.context.angle:
      # * :rad for radians
      # * :deg for degrees
      # * :grad for gradians
      def sin(x)
        sign = x.sign
        s = nil
        DecNum.context do |local_context|
          local_context.precision += 3 # extra digits for intermediate steps
          x = x.abs if sign<0
          x,k,pi_2 = reduce_angle2(x,2)
          sign = -sign if k>1
          x = pi_2 - x if k % 2 == 1
          x = to_rad(x)
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
        return (+s).copy_sign(sign)
      end

      # Tangent of an angle
      def tan(x)
        +DecNum.context do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
          s,c = sin(x), cos(x)
          s/c
        end
      end

      # Arc-tangent in units specified by DecNum.context.angle
      def atan(x)
        s = nil
        conversion = true
        DecNum.context do |local_context|
          local_context.precision += 2
          if x == 0
            return DecNum.zero
          elsif x.abs > 1
            if x.infinite?
              s = (quarter_cycle).copy_sign(x)
              conversion = false
              break
            else
              # c = (quarter_cycle).copy_sign(x)
              c = (HALF*pi).copy_sign(x)
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
        return conversion ? rad_to(s) : +s
      end

      def atan2(y, x)
          abs_y = y.abs
          abs_x = x.abs
          y_is_real = !x.infinite?

          if x != 0
              if y_is_real
                  a = y!=0 ? atan(y / x) : DecNum.zero
                  a += half_cycle.copy_sign(y) if x < 0
                  return a
              elsif abs_y == abs_x
                  x = DecNum(1).copy_sign(x)
                  y = DecNum(1).copy_sign(y)
                  return half_cycle * (2 - x) / (4 * y)
              end
          end

          if y != 0
              return atan(DecNum.infinity(y.sign))
          elsif x < 0
              return half_cycle.copy_sign(x)
          else
              return DecNum.zero
          end
      end

      def asin(x)
        x = +x
        return DecNum.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1

          if x == -1
              return -quarter_cycle
          elsif x == 0
              return DecNum.zero
          elsif x == 1
              return quarter_cycle
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
            return half_cycle
        elsif x == 0
            return quarter_cycle
        elsif x == 1
            return DecNum.zero
        end

        if x < HALF
          DecNum.context do |local_context|
            local_context.precision += 3
            x = x/(1-x*x).sqrt
            x = quarter_cycle - atan(x)
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

      def hypot(x, y)
        DecNum.context do |local_context|
          local_context.precision += 3
          (x*x + y*y).sqrt
        end
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
          return +DecNum.context(:precision=>DecNum.context.precision*3){x.modulo(one_cycle)}
        end

        # Reduce angle to [0,2Pi)
        def reduce_angle(a)
          modtwopi(a)
        end

        # Reduce angle to [0,Pi/k0) (result is not rounded to precision)
        def reduce_angle2(a,k0=nil) # divisor of pi or nil for pi*2
          # we could reduce first to pi*2 to avoid the mod k0 operation
          k,r,divisor = DecNum.context do
            DecNum.context.precision *= 3
            m = k0.nil? ? one_cycle : half_cycle/k0
            a.divmod(m)+[m]
          end
          [r, k.modulo(k0*2).to_i, divisor]
        end

        def one_cycle
          case DecNum.context.angle
          when :rad
            pi2
          when :deg
            DecNum(360)
          when :grad
            DecNum(400)
          end
        end

        def half_cycle
          case DecNum.context.angle
          when :rad
            pi
          when :deg
            DecNum(180)
          when :grad
            DecNum(200)
          end
        end

        def quarter_cycle
          case DecNum.context.angle
          when :rad
            HALF*pi
          when :deg
            DecNum(90)
          when :grad
            DecNum(100)
          end
        end

        def to_rad(x)
          case DecNum.context.angle
          when :rad
            +x
          else
            +DecNum.context(:precision=>DecNum.context.precision+3){x*pi/half_cycle}
          end
        end

        def to_deg(x)
          case DecNum.context.angle
          when :deg
            +x
          else
            +DecNum.context(:precision=>DecNum.context.precision+3){x*DecNum(180)/half_cycle}
          end
        end

        def to_grad(x)
          case DecNum.context.angle
          when :deg
            +x
          else
            +DecNum.context(:precision=>DecNum.context.precision+3){x*DecNum(200)/half_cycle}
          end
        end

        def to_angle(angular_units, x)
          return +x if angular_units == DecNum.context.angle
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
          case DecNum.context.angle
          when :rad
            +x
          else
            +DecNum.context(:precision=>DecNum.context.precision+3){x*half_cycle/pi}
          end
        end

        def deg_to(x)
          case DecNum.context.angle
          when :deg
            +x
          else
            +DecNum.context(:precision=>DecNum.context.precision+3){x*half_cycle/DecNum(180)}
          end
        end

        def grad_to(x)
          case DecNum.context.angle
          when :grad
            +x
          else
            +DecNum.context(:precision=>DecNum.context.precision+3){x*half_cycle/DecNum(200)}
          end
        end

        def angle_to(x, angular_units)
          return +x if angular_units == DecNum.context.angle
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
          Num::ContextBase.class_eval do
            define_method f do |*args|
              Math.send(f, *args.map{|x| Num(x)})
              # x = Num(args.shift)
              # Math.send(f, x, *args)
            end
          end
        end
      end
    end

    math_function :sin, :cos, :tan, :atan, :asin, :acos, :atan2, :hypot
    math_function :pi, :e

    def self.pi
      Math.pi
    end

    def self.e
      Math.e
    end

  end # DecNum
end # Flt