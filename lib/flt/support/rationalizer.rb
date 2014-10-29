module Flt
  module Support

    # This class provides efficient conversion of fraction (as approximate floating point numbers)
    # to rational numbers.
    class Rationalizer
      # Exact conversion to rational. Ruby provides this method for all numeric types
      # since version 1.9.1, but before that it wasn't available for Float or BigDecimal.
      # This methods supports old Ruby versions.
      def self.to_r(x)
        if x.respond_to?(:to_r)
          x.to_r
        else
          case x
          when Float
            # Float did not had a #to_r method until Ruby 1.9.1
            return Rational(x.to_i, 1) if x.modulo(1) == 0
            if !x.finite?
              return Rational(0, 0) if x.nan?
              return x < 0 ? Rational(-1, 0) : Rational(1, 0)
            end

            f, e = Math.frexp(x)

            if e < Float::MIN_EXP
               bits = e + Float::MANT_DIG - Float::MIN_EXP
            else
               bits = [Float::MANT_DIG,e].max
               # return Rational(x.to_i, 1) if bits < e
            end
              p = Math.ldexp(f, bits)
              e = bits - e
              if e < Float::MAX_EXP
                q = Math.ldexp(1, e)
              else
                q = Float::RADIX**e
              end
            Rational(p.to_i, q.to_i)

          when BigDecimal
            # BigDecimal probably didn't have #to_r at some point
            s, f, b, e = x.split
            p = f.to_i
            p = -p if s < 0
            e = f.size - e
            if e < 0
              p *= b**(-e)
              e = 0
            end
            q = b**(e)
            Rational(p,q)

          else
            x.to_r
          end
        end
      end

      # Convenience methods
      module AuxiliarFunctions
        private

        def num_den(x)
          x = to_r(x)
          [x.numerator, x.denominator]
        end

        # fraction part
        def fp(x)
          # y = x.modulo(1); return x<0 ? -y : y;
          x-ip(x)
        end

        # integer part
        def ip(x)
          # Note that ceil, floor return an Integer for Float and Flt::Num, but not for BigDecimal
          (x<0 ? x.ceil : x.floor).to_i
        end

        # round to integer
        def rnd(x)
          # Note that round returns an Integer for Float and Flt::Num, but not for BigDecimal
          x.round.to_i
        end

        # absolute value
        def abs(x)
          x.abs
        end

        def ceil(x)
          # Note that ceil returns an Integer for Float and Flt::Num, but not for BigDecimal
          x.ceil.to_i
        end

        def to_r(x)
          Rationalizer.to_r(x)
        end

        def special?(x)
          !x.finite? # x.class.context.special?(x)
        end

        def sign(x)
          x.class.context.sign(x)
        end
      end

      include AuxiliarFunctions
      extend  AuxiliarFunctions

      # Create Rationalizator with given tolerance.
      def initialize(tol=Tolerance(:epsilon))
        @tol = tol
      end

      def self.[](*args)
        new *args
      end

      # Rationalization method that finds the fraction with
      # smallest denominator fraction within the tolerance distance
      # of an approximate (floating point) number.
      #
      def rationalize(x)
        # Use the algorithm which has been found most efficient, rationalize_Knuth.
        rationalize_Knuth(x)
      end

      # This algorithm is derived from exercise 39 of 4.5.3 in
      # "The Art of Computer Programming", by Donald E. Knuth.
      def rationalize_Knuth(x)
        rationalization(x) do |x, dx|
          x     = to_r(x)
          dx    = to_r(dx)
          xp,xq = num_den(x-dx)
          yp,yq = num_den(x+dx)

          a = []
          fin, odd = false, false
          while !fin && xp != 0 && yp != 0
            odd = !odd
            xp,xq = xq,xp
            ax = xp.div(xq)
            xp -= ax*xq

            yp,yq = yq,yp
            ay = yp.div(yq)
            yp -= ay*yq

            if ax!=ay
              fin = true
              ax,xp,xq = ay,yp,yq if odd
            end
            a << ax # .to_i
          end
          a[-1] += 1 if xp != 0 && a.size > 0
          p,q = 1,0
          (1..a.size).each{|i| p, q = q+p*a[-i], p}
          [q, p]
        end
      end

      # This is algorithm PDQ2 by Joe Horn.
      def rationalize_Horn(x)
        rationalization(x) do |z, t|
          a,b = num_den(t)
          n0,d0 = (n,d = num_den(z))
          cn,x,pn,cd,y,pd,lo,hi,mid,q,r = 1,1,0,0,0,1,0,1,1,0,0
          begin
            q,r = n.divmod(d)
            x = q*cn+pn
            y = q*cd+pd
            pn = cn
            cn = x
            pd = cd
            cd = y
            n,d = d,r
          end until b*(n0*y-d0*x).abs <= a*d0*y

          if q > 1
            hi = q
            begin
              mid = (lo + hi).div(2)
              x = cn - pn*mid
              y = cd - pd*mid
              if b*(n0*y - d0*x).abs <= a*d0*y
                lo = mid
              else
                hi = mid
              end
            end until hi - lo <= 1
            x = cn - pn*lo
            y = cd - pd*lo
          end
          [x, y]
        end
      end

      # This is from a RPL program by Tony Hutchins (PDR6).
      def rationalize_HornHutchins(x)
        rationalization(x) do |z, t|
          a,b = num_den(t)
          n0,d0 = (n,d = num_den(z))
          cn,x,pn,cd,y,pd,lo,hi,mid,q,r = 1,1,0,0,0,1,0,1,1,0,0
          begin
            q,r = n.divmod(d)
            x = q*cn+pn
            y = q*cd+pd
            pn = cn
            cn = x
            pd = cd
            cd = y
            n,d = d,r
          end until b*(n0*y-d0*x).abs <= a*d0*y

          if q > 1
            hi = q
            begin
              mid = (lo + hi).div(2)
              x = cn - pn*mid
              y = cd - pd*mid
              if b*(n0*y - d0*x).abs <= a*d0*y
                lo = mid
              else
                hi = mid
              end
            end until hi - lo <= 1
            x = cn - pn*lo
            y = cd - pd*lo
          end
          [x, y]
        end
      end

      # Best fraction given maximum denominator
      # Algorithm Copyright (c) 1991 by Joseph K. Horn.
      #
      # The implementation of this method uses floating point
      # arithmetic which limits the magnitude and precision of the results, specially
      # using Float values.
      def self.max_denominator(f, max_den=1000000000, num_class=nil)
        return rationalize_special(f) if special?(f)
        return nil if max_den < 1
        num_class ||= f.class
        context = num_class.context
        return ip(f),1 if fp(f) == 0

        cast = lambda{|x| context.Num(x)}

        one = cast[1]

         sign = f < 0
         f = -f if sign

         a,b,c = 0,1,f
         while b < max_den && c != 0
           cc = one/c
           a,b,c = b, ip(cc)*b+a, fp(cc)
         end

         if b>max_den
           b -= a*ceil(cast[b-max_den]/a)
         end

         f1,f2 = [a,b].collect{|x| abs(cast[rnd(x*f)]/x-f)}

         a = f1 > f2 ? b : a

         num,den = rnd(a*f).to_i,a
         den = 1 if abs(den) < 1

         num = -num if sign

        return num,den
      end

      def self.rationalize_special(x)
        if x.nan?
          [0, 0]
        else
          [sign(x), 0]
        end
      end

      private

      def rationalization(x)
        return Rationalizer.rationalize_special(x) if special?(x)
        num_tol = @tol.kind_of?(Numeric)
        if !num_tol && @tol.zero?(x)
          # num,den = num_den(x)
          num,den = 0,1
        else
          negans = false
          if x<0
            negans = true
            x = -x
          end
          dx = num_tol ? @tol : @tol.value(x)

          num, den = yield x, dx

          num = -num if negans
        end
        [num, den]
      end

    end

  end
end
