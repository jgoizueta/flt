require 'flt/dec_num'

# TODO: convert arguments as Context#_convert does, to accept non DecNum arguments

module Flt
  class DecNum
    module Math

      extend Flt # to access constructor methods DecNum

      module_function

      # Trinogometry

      # Pi
      def pi(decimals=nil)
        three = DecNum(3)
        lasts, t, s, n, na, d, da = 0, three, 3, 1, 0, 0, 24
        Flt::DecNum.context(:precision=>decimals) do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
          while s != lasts
            lasts = s
            n, na = n+na, na+8
            d, da = d+da, da+32
            t = (t * n) / d
            s += t
          end
        end
        return +s
      end

      def e(decimals=nil)
        DecNum.context do |local_context|
          local_context.precision = decimals if decimals
          DecNum(1).exp
        end
      end

      # TODO: reduce angular arguments

      # Cosine of angle in radians
      def cos(x)
        i, lasts, s, fact, num = 0, 0, 1, 1, 1
        DecNum.context do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
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

      # Sine of angle in radians
      def sin(x)
        i, lasts, s, fact, num = 1, 0, x, 1, x
        DecNum.context do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
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

      def sincos(x) # TODO: use cos(x) = sqrt(1-sin(x)**2)
        s = DecNum(0)
        c = DecNum(1)
        DecNum.context do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
           x = x.divmod(2 * pi)[1]

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

      def tan(x)
        +DecNum.context do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
          s,c = sincos(x)
          s/c
        end
      end


      # this was slower
      # def atan(x)
      #   s = nil
      #   DecNum.context do |local_context|
      #     local_context.precision += 2
      #     if x == 0
      #       return DecNum.zero
      #     elsif x.abs > 1
      #       if x.infinite?
      #         s = pi / DecNum(x.sign, 2, 0)
      #         break
      #       else
      #         c = (pi / 2).copy_sign(x)
      #         x = 1 / x
      #       end
      #     end
      #     local_context.precision += 2
      #     x_squared = x ** 2
      #     y = x_squared / (1 + x_squared)
      #     y_over_x = y / x
      #     i = DecNum.zero; lasts = 0; s = y_over_x; coeff = 1; num = y_over_x
      #     while s != lasts
      #       lasts = s
      #       i += 2
      #       coeff *= i / (i + 1)
      #       num *= y
      #       s += coeff * num
      #     end
      #     if c && c!= 0
      #       s = c - s
      #     end
      #   end
      #   return +s
      # end

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
                  return pi(context=context) * (2 - x) / (4 * y)
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

      # def asin(x)
      #   return DecNum.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1
      #
      #     if x == -1:
      #         return pi / -2
      #     elsif x == 0
      #         return DecNum.zero
      #     elsif x == 1
      #         return pi / 2
      #     end
      #
      #     return atan2(x, (DecNum(1)-x**2).sqrt)
      # end
      #
      # def acos(x)
      #   return DecNum.context.exception(Num::InvalidOperation, 'acos needs -1 <= x <= 1') if x.abs > 1
      #
      #     if x == -1:
      #         return pi
      #     elsif x == 0
      #         return pi / 2
      #     elsif x == 1
      #         return DecNum.zero
      #     end
      #
      #     return pi/2 - atan2(x, (DecNum(1)-x**2).sqrt)
      # end


      # def asin(x)
      #   return DecNum.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1
      #   z = nil
      #   DecNum.context do |local_context|
      #     local_context.precision += 2
      #     y = x
      #
      #     # scale argument for faster convergence
      #
      #     z = nil
      #     3.times do
      #       z = (1 - DecNum.context.sqrt(1-y*y))/2
      #       y = DecNum.context.sqrt(z)
      #     end
      #     n = 1
      #
      #     z = y/DecNum.context.sqrt(n - z)
      #
      #     y = z
      #
      #     ok = true
      #     while ok
      #       z = -z
      #       n += 2
      #
      #       next_y = y + (z**n)/n # the ** is slow!
      #
      #       ok = (y != next_y)
      #       y = next_y
      #     end
      #
      #     z = y*8
      #     z = -z if x <= y
      #   end
      #   +z
      #
      # end

      def asin(x)
        return DecNum.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1
        z = nil
        DecNum.context do |local_context|
          local_context.precision += 2
          y = x

          # scale argument for faster convergence

          z = nil
          3.times do
            z = (1 - DecNum.context.sqrt(1-y*y))/2
            y = DecNum.context.sqrt(z)
          end
          n = 1

          z = y/DecNum.context.sqrt(n - z)
          y = z
          k = -z*z

          ok = true
          while ok
            n += 2
            z *= k
            next_y = y + z/n
            ok = (y != next_y)
            y = next_y
          end

          z = y*8
          z = -z if x <= y
        end
        +z

      end

      def atan(x)
        DecNum.context do |local_context|
          local_context.precision += 2
          x = x/(1+x*x).sqrt
        end
        asin(x)
      end

      def acos(x)
        return DecNum.context.exception(Num::InvalidOperation, 'acos needs -1 <= x <= 2') if x.abs > 1
        DecNum.context do |local_context|
          local_context.precision += 2
          x = (1-x*x).sqrt
        end
        asin(x)
      end

      # TODO: degrees mode or radians/degrees conversion

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

    math_function :sin, :cos, :tan, :atan

    def pi
      Math.pi
    end

    def e
      Math.e
    end

  end # DecNum
end # Flt