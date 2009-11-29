require 'flt/dec_num'

# TODO: convert arguments as Context#_convert does, to accept non DecNum arguments
# TODO: tests!

module Flt
  class DecNum
    module Math

      extend Flt # to access constructor methods DecNum

      module_function

      # Trigonometry

      HALF = DecNum('0.5')

      # Pi
      $no_cache = false
      @pi_cache = nil # truncated pi digits as a string
      @pi_cache_digits = 0
      PI_MARGIN = 10
      def pi(round_digits=nil)

        round_digits ||= DecNum.context.precision
        digits = round_digits
          if @pi_cache_digits <= digits # we need at least one more truncated digit
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
             @pi_cache_digits = digits + margin - PI_MARGIN # @pi_cache.size
             @pi_cache = v # DecNum(+1, v, 1-digits) # cache truncated value
          end
          # Now we avoid rounding too much because it is slow
          l = round_digits + 1
          while (l<@pi_cache_digits) && [0,5].include?(@pi_cache[l-1,1].to_i)
            l += 1
          end
          v = @pi_cache[0,l]
          DecNum.context(:precision=>round_digits){+DecNum(+1,v.to_i,1-l)}
      end

      def e(decimals=nil)
        DecNum.context do |local_context|
          local_context.precision = decimals if decimals
          DecNum(1).exp
        end
      end

      # TODO: reduce angular arguments
      # TODO: better sin,cos precision

      # Cosine of angle in radians
      # for x = 1.57079646018 RPL gives the correct answer -1.33385103381E-7 but this gives -1.33385104123E-7
      def cos(x) # inaccurate near pi/2
        # c = nil
        # DecNum.context do |local_context|
        #   local_context.precision += 3 # extra digits for intermediate steps
        #   x = reduce_angle(x)
        #   c = sin(x+pi/2)
        # end
        # return +c
        s = nil
        DecNum.context do |local_context|
          local_context.precision += 3 # extra digits for intermediate steps
          x = reduce_angle(x)
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

      # Sine of angle in radians
      # TODO: try this:
      #  reduce to [0,pi/2] (keep quadrant information)
      #    using: sin(x) == -sin(-x); sin(a+b) = sin(a)*cos(b)+cos(a)*sin(b); ...
      #  reduce further to some limit by dividing by 3 k times
      #  compute the series with extra precision (double?)
      #  undo second reduction by aplying sin(3a)=sin(a)*(3-4*sin(a)^2) k times
      #  compute sin using quadrant information
      def sin(x) # inaccurate near pi
        s = nil
        DecNum.context do |local_context|
          local_context.precision += 3 # extra digits for intermediate steps
          x = reduce_angle(x)
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

      # NOTE: currently sincos is a little too slow (sin+cos seems faster)
      # both sincos and sin,cos are sometimes slightly innacurate (1ulp) and they're differently inacurate
      def sincos(x) # TODO: use cos(x) = sqrt(1-sin(x)**2) ? # this is slow
        # for x = 1.57079646018 RPL gives the correct answer for sin -1.33385103381E-7 but this gives -1.33385104123E-7
        s = DecNum(0)
        c = DecNum(1)
        DecNum.context do |local_context|
          local_context.precision += 3 # extra digits for intermediate steps
          x = reduce_angle(x)

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
        # for x = 1.57079646018 RPL gives the correct answer-7497089.06508 but this gives -7497089.06279
        # it needs 5 extra digits rather than 2 to get the correct result
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

      # Inverse trigonometric functions 1: reference implementation (accurate enough)
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

      def acos(x) # less accurate than asin (has problems near x=1)

        # We can compute acos(x) = pi/2 - asin(x)
        # but we must take care with x near 1, where that formula would cause loss of precision

        return DecNum.context.exception(Num::InvalidOperation, 'acos needs -1 <= x <= 2') if x.abs > 1

        if x == -1
            return pi
        elsif x == 0
            return +DecNum.context(:precision=>DecNum.context.precision+3){pi*HALF}
        elsif x == 1
            return DecNum.zero
        end

        # some identities:
        #   acos(x) = pi/2 - asin(x) # (but this losses accuracy near x=+1)
        #   acos(x) = pi/2 - atan(x/(1-x*x).sqrt) # this too
        #   acos(x) = asin((1-x*x).sqrt) for x>=0; for x<=0  acos(x) = pi/2 - asin((1-x*x).sqrt)

        if x < HALF
          DecNum.context do |local_context|
            local_context.precision += 3
            x = x/(1-x*x).sqrt
            x = pi*HALF - atan(x)
          end
        else
          # valid for x>=0
          DecNum.context do |local_context|
            local_context.precision += 3 # 2
            x = (1-x*x).sqrt
            x = asin(x)
          end
        end
        +x

      end

      # Inverse trigonometric functions 2: experimental optimizations

      # twice as fast, but slightly less precise in some cases
      def asin_(x)
        return DecNum.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1
        z = nil
        DecNum.context do |local_context|
          local_context.precision += 3
          y = x

          # scale argument for faster convergence

          exp = x.adjusted_exponent
          if exp <= -2
            nt = 0
          else
            nt = 3
          end

          z = y*y
          nt.times do
            #$asin_red += 1
            #z = (1 - DecNum.context.sqrt(1-z))/2
            z = (- DecNum.context.sqrt(-z+1) + 1)/2
          end
          y = DecNum.context.sqrt(z)
          n = 1

          z = y/DecNum.context.sqrt(n - z)
