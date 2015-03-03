module Flt
  module Support

    # Burger and Dybvig free formatting algorithm,
    # from their paper: "Printing Floating-Point Numbers Quickly and Accurately"
    # (Robert G. Burger, R. Kent Dybvig)
    #
    # This algorithm formats arbitrary base floating point numbers as decimal
    # text literals. The floating-point (with fixed precision) is interpreted as an approximate
    # value, representing any value in its 'rounding-range' (the interval where all values round
    # to the floating-point value, with the given precision and rounding mode).
    # An alternative approach which is not taken here would be to represent the exact floating-point
    # value with some given precision and rounding mode requirements; that can be achieved with
    # Clinger algorithm (which may fail for exact precision).
    #
    # The variables used by the algorithm are stored in instance variables:
    # @v - The number to be formatted = @f*@b**@e
    # @b - The numeric base of the input floating-point representation of @v
    # @f - The significand or characteristic (fraction)
    # @e - The exponent
    #
    # Quotients of integers will be used to hold the magnitudes:
    # @s is the denominator of all fractions
    # @r numerator of @v: @v = @r/@s
    # @m_m numerator of the distance from the rounding-range lower limit, l, to @v: @m_m/@s = (@v - l)
    # @m_p numerator of the distance from @v to the rounding-range upper limit, u: @m_p/@s = (u - @v)
    # All numbers in the randound-range are rounded to @v (with the given precision p)
    # @k scale factor that is applied to the quotients @r/@s, @m_m/@s and @m_p/@s to put the first
    # significant digit right after the radix point. @b**@k is the first power of @b >= u
    #
    # The rounding range of @v is the interval of values that round to @v under the runding-mode.
    # If the rounding mode is one of the round-to-nearest variants (even, up, down), then
    # it is ((v+v-)/2 = (@v-@m_m)/@s, (v+v+)/2 = (@v+@m_)/2) whith the boundaries open or closed as explained below.
    # In this case:
    #   @m_m/@s = (@v - (v + v-)/2) where v- = @v.next_minus is the lower adjacent to v floating point value
    #   @m_p/@s = ((v + v+)/2 - @v) where v+ = @v.next_plus is the upper adjacent to v floating point value
    # If the rounding is directed, then the rounding interval is either (v-, @v] or [@v, v+]
    # @roundl is true if the lower limit of the rounding range is closed (i.e., if l rounds to @v)
    # @roundh is true if the upper limit of the rounding range is closed (i.e., if u rounds to @v)
    # if @roundh, then @k is the minimum @k with (@r+@m_p)/@s <= @output_b**@k
    #   @k = ceil(logB((@r+@m_p)/2)) with lobB the @output_b base logarithm
    # if @roundh, then @k is the minimum @k with (@r+@m_p)/@s < @output_b**@k
    #   @k = 1+floor(logB((@r+@m_p)/2))
    #
    # @output_b is the output base
    # @min_e is the input minimum exponent
    # p is the input floating point precision
    class Formatter

      # This Object-oriented implementation is slower than the original functional one for two reasons:
      # * The overhead of object creation
      # * The use of instance variables instead of local variables
      # But if scale is optimized or local variables are used in the inner loops, then this implementation
      # is on par with the functional one for Float and it is more efficient for Flt types, where the variables
      # passed as parameters hold larger objects.

      # A Formatted object is created to format floating point numbers given:
      # * The input base in which numbers to be formatted are defined
      # * The input minimum exponent
      # * The output base to which the input is converted.
      # * The :raise_on_repeat option, true by default specifies that when
      #   an infinite sequence of repeating significant digits is found on the output
      #   (which may occur when using the all-digits options and using directed-rounding)
      #   an InfiniteLoopError exception is raised. If this option is false, then
      #   no exception occurs, and instead of generating an infinite sequence of digits,
      #   the formatter object will have a 'repeat' property which designs the first digit
      #   to be repeated (it is an index into digits). If this equals the size of digits,
      #   it is assumend, that the digit to be repeated is a zero which follows the last
      #   digit present in digits.
      def initialize(input_b, input_min_e, output_b, options={})
        @b = input_b
        @min_e = input_min_e
        @output_b = output_b
        # result of last operation
        @adjusted_digits = @digits = nil
        # for "all-digits" mode results (which are truncated, rather than rounded),
        # round_up contains information to round the result:
        # * it is nil if the rest of digits are zero (the result is exact)
        # * it is :lo if there exist non-zero digits beyond the significant ones (those returned), but
        #   the value is below the tie (the value must be rounded up only for :up rounding mode)
        # * it is :tie if there exists exactly one nonzero digit after the significant and it is radix/2,
        #   for round-to-nearest it is atie.
        # * it is :hi otherwise (the value should be rounded-up except for the :down mode)
        @round_up = nil

        options = { :raise_on_repeat => true }.merge(options)
        # when significant repeating digits occur (+all+ parameter and directed rounding)
        # @repeat is set to the index of the first repeating digit in @digits;
        # (if equal to @digits.size, that would indicate an infinite sequence of significant zeros)
        @repeat = nil
        # the :raise_on_repeat options (by default true) causes exceptions when repeating is found
        @raise_on_repeat = options[:raise_on_repeat]
      end

      # This method converts v = f*b**e into a sequence of +output_b+-base digits,
      # so that if the digits are converted back to a floating-point value
      # of precision p (correctly rounded), the result is exactly v.
      #
      # If +round_mode+ is not nil, then just enough digits to produce v using
      # that rounding is used; otherwise enough digits to produce v with
      # any rounding are delivered.
      #
      # If the +all+ parameter is true, all significant digits are generated without rounding,
      # Significant digits here are all digits that, if used on input, cannot arbitrarily change
      # while preserving the parsed value of the floating point number. Since the digits are not rounded
      # more digits may be needed to assure round-trip value preservation.
      #
      # This is useful to reflect the precision of the floating point value in the output; in particular
      # trailing significant zeros are shown. But note that, for directed rounding and base conversion
      # this may need to produce an infinite number of digits, in which case an exception will be raised
      # unless the :raise_on_repeat option has been set to false in the Formatter object. In that case
      # the formatter objetct will have a +repeat+ property that specifies the point in the digit
      # sequence where irepetition starts. The digits from that point to the end to the digits sequence
      # repeat indefinitely.
      #
      # This digit-repetition is specially frequent for the :up rounding mode, in which any number
      # with a finite numberof nonzero digits equal to or less than the precision will haver and infinite
      # sequence of zero significant digits.
      #
      # The:down rounding (truncation) could be used to show the exact value of the floating
      # point but beware: if the value has not an exact representation in the output base this will
      # lead to an infinite loop or repeating squence.
      #
      # When the +all+ parameters is used the result is not rounded (is truncated), and the round_up flag
      # is set to indicate that nonzero digits exists beyond the returned digits; the possible values
      # of the round_up flag are:
      # * nil : the rest of digits are zero or repeat (the result is exact)
      # * :lo : there exist non-zero digits beyond the significant ones (those returned), but
      #   the value is below the tie (the value must be rounded up only for :up rounding mode)
      # * :tie : there exists exactly one nonzero digit after the significant and it is radix/2,
      #   for round-to-nearest it is atie.
      # * :hi : the value is closer to the rounded-up value (incrementing the last significative digit.)
      #
      # Note that the round_mode here is not the rounding mode applied to the output;
      # it is the rounding mode that applied to *input* preserves the original floating-point
      # value (with the same precision as input).
      # should be rounded-up.
      #
      def format(v, f, e, round_mode, p=nil, all=false)
        context = v.class.context
        # TODO: consider removing parameters f,e and using v.split instead
        @minus = (context.sign(v)==-1)
        @v = context.copy_sign(v, +1) # don't use context.abs(v) because it rounds (and may overflow also)
        @f = f.abs
        @e = e
        @round_mode = round_mode
        @all_digits = all
        p ||= context.precision

        # adjust the rounding mode to work only with positive numbers
        @round_mode = Support.simplified_round_mode(@round_mode, @minus)

        # determine the high,low inclusion flags of the rounding limits
        case @round_mode
          when :half_even
            # rounding rage is (v-m-,v+m+) if v is odd and [v+m-,v+m+] if even
            @round_l = @round_h = ((@f % 2) == 0)
          when :up
            # rounding rage is (v-,v]
            # ceiling is treated here assuming f>0
            @round_l, @round_h = false, true
          when :down
            # rounding rage is [v,v+)
            # floor is treated here assuming f>0
            @round_l, @round_h = true, false
          when :half_up
            # rounding rage is [v+m-,v+m+)
            @round_l, @round_h = true, false
          when :half_down
            # rounding rage is (v+m-,v+m+]
            @round_l, @round_h = false, true
          else # :nearest
            # Here assume only that round-to-nearest will be used, but not which variant of it
            # The result is valid for any rounding (to nearest) but may produce more digits
            # than stricly necessary for specific rounding modes.
            # That is, enough digits are generated so that when the result is
            # converted to floating point with the specified precision and
            # correct rounding (to nearest), the result is the original number.
            # rounding range is (v+m-,v+m+)
            @round_l = @round_h = false
        end

        # TODO: use context.next_minus, next_plus instead of direct computing, don't require min_e & ps
        # Now compute the working quotients @r/@s, @m_p/@s = (v+ - @v), @m_m/@s = (@v - v-) and scale them.
        if @e >= 0
          if @f != b_power(p-1)
            be = b_power(@e)
            @r, @s, @m_p, @m_m = @f*be*2, 2, be, be
          else
            be = b_power(@e)
            be1 = be*@b
            @r, @s, @m_p, @m_m = @f*be1*2, @b*2, be1, be
          end
        else
          if @e == @min_e || @f != b_power(p-1)
            @r, @s, @m_p, @m_m = @f*2, b_power(-@e)*2, 1, 1
          else
            @r, @s, @m_p, @m_m = @f*@b*2, b_power(1-@e)*2, @b, 1
          end
        end
        @k = 0
        @context = context
        scale_optimized!


        # The value to be formatted is @v=@r/@s; m- = @m_m/@s = (@v - v-)/@s; m+ = @m_p/@s = (v+ - @v)/@s
        # Now adjust @m_m, @m_p so that they define the rounding range
        case @round_mode
        when :up
          # ceiling is treated here assuming @f>0
          # rounding range is -v,@v
          @m_m, @m_p = @m_m*2, 0
        when :down
          # floor is treated here assuming #f>0
          # rounding range is @v,v+
          @m_m, @m_p = 0, @m_p*2
        else
          # rounding range is v-,v+
          # @m_m, @m_p = @m_m, @m_p
        end

        # Now m_m, m_p define the rounding range
        all ? generate_max : generate

      end

      # Access result of format operation: scaling (position of radix point) and digits
      def digits
        return @k, @digits
      end

      attr_reader :round_up, :repeat

      # Access rounded result of format operation: scaling (position of radix point) and digits
      def adjusted_digits(round_mode)
        if @adjusted_digits.nil? && !@digits.nil?
          @adjusted_k, @adjusted_digits = Support.adjust_digits(
                                            @k, @digits,
                                            :round_mode => round_mode,
                                            :negative => @minus,
                                            :round_up => @round_up,
                                            :base => @output_b)
        end
        return @adjusted_k, @adjusted_digits
      end

      # Given r/s = v (number to convert to text), m_m/s = (v - v-)/s, m_p/s = (v+ - v)/s
      # Scale the fractions so that the first significant digit is right after the radix point, i.e.
      # find k = ceil(logB((r+m_p)/s)), the smallest integer such that (r+m_p)/s <= B^k
      # if k>=0 return:
      #  r=r, s=s*B^k, m_p=m_p, m_m=m_m
      # if k<0 return:
      #  r=r*B^k, s=s, m_p=m_p*B^k, m_m=m_m*B^k
      #
      # scale! is a general iterative method using only (multiprecision) integer arithmetic.
      def scale_original!(really=false)
        loop do
          if (@round_h ? (@r+@m_p >= @s) : (@r+@m_p > @s)) # k is too low
            @s *= @output_b
            @k += 1
          elsif (@round_h ? ((@r+@m_p)*@output_b<@s) : ((@r+@m_p)*@output_b<=@s)) # k is too high
            @r *= @output_b
            @m_p *= @output_b
            @m_m *= @output_b
            @k -= 1
          else
            break
          end
        end
      end
      # using local vars instead of instance vars: it makes a difference in performance
      def scale!
        r, s, m_p, m_m, k,output_b = @r, @s, @m_p, @m_m, @k,@output_b
        loop do
          if (@round_h ? (r+m_p >= s) : (r+m_p > s)) # k is too low
            s *= output_b
            k += 1
          elsif (@round_h ? ((r+m_p)*output_b<s) : ((r+m_p)*output_b<=s)) # k is too high
            r *= output_b
            m_p *= output_b
            m_m *= output_b
            k -= 1
          else
            @s = s
            @r = r
            @m_p = m_p
            @m_m = m_m
            @k = k
            break
          end
        end
      end

      def b_power(n)
        @b**n
      end

      def output_b_power(n)
        @output_b**n
      end

      def start_repetition_dectection
        @may_repeat = (@m_p == 0 || @m_m == 0)
        @n_iters = 0
        @rs = []
      end

      ITERATIONS_BEFORE_KEEPING_TRACK_OF_REMAINDERS = 10000

      # Detect indefinite repetitions in generate_max
      # returns the number of digits that are being repeated
      # (0 indicates the next digit would repeat and it would be a zero)
      def detect_repetitions(r)
        return nil unless @may_repeat
        @n_iters += 1
        if r == 0 && @m_p == 0
          repeat_count = 0
        elsif (@n_iters > ITERATIONS_BEFORE_KEEPING_TRACK_OF_REMAINDERS)
          if @rs.include?(r)
            repeat_count = @rs.index(r) - @rs.size
          else
            @rs << r
          end
        end
        if repeat_count
          raise InfiniteLoopError, "Infinite digit sequence." if @raise_on_repeat
          repeat_count
        else
          nil
        end
      end

      def remove_redundant_repetitions
        if ITERATIONS_BEFORE_KEEPING_TRACK_OF_REMAINDERS > 0 && @repeat
          if @repeat < @digits.size
            repeating_digits = @digits[@repeat..-1]
            l = repeating_digits.size
            pos = @repeat - l
            while pos >= 0 && @digits[pos, l] == repeating_digits
              pos -= l
            end
            first_repeat = pos + l
            if first_repeat < @repeat
              @repeat = first_repeat
              @digits = @digits[0, @repeat+l]
            end
          end
        end
        @digits
      end

      def generate_max
        @round_up = false
        list = []
        r, s, m_p, m_m, = @r, @s, @m_p, @m_m

        start_repetition_dectection

        loop do
          if repeat_count = detect_repetitions(r)
            @repeat = list.size + repeat_count
            break
          end

          d,r = (r*@output_b).divmod(s)

          m_p *= @output_b
          m_m *= @output_b

          list << d

          tc1 = @round_l ? (r<=m_m) : (r<m_m)
          tc2 = @round_h ? (r+m_p >= s) : (r+m_p > s)

          if tc1 && tc2
            if r != 0
              r *= 2
              if r > s
                @round_up = :hi
              elsif r == s
                @round_up = :tie
              else
                @rund_up = :lo
              end
            end
            break
          end
        end
        @digits = list
        remove_redundant_repetitions
      end

      def generate
        list = []
        r, s, m_p, m_m, = @r, @s, @m_p, @m_m
        loop do
          d,r = (r*@output_b).divmod(s)
          m_p *= @output_b
          m_m *= @output_b
          tc1 = @round_l ? (r<=m_m) : (r<m_m)
          tc2 = @round_h ? (r+m_p >= s) : (r+m_p > s)

          if not tc1
            if not tc2
              list << d
            else
              list << d+1
              break
            end
          else
            if not tc2
              list << d
              break
            else
              if r*2 < s
                list << d
                break
              else
                list << d+1
                break
              end
            end
          end

        end
        @digits = list
      end

      ESTIMATE_FLOAT_LOG_B = {2=>1/Math.log(2), 10=>1/Math.log(10), 16=>1/Math.log(16)}
      # scale_o1! is an optimized version of scale!; it requires an additional parameters with the
      # floating-point number v=r/s
      #
      # It uses a Float estimate of ceil(logB(v)) that may need to adjusted one unit up
      # TODO: find easy to use estimate; determine max distance to correct value and use it for fixing,
      #       or use the general scale! for fixing (but remembar to multiply by exptt(...))
      #       (determine when Math.log is aplicable, etc.)
      def scale_optimized!
        context = @context # @v.class.context
        return scale! if context.zero?(@v)

        # 1. compute estimated_scale

        # 1.1. try to use Float logarithms (Math.log)
        v = @v
        v_abs = context.copy_sign(v, +1) # don't use v.abs because it rounds (and may overflow also)
        v_flt = v_abs.to_f
        b = @output_b
        log_b = ESTIMATE_FLOAT_LOG_B[b]
        log_b = ESTIMATE_FLOAT_LOG_B[b] = 1.0/Math.log(b) if log_b.nil?
        estimated_scale = nil
        fixup = false
        begin
          l = ((b==10) ? Math.log10(v_flt) : Math.log(v_flt)*log_b)
          estimated_scale =(l - 1E-10).ceil
          fixup = true
        rescue
          # rescuing errors is more efficient than checking (v_abs < Float::MAX.to_i) && (v_flt > Float::MIN) when v is a Flt
        else
          # estimated_scale = nil
        end

        # 1.2. Use Flt::DecNum logarithm
        if estimated_scale.nil?
          v.to_decimal_exact(:precision=>12) if v.is_a?(BinNum)
          if v.is_a?(DecNum)
            l = nil
            DecNum.context(:precision=>12) do
              case b
              when 10
                l = v_abs.log10
              else
                l = v_abs.ln/Flt.DecNum(b).ln
              end
            end
            l -= Flt.DecNum(+1,1,-10)
            estimated_scale = l.ceil
            fixup = true
          end
        end

        # 1.3 more rough Float aproximation
          # TODO: optimize denominator, correct numerator for more precision with first digit or part
          # of the coefficient (like _log_10_lb)
        estimated_scale ||= (v.adjusted_exponent.to_f * Math.log(v.class.context.radix) * log_b).ceil

        if estimated_scale >= 0
          @k = estimated_scale
          @s *= output_b_power(estimated_scale)
        else
          sc = output_b_power(-estimated_scale)
          @k = estimated_scale
          @r *= sc
          @m_p *= sc
          @m_m *= sc
        end
        fixup ? scale_fixup! : scale!

      end

      # fix up scaling (final step): specialized version of scale!
      # This performs a single up scaling step, i.e. behaves like scale2, but
      # the input must be at most one step down from the final result
      def scale_fixup!
        if (@round_h ? (@r+@m_p >= @s) : (@r+@m_p > @s)) # too low?
          @s *= @output_b
          @k += 1
        end
      end

    end

  end
end
