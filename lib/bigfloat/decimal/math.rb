require 'bigfloat/decimal'

module BigFloat
  class Decimal
    module Math
      module_function

      # Trinogometry

      # Pi
      def pi()
        three = Decimal(3)      # substitute "three=3.0" for regular floats
        lasts, t, s, n, na, d, da = 0, three, 3, 1, 0, 0, 24
        Decimal.context do |local_context|
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
        Decimal.context do |local_context|
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
        Decimal.context do |local_context|
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

    end # Math
  end # Decimal
end # BigFloat