#          puts "asin_ #{x} nt=#{nt} y=#{y} z=#{z}"
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

          if nt==3
            z = y*8
            z = -z if x <= y
          else
            z = y
          end
        end
        +z

      end

      def atan_(x) # bad precision for large x absolute value
        DecNum.context do |local_context|
          local_context.precision += 3
          x = x/(1+x*x).sqrt
        end
        asin_(x)
      end

      # TODO: analogous implementation of acos for testing
      def asin__(x)
        return DecNum.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1
        z = nil
        lim = DecNum('0.1') # DecNum('0.2') is enough; DecNum('0.1') trades reduction iterations for taylor series iterations
        DecNum.context do |local_context|
          local_context.precision += 3
          y = x


          s = 1
          y2 = nil
          h = HALF
          while y.abs > lim
            #$asin__red += 1
            #s *= 2
            s += s

            y2 = ((1 - DecNum.context.sqrt(1-(y2 || y*y)))/2)
            y = y2.sqrt # this could be avoided except for last iteration as in asin_
          end
          n = 1

          z = y/DecNum.context.sqrt(n - (y2 || y*y))
          #puts "asin__ #{x} k=#{s} y=#{y} z=#{z}"
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

          if s!=1
            z = y*s
            z = -z if x <= y
          else
            z = y
          end
        end
        +z

      end


      # this is practically as precise as atan and a little faster
      def atan__(x)
        # TODO: Nan's...
        s = nil
        DecNum.context do |local_context|
          local_context.precision += 3
          piby2 = pi*HALF
          if x.infinite?
            s = (piby2).copy_sign(x)
            break
          end
          neg = (x.sign==-1)
          a = neg ? -x : x

          invert = (a>1)
          a = DecNum(1)/a if invert

          lim = DecNum('0.1')
          #k = 1
          dbls = 0
          while a > lim
            dbls += 1
            #k += k
            a = a/((a*a+1).sqrt+1)
          end

          a2 = -a*a
          t = a2
          s = 1 + t/3
          j = 5

          fin = false
          while !fin
            t *= a2
            d = t/j
            #break if d.zero?
            old_s = s
            s += d
            fin = (s==old_s)
            j += 2
          end
          s *= a

          #s *= k
          dbls.times  do
            s += s
          end

          s = piby2-s if invert
          s = -s if neg
        end

        +s

      end


      # TODO: degrees mode or radians/degrees conversion

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
          # This seems to be slower and less accurate:
          # prec = DecNum.context.precision
          # pi_2 = pi2(prec*2)
          # return x if x < pi_2
          # ex = x.fractional_exponent
          # DecNum.context do |local_context|
          #   # x.modulo(pi_2)
          #   local_context.precision *= 2
          #   if ex > prec
          #     # consider exponent separately
          #     fd = nil
          #     excess = ex - prec
          #     x = x.scaleb(prec-ex)
          #     # now obtain 2*prec digits from inv2pi after the initial excess digits
          #     digits = nil
          #     inv_2pi = inv2pi(local_context.precision+excess)
          #     DecNum.context do |extended_context|
          #       extended_context.precision += excess
          #       digits = (inv2pi.scaleb(excess)).fraction_part
          #     end
          #     x *= digits*pi_2
          #   end
          #   # compute the fractional part of the division by 2pi
          #   inv_2pi ||= inv2pi
          #   x = pi_2*((x*inv2pi).fraction_part)
          # end
          # +x
        end

        def reduce_angle(a)
          # TODO: reduce to pi/k; with quadrant information
          modtwopi(a)
        end

        def reduce_angle2(a,k0=nil) # divisor of pi or nil for pi*2
          # we could reduce first to pi*2 to avoid the mod k0 operation
          k,r = DecNum.context do
            DecNum.context.precision *= 3
            m = k0.nil? ? pi2 : pi/k0
            a.divmod(k)
          end
          [+r, k.modulo(k0).to_i]
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