module Flt
  module Support

    # Floating-point reading and printing (from/to text literals).
    #
    # Here are methods for floating-point reading, using algorithms by William D. Clinger, and
    # printing, using algorithms by Robert G. Burger and R. Kent Dybvig.
    #
    # Reading and printing can also viewed as floating-point conversion between a fixed-precision
    # floating-point format (the floating-point numbers) and and a free floating-point format (text),
    # which may use different numerical bases.
    #
    # The Reader class, in the default :free mode, converts a free-form numeric value
    # (as a text literal, i.e. a free floating-point format, usually in base 10) which is taken
    # as an exact value, to a correctly-rounded floating-point of specified precision and with a
    # specified rounding mode. It also has a :fixed mode that uses the Formatter class indirectly.
    #
    # The Formatter class implements the Burger-Dybvig printing algorithm which converts a
    # fixed-precision floating point value and produces a text literal in some base, usually 10,
    # (equivalently, it produces a floating-point free-format value) so that it rounds back to
    # the original value (with some specified rounding-mode or any round-to-nearest mode) and with
    # the same original precision (e.g. using the Clinger algorithm)

    # Clinger algorithms to read floating point numbers from text literals with correct rounding.
    # from his paper: "How to Read Floating Point Numbers Accurately"
    # (William D. Clinger)
    class Reader

      # There are three different reading approaches, selected by the :mode parameter:
      # * :fixed (the destination context defines the resulting precision) input is rounded as specified
      #   by the context; if the context precision is 'exact', the exact input value will be represented
      #   in the destination base, which can lead to a Inexact exception (or a NaN result and an Inexact flag)
      # * :free The input precision is preserved, and the destination context precision is ignored;
      #   in this case the result can be converted back to the original number (with the same precision)
      #   a rounding mode for the back conversion may be passed; otherwise any round-to-nearest is assumed.
      #   (to increase the precision of the result the input precision must be increased --adding trailing zeros)
      # * :short is like :free, but the minumum number of digits that preserve the original value
      #   are generated (with :free, all significant digits are generated)
      #
      # For the fixed mode there are three conversion algorithms available that can be selected with the
      # :algorithm parameter:
      # * :A Arithmetic algorithm, using correctly rounded Flt::Num arithmetic.
      # * :M The Clinger Algorithm M is the slowest method, but it was the first implemented and testes and
      #   is kept as a reference for testing.
      # * :R The Clinger Algorithm R, which requires an initial approximation is currently only implemented
      #   for Float and is the fastest by far.
      def initialize(options={})
        @exact = nil
        @algorithm = options[:algorithm]
        @mode = options[:mode] || :fixed
      end

      def exact?
        @exact
      end

      # Given exact integers f and e, with f nonnegative, returns the floating-point number
      # closest to f * eb**e
      # (eb is the input radix)
      #
      # If the context precision is exact an Inexact exception may occur (an NaN be returned)
      # if an exact conversion is not possible.
      #
      # round_mode: in :fixed mode it specifies how to round the result (to the context precision); it
      # is passed separate from context for flexibility.
      # in :free mode it specifies what rounding would be used to convert back the output to the
      # input base eb (using the same precision that f has).
      def read(context, round_mode, sign, f, e, eb=10)
        @exact = true

        case @mode
        when :free, :short
          all_digits = (@mode == :free)
          # for free mode, (any) :nearest rounding is used by default
          Num.convert(Num[eb].Num(sign, f, e), context.num_class, :rounding=>round_mode||:nearest, :all_digits=>all_digits)
        when :fixed
          if exact_mode = context.exact?
            a,b = [eb, context.radix].sort
            m = (Math.log(b)/Math.log(a)).round
            if b == a**m
              # conmensurable bases
              if eb > context.radix
                n = AuxiliarFunctions._ndigits(f, eb)*m
              else
                n = (AuxiliarFunctions._ndigits(f, eb)+m-1)/m
              end
            else
              # inconmesurable bases; exact result may not be possible
              x = Num[eb].Num(sign, f, e)
              x = Num.convert_exact(x, context.num_class, context)
              @exact = !x.nan?
              return x
            end
          else
            n = context.precision
          end
          if round_mode == :nearest
            # :nearest is not meaningful here in :fixed mode; replace it
            if [:half_even, :half_up, :half_down].include?(context.rounding)
              round_mode = context.rounding
            else
              round_mode = :half_even
            end
          end
          # for fixed mode, use the context rounding by default
          round_mode ||= context.rounding
          alg = @algorithm
          if (context.radix == 2 && alg.nil?) || alg==:R
            z0 =  _alg_r_approx(context, round_mode, sign, f, e, eb, n)
            alg = z0 && :R
          end
          alg ||= :A
          case alg
          when :M, :R
            round_mode = Support.simplified_round_mode(round_mode, sign == -1)
            case alg
            when :M
              _alg_m(context, round_mode, sign, f, e, eb, n)
            when :R
              _alg_r(z0, context, round_mode, sign, f, e, eb, n)
            end
          else # :A
            # direct arithmetic conversion
            if round_mode == context.rounding
              x = Num.convert_exact(Num[eb].Num(sign, f, e), context.num_class, context)
              x = context.normalize(x) unless !context.respond_to?(:normalize) || context.exact?
              x
            else
              if context.num_class == Float
                float = true
                context = BinNum::FloatContext
              end
              x = context.num_class.context(context) do |local_context|
                local_context.rounding = round_mode
                Num.convert_exact(Num[eb].Num(sign, f, e), local_context.num_class, local_context)
              end
              if float
                x = x.to_f
              else
                x = context.normalize(x) unless context.exact?
              end
              x
            end
          end
        end
      end

      def _alg_r_approx(context, round_mode, sign, f, e, eb, n)

        return nil if context.radix != Float::RADIX || context.exact? || context.precision > Float::MANT_DIG

        # Compute initial approximation; if Float uses IEEE-754 binary arithmetic, the approximation
        # is good enough to be adjusted in just one step.
        @good_approx = true

        ndigits = Support::AuxiliarFunctions._ndigits(f, eb)
        adj_exp = e + ndigits - 1
        min_exp, max_exp = Reader.float_min_max_adj_exp(eb)

        if adj_exp >= min_exp && adj_exp <= max_exp
          if eb==2
            z0 = Math.ldexp(f,e)
          elsif eb==10
            unless Flt.float_correctly_rounded?
              min_exp_norm, max_exp_norm = Reader.float_min_max_adj_exp(eb, true)
              @good_approx = false
              return nil if e <= min_exp_norm
            end
            z0 = Float("#{f}E#{e}")
          else
            ff = f
            ee = e
            min_exp_norm, max_exp_norm = Reader.float_min_max_adj_exp(eb, true)
            if e <= min_exp_norm
              # avoid loss of precision due to gradual underflow
              return nil if e <= min_exp
              @good_approx = false
              ff = Float(f)*Float(eb)**(e-min_exp_norm-1)
              ee = min_exp_norm + 1
            end
            # if ee < 0
            #   z0 = Float(ff)/Float(eb**(-ee))
            # else
            #   z0 = Float(ff)*Float(eb**ee)
            # end
            z0 = Float(ff)*Float(eb)**ee
          end

          if z0 && context.num_class != Float
            @good_approx = false
            z0 = context.Num(z0).plus(context) # context.plus(z0) ?
          else
            z0 = context.Num(z0)
          end
        end

      end

      def _alg_r(z0, context, round_mode, sign, f, e, eb, n) # Fast for Float
        #raise InvalidArgument, "Reader Algorithm R only supports base 2" if context.radix != 2

        @z = z0
        @r = context.radix
        @rp_n_1 = context.int_radix_power(n-1)
        @round_mode = round_mode

        ret = nil
        loop do
          m, k = context.to_int_scale(@z)
          # TODO: replace call to compare by setting the parameters in local variables,
          #       then insert the body of compare here;
          #       then eliminate innecesary instance variables
          if e >= 0 && k >= 0
            ret = compare m, f*eb**e, m*@r**k, context
          elsif e >= 0 && k < 0
            ret = compare m, f*eb**e*@r**(-k), m, context
          elsif e < 0 && k >= 0
            ret = compare m, f, m*@r**k*eb**(-e), context
          else # e < 0 && k < 0
            ret = compare m, f*@r**(-k), m*eb**(-e), context
          end
          break if ret
        end
        ret && context.copy_sign(ret, sign) # TODO: normalize?
      end

      @float_min_max_exp_values = {
        10 => [Float::MIN_10_EXP, Float::MAX_10_EXP],
        Float::RADIX => [Float::MIN_EXP, Float::MAX_EXP],
        -Float::RADIX => [Float::MIN_EXP-Float::MANT_DIG, Float::MAX_EXP-Float::MANT_DIG]
      }
      class <<self
        # Minimum & maximum adjusted exponent for numbers in base to be in the range of Floats
        def float_min_max_adj_exp(base, normalized=false)
          k = normalized ? base : -base
          unless min_max = @float_min_max_exp_values[k]
            max_exp = (Math.log(Float::MAX)/Math.log(base)).floor
            e = Float::MIN_EXP
            e -= Float::MANT_DIG unless normalized
            min_exp = (e*Math.log(Float::RADIX)/Math.log(base)).ceil
            @float_min_max_exp_values[k] = min_max = [min_exp, max_exp]
          end
          min_max.map{|exp| exp - 1} # adjust
        end
      end

      def compare(m, x, y, context)
        ret = nil
        d = x-y
        d2 = 2*m*d.abs

        # v = f*eb**e is the number to be approximated
        # z = m*@r**k is the current aproximation
        # the error of @z is eps = abs(v-z) = 1/2 * d2 / y
        # we have x, y integers such that x/y = v/z
        # so eps < 1/2 <=> d2 < y
        #    d < 0 <=> x < y <=> v < z

        directed_rounding = [:up, :down].include?(@round_mode)

        if directed_rounding
          if @round_mode==:up ? (d <= 0) : (d < 0)
            # v <(=) z
            chk = (m == @rp_n_1) ? d2*@r : d2
            if (@round_mode == :up) && (chk < 2*y)
              # eps < 1
              ret = @z
            else
              @z = context.next_minus(@z)
            end
          else # @round_mode==:up ? (d > 0) : (d >= 0)
            # v >(=) z
            if (@round_mode == :down) && (d2 < 2*y)
              # eps < 1
              ret = @z
            else
              @z = context.next_plus(@z)
            end
          end
        else
          if d2 < y # eps < 1/2
            if (m == @rp_n_1) && (d < 0) && (y < @r*d2)
              # z has the minimum normalized significand, i.e. is a power of @r
              # and v < z
              # and @r*eps > 1/2
              # On the left of z the ulp is 1/@r than the ulp on the right; if v < z we
              # must require an error @r times smaller.
              @z = context.next_minus(@z)
            else
              # unambiguous nearest
              ret = @z
            end
          elsif d2 == y # eps == 1/2
            # round-to-nearest tie
            if @round_mode == :half_even
              if (m%2) == 0
                # m is even
                if (m == @rp_n_1) && (d < 0)
                  # z is power of @r and v < z; this wasn't really a tie because
                  # there are closer values on the left
                  @z = context.next_minus(@z)
                else
                  # m is even => round tie to z
                  ret = @z
                end
              elsif d < 0
                # m is odd, v < z => round tie to prev
                ret = context.next_minus(@z)
              elsif d > 0
                # m is odd, v > z => round tie to next
                ret = context.next_plus(@z)
              end
            elsif @round_mode == :half_up
              if d < 0
                # v < z
                if (m == @rp_n_1)
                  # this was not really a tie
                  @z = context.next_minus(@z)
                else
                  ret = @z
                end
              else # d > 0
                # v >= z
                ret = context.next_plus(@z)
              end
            else # @round_mode == :half_down
              if d < 0
                # v < z
                if (m == @rp_n_1)
                  # this was not really a tie
                  @z = context.next_minus(@z)
                else
                  ret = context.next_minus(@z)
                end
              else # d < 0
                # v > z
                ret = @z
              end
            end
          elsif d < 0 # eps > 1/2 and v < z
            @z = context.next_minus(@z)
          elsif d > 0 # eps > 1/2 and v > z
            @z = context.next_plus(@z)
          end
        end

        # Assume the initial approx is good enough (uses IEEE-754 arithmetic with round-to-nearest),
        # so we can avoid further iteration, except for directed rounding
        ret ||= @z unless directed_rounding || !@good_approx

        return ret
      end

      # Algorithm M to read floating point numbers from text literals with correct rounding
      # from his paper: "How to Read Floating Point Numbers Accurately" (William D. Clinger)
      def _alg_m(context, round_mode, sign, f, e, eb, n)
        if e<0
         u,v,k = f,eb**(-e),0
        else
          u,v,k = f*(eb**e),1,0
        end
        min_e = context.etiny
        max_e = context.etop
        rp_n = context.int_radix_power(n)
        rp_n_1 = context.int_radix_power(n-1)
        r = context.radix
        loop do
           x = u.div(v) # bottleneck
           if (x>=rp_n_1 && x<rp_n) || k==min_e || k==max_e
              z, exact = Reader.ratio_float(context,u,v,k,round_mode)
              @exact = exact
              if context.respond_to?(:exception)
                if k==min_e
                  context.exception(Num::Subnormal) if z.subnormal?
                  context.exception(Num::Underflow,"Input literal out of range") if z.zero? && f!=0
                elsif k==max_e
                  if !context.exact? && z.coefficient > context.maximum_coefficient
                    context.exception(Num::Overflow,"Input literal out of range")
                  end
                end
                context.exception Num::Inexact if !exact
              end
              return z.copy_sign(sign)
           elsif x<rp_n_1
             u *= r
             k -= 1
           elsif x>=rp_n
             v *= r
             k += 1
           end
        end
      end

      # Given exact positive integers u and v with beta**(n-1) <= u/v < beta**n
      # and exact integer k, returns the floating point number closest to u/v * beta**n
      # (beta is the floating-point radix)
      def self.ratio_float(context, u, v, k, round_mode)
        # since this handles only positive numbers and ceiling and floor
        # are not symmetrical, they should have been swapped before calling this.
        q = u.div v
        r = u-q*v
        v_r = v-r
        z = context.Num(+1,q,k)
        exact = (r==0)
        if round_mode == :down
          # z = z
        elsif (round_mode == :up) && r>0
          z = context.next_plus(z)
        elsif r<v_r
          # z = z
        elsif r>v_r
          z = context.next_plus(z)
        else
          # tie
          if (round_mode == :half_down) || (round_mode == :half_even && ((q%2)==0)) || (round_mode == :down)
             # z = z
          else
            z = context.next_plus(z)
          end
        end
        return z, exact
      end

    end # Reader

  end
end
