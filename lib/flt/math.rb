require 'flt/dec_num'

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

      # Cosine of angle in radians
      def cos(x)
        i, lasts, s, fact, num, sign = 0, 0, 1, 1, 1, 1
        DecNum.context do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
          while s != lasts
            lasts = s
            i += 2
            fact *= i * (i-1)
            num *= x * x
            sign *= -1
            s += num / fact * sign
          end
        end
        return +s
      end

      # Sine of angle in radians
      def sin(x)
        i, lasts, s, fact, num, sign = 1, 0, x, 1, x, 1
        DecNum.context do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
          while s != lasts
            lasts = s
            i += 2
            fact *= i * (i-1)
            num *= x * x
            sign *= -1
            s += num / fact * sign
          end
        end
        return +s
      end

      def tan(x)
        sin(x)/cos(x)
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

    math_function :sin, :cos, :tan

    def pi
      Math.pi(precision)
    end

  end # DecNum
end # Flt