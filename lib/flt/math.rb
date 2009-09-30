require 'flt/dec_num'

# TODO: convert arguments as Context#_convert does, to accept non DecNum arguments
# TODO: tests!

module Flt
  class DecNum
    module Math

      extend Flt # to access constructor methods DecNum

      module_function

      # Trigonometry

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
      def cos(x)
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
      def sin(x)
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
        +DecNum.context do |local_context|
          local_context.precision += 2 # extra digits for intermediate steps
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
              s = pi / DecNum(x.sign, 2, 0)
              break
            else
              c = (pi / 2).copy_sign(x)
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


      def asin(x)
        x = +x
        return DecNum.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1

          if x == -1
              return pi / -2
          elsif x == 0
              return DecNum.zero
          elsif x == 1
              return pi / 2
          end

          DecNum.context do |local_context|
            local_context.precision += 3
            x = x/(1-x*x).sqrt
          end
          atan(x)
      end

      def acos(x)
        x = +x
        return DecNum.context.exception(Num::InvalidOperation, 'acos needs -1 <= x <= 1') if x.abs > 1

          if x == -1
              return pi
          elsif x == 0
              return pi / 2
          elsif x == 1
              return DecNum.zero
          end

          DecNum.context do |local_context|
            local_context.precision += 3
            x = x/(1-x*x).sqrt
          end

          pi/2 - atan(x) # should use extra precision for this?
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

      def acos_(x)
        return DecNum.context.exception(Num::InvalidOperation, 'acos needs -1 <= x <= 2') if x.abs > 1
        DecNum.context do |local_context|
          local_context.precision += 2
          x = (1-x*x).sqrt
        end
        asin_(x)
      end

      def asin__(x)
        return DecNum.context.exception(Num::InvalidOperation, 'asin needs -1 <= x <= 1') if x.abs > 1
        z = nil
        lim = DecNum('0.1') # DecNum('0.2') is enough; DecNum('0.1') trades reduction iterations for taylor series iterations
        DecNum.context do |local_context|
          local_context.precision += 3
          y = x


          s = 1
          y2 = nil
          h = DecNum('0.5')
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
          piby2 = pi*DecNum('0.5') # TODO. piby2=pi/2 cached constant
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

      # TODO: cached constants: pi2=2*pi, inv2pi=1/pi2

      @pi2 = nil
      @pi2_decimals = 0
      def pi2(decimals=nil)
        decimals ||= DecNum.context.precision
        DecNum.context(:precision=>decimals) do
          if $no_cache || @pi2_decimals < decimals
            @pi2 = pi(decimals)*2
            @pi2_decimals = decimals
          end
          +@pi2
        end
      end

      @invpi = nil
      @invpi_decimals = 0
      def invpi(decimals=nil)
        decimals ||= DecNum.context.precision
        DecNum.context(:precision=>decimals) do
          if @invpi_decimals < decimals
            @invpi = DecNum(1)/pi(decimals)
            @invpi_decimals = decimals
          end
          +@invpi
        end
      end

      @inv2pi = nil
      @inv2pi_decimals = 0
      def inv2pi(decimals=nil)
        decimals ||= DecNum.context.precision
        DecNum.context(:precision=>decimals) do
          if @inv2pi_decimals < decimals
            @inv2pi = DecNum(1)/pi2(decimals)
            @inv2pi_decimals = decimals
          end
          +@inv2pi
        end
      end

      @pi2 = DecNum(+1, 6283185307179586476925286766559005768394338798750211641949889184615632812572417997256069650684234135964296173026564613294187689219101164463450718816256962234900568205403877042211119289245897909860763928857621951331866892256951296467573566330542403818291297133846920697220908653296426787214520498282547449174013212631176349763041841925658508183430728735785180720022661061097640933042768293903883023218866114540731519183906184372234763865223586210237096148924759925499134703771505449782455876366023898259667346724881313286172042789892790449474381404359721887405541078434352586353504769349636935338810264001136254290527121655571542685515579218347274357442936881802449906860293099170742101584559378517847084039912224258043921728068836319627259549542619921037414422699999996745956099902119463465632192637190048918910693816605285044616506689370070523862376342020006275677505773175066416762841234355338294607196506980857510937462319125727764707575187503915563715561064342453613226003855753222391818432840398, -999)
      @pi2_decimals = 1000
      @invpi = DecNum(+1, 3183098861837906715377675267450287240689192914809128974953346881177935952684530701802276055325061719121456854535159160737858236922291573057559348214633996784584799338748181551461554927938506153774347857924347953233867247804834472580236647602284453995114318809237801738053479122409788218738756881710574461998928868004973446954789192217966461935661498123339729256093988973043757631495731339284820779917482786972199677361983999248857511703423577168622350375343210930950739760194789207295186675361186049889932706106543135510064406495556327943320458934962391963316812120336060719962678239749976655733088705595101400324813551287776991426217602443987522953627555294757812661360929159569635226248546281399215500490005955197141781138055935702630504200326354920418496232124811229124062929681784969183828704231508151124017430532136044343182815149491654451954925707997503106587816279635448187165095941466574380813999518153154156986940787179656174346851280733790233250914118866552625373000522454359423064225199009, -1000)
      @invpi_decimals = 1000
      @inv2pi = DecNum(+1, 1591549430918953357688837633725143620344596457404564487476673440588967976342265350901138027662530859560728427267579580368929118461145786528779674107316998392292399669374090775730777463969253076887173928962173976616933623902417236290118323801142226997557159404618900869026739561204894109369378440855287230999464434002486723477394596108983230967830749061669864628046994486521878815747865669642410389958741393486099838680991999624428755851711788584311175187671605465475369880097394603647593337680593024944966353053271567755032203247778163971660229467481195981658406060168030359981339119874988327866544352797550700162406775643888495713108801221993761476813777647378906330680464579784817613124273140699607750245002977598570890569027967851315252100163177460209248116062405614562031464840892484591914352115754075562008715266068022171591407574745827225977462853998751553293908139817724093582547970733287190406999759076577078493470393589828087173425640366895116625457059433276312686500261227179711532112599504, -1000)
      @inv2pi_decimals = 1000


      class <<self
        private

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
          # return x if x < pi2
          # prec = DecNum.context.precision
          # ex = x.fractional_exponent
          # DecNum.context do |local_context|
          #   # x.modulo(pi2)
          #   local_context.precision *= 2
          #   if ex > prec
          #     # consider exponent separately
          #     fd = nil
          #     excess = ex - prec
          #     x = x.scaleb(prec-ex)
          #     # now obtain 2*prec digits from inv2pi after the initial excess digits
          #     digits = nil
          #     DecNum.context do |extended_context|
          #       extended_context.precision += excess
          #       digits = (inv2pi.scaleb(excess)).fraction_part
          #     end
          #     x *= digits*pi2
          #   end
          #   # compute the fractional part of the division by 2pi
          #   x = pi2*((x*inv2pi).fraction_part)
          # end
          # +x
        end

        def reduce_angle(a)
          # TODO: reduce to pi/k; with quadrant information
          modtwopi(a)
        end

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

    math_function :sin, :cos, :tan, :atan

    def pi
      Math.pi
    end

    def e
      Math.e
    end

  end # DecNum
end # Flt