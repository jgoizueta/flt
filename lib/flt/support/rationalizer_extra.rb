module Flt
  module Support

    class Rationalizer
      # Some rationalization algorithms currently not being used


      # Simple Rationalization by Joe Horn
      def rationalize_Horn_simple(x, smallest_denominator = false)
        rationalization(x) do |z, t|
          a,b = num_den(t)
          n0,d0 = (n,d = z.nio_xr.nio_num_den)
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
          if smallest_denominator
            if q>1
              hi = q
              begin
                mid = (lo+hi).div(2)
                x = cn-pn*mid
                y = cd-pd*mid
                if b*(n0*y-d0*x).abs <= a*d0*y
                  lo = mid
                else
                  hi = mid
                end
              end until hi-lo <= 1
              x = cn - pn*lo
              y = cd - pd*lo
            end
          end
          [x, y]
        end
      end


      # Smallest denominator rationalization procedure by Joe Horn and Tony Hutchins; this
      # is the most efficient method as implemented in RPL.
      # Tony Hutchins has come up with PDR6, an improvement over PDQ2;
      # though benchmarking does not show any speed improvement under Ruby.
      def rationalize_Horn_Hutchins(x)
        rationalization(x) do |x, dx|
          a,b = num_den(dx)
          n,d = num_den(x)
          pc,ce = n,-d
          pc,cd = 1,0
          t = a*b
          begin
            tt = (-pe).div(ce)
            pd,cd = cd,pd+tt*cd
            pe,ce = ce,pe+tt*ce
          end until b*ce.abs <= t*cd
          tt = t * (pe<0 ? -1 : (pe>0 ? +1 : 0))
          tt = (tt*d+b*ce).div(tt*pd+b*pe)
          [(n*cd-ce-(n*pd-pe)*tt)/d, tt/(cd-tt*pd)]
        end
      end

      # Smallest denominator rationalization based on exercise 39 of \cite[\S 4.5.3]{Knuth}.
      # This has been found the most efficient method (except for large tolerances)
      # as implemented in Ruby.
      # Here's the rationalization procedure based on the exercise by Knuth.
      # We need first to calculate the limits (x-dx, x+dx)
      # of the range where we'll look for the rational number.
      # If we compute them using floating point and then convert then to fractions this method is
      # always more efficient than the other procedures implemented here, but it may be
      # less accurate. We can achieve perfect accuracy as the other methods by doing the
      # substraction and addition with rationals, but then this method becomes less efficient than
      # the others for a low number of iterations (low precision required).
      def rationalize_Knuth_Goizueta(x)
        rationalization(x) do |x, dx|
          x = to_r(x)
          dx = to_r(dx)
          xp,xq = num_den(x-dx)
          yp,yq = num_den(x+dx)

          a = []
          fin,odd = false,false
          while !fin && xp!=0 && yp!=0
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
          a[-1] += 1 if xp!=0 && a.size>0
          p,q = 1,0
          (1..a.size).each{|i| p,q=q+p*a[-i],p}
          [q, p]
        end
      end

      # La siguiente variante realiza una iteración menos si xq<xp y una iteración más
      # si xq>xp.
      def rationalize_Knuth_Goizueta_b(x)
        rationalization(x) do |x, dx|
          x = to_r(x)
          dx = to_r(dx)
          xq,xp = num_den(x-dx)
          yq,yp = num_den(x+dx)

          a = []
          fin,odd = false,false
          while !fin && xp!=0 && yp!=0
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
          a[-1] += 1 if xp!=0 && a.size>0
          p,q = 1,0
          (1..a.size).each{|i| p,q=q+p*a[-i],p}
          [p, q]
        end
      end

      # An exact rationalization method for binary floating point
      # that yields smallest fractions when possible and is not too slow
      def exact_binary_rationalization(x)
        p, q = x, 1
        while p.modulo(1) != 0
          p *= 2.0
          q <<= 1 # q *= 2
        end
        Rational(p.to_i, q)
      end

      # An a here's a shorter implementation relying on the semantics of the power operator, but
      # which is somewhat slow:
      def exact_float_rationalization(x)
        f,e = Math.frexp(x)
        f = Math.ldexp(f, Float::MANT_DIG)
        e -= Float::MANT_DIG
        return Rational(f.to_i*(Float::RADIX**e.to_i), 1)
      end

    end

  end
end
