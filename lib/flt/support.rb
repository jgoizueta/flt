module Flt
  module Support
    # This class assigns bit-values to a set of symbols
    # so they can be used as flags and stored as an integer.
    #   fv = FlagValues.new(:flag1, :flag2, :flag3)
    #   puts fv[:flag3]
    #   fv.each{|f,v| puts "#{f} -> #{v}"}
    class FlagValues

      #include Enumerator

      class InvalidFlagError < StandardError
      end
      class InvalidFlagTypeError < StandardError
      end


      # The flag symbols must be passed; values are assign in increasing order.
      #   fv = FlagValues.new(:flag1, :flag2, :flag3)
      #   puts fv[:flag3]
      def initialize(*flags)
        @flags = {}
        value = 1
        flags.each do |flag|
          raise InvalidFlagType,"Flags must be defined as symbols or classes; invalid flag: #{flag.inspect}" unless flag.kind_of?(Symbol) || flag.instance_of?(Class)
          @flags[flag] = value
          value <<= 1
        end
      end

      # Get the bit-value of a flag
      def [](flag)
        v = @flags[flag]
        raise InvalidFlagError, "Invalid flag: #{flag}" unless v
        v
      end

      # Return each flag and its bit-value
      def each(&blk)
        if blk.arity==2
          @flags.to_a.sort_by{|f,v|v}.each(&blk)
        else
          @flags.to_a.sort_by{|f,v|v}.map{|f,v|f}.each(&blk)
        end
      end

      def size
        @flags.size
      end

      def all_flags_value
        (1 << size) - 1
      end

    end

    # This class stores a set of flags. It can be assign a FlagValues
    # object (using values= or passing to the constructor) so that
    # the flags can be store in an integer (bits).
    class Flags

      class Error < StandardError
      end
      class InvalidFlagError < Error
      end
      class InvalidFlagValueError < Error
      end
      class InvalidFlagTypeError < Error
      end

      # When a Flag object is created, the initial flags to be set can be passed,
      # and also a FlagValues. If a FlagValues is passed an integer can be used
      # to define the flags.
      #    Flags.new(:flag1, :flag3, FlagValues.new(:flag1,:flag2,:flag3))
      #    Flags.new(5, FlagValues.new(:flag1,:flag2,:flag3))
      def initialize(*flags)
        @values = nil
        @flags = {}

        v = 0

        flags.flatten!

        flags.each do |flag|
          case flag
            when FlagValues
              @values = flag
            when Symbol, Class
              @flags[flag] = true
            when Integer
              v |= flag
            when Flags
              @values = flag.values
              @flags = flag.to_h.dup
            else
              raise InvalidFlagTypeError, "Invalid flag type for: #{flag.inspect}"
          end
        end

        if v!=0
          raise InvalidFlagTypeError, "Integer flag values need flag bit values to be defined" if @values.nil?
          self.bits = v
        end

        if @values
          # check flags
          @flags.each_key{|flag| check flag}
        end

      end

      def dup
        Flags.new(self)
      end

      # Clears all flags
      def clear!
        @flags = {}
      end

      # Sets all flags
      def set!
        if @values
          self.bits = @values.all_flags_value
        else
          raise Error,"No flag values defined"
        end
      end

      # Assign the flag bit values
      def values=(fv)
        @values = fv
      end

      # Retrieves the flag bit values
      def values
        @values
      end

      # Retrieves the flags as a bit-vector integer. Values must have been assigned.
      def bits
        if @values
          i = 0
          @flags.each do |f,v|
            bit_val = @values[f]
            i |= bit_val if v && bit_val
          end
          i
        else
          raise Error,"No flag values defined"
        end
      end

      # Sets the flags as a bit-vector integer. Values must have been assigned.
      def bits=(i)
        if @values
          raise Error, "Invalid bits value #{i}" if i<0 || i>@values.all_flags_value
          clear!
          @values.each do |f,v|
            @flags[f]=true if (i & v)!=0
          end
        else
          raise Error,"No flag values defined"
        end
      end

      # Retrieves the flags as a hash.
      def to_h
        @flags
      end

      # Same as bits
      def to_i
        bits
      end

      # Retrieve the setting (true/false) of a flag
      def [](flag)
        check flag
        @flags[flag]
      end

      # Modifies the setting (true/false) of a flag.
      def []=(flag,value)
        check flag
        case value
          when true,1
            value = true
          when false,0,nil
            value = false
          else
            raise InvalidFlagValueError, "Invalid value: #{value.inspect}"
        end
        @flags[flag] = value
        value
      end

      # Sets (makes true) one or more flags
      def set(*flags)
        flags = flags.first if flags.size==1 && flags.first.instance_of?(Array)
        flags.each do |flag|
          if flag.kind_of?(Flags)
            #if @values && other.values && compatible_values(other_values)
            #  self.bits |= other.bits
            #else
              flags.concat other.to_a
            #end
          else
            check flag
            @flags[flag] = true
          end
        end
      end

      # Clears (makes false) one or more flags
      def clear(*flags)
        flags = flags.first if flags.size==1 && flags.first.instance_of?(Array)
        flags.each do |flag|
          if flag.kind_of?(Flags)
            #if @values && other.values && compatible_values(other_values)
            #  self.bits &= ~other.bits
            #else
              flags.concat other.to_a
            #end
          else
            check flag
            @flags[flag] = false
          end
        end
      end

      # Sets (makes true) one or more flags (passes as an array)
      def << (flags)
        if flags.kind_of?(Array)
          set(*flags)
        else
          set(flags)
        end
      end

      # Iterate on each flag/setting pair.
      def each(&blk)
        if @values
          @values.each do |f,v|
            blk.call(f,@flags[f])
          end
        else
          @flags.each(&blk)
        end
      end

      # Iterate on each set flag
      def each_set
        each do |f,v|
          yield f if v
        end
      end

      # Iterate on each cleared flag
      def each_clear
        each do |f,v|
          yield f if !v
        end
      end

      # returns true if any flag is set
      def any?
        if @values
          bits != 0
        else
          to_a.size>0
        end
      end

      # Returns the true flags as an array
      def to_a
        a = []
        each_set{|f| a << f}
        a
      end

      def to_s
        "[#{to_a.map{|f| f.to_s.split('::').last}.join(', ')}]"
      end

      def inspect
        txt = "#{self.class.to_s}#{to_s}"
        txt << " (0x#{bits.to_s(16)})" if @values
        txt
      end


      def ==(other)
        if @values && other.values && compatible_values?(other.values)
          bits == other.bits
        else
          to_a.map{|s| s.to_s}.sort == other.to_a.map{|s| s.to_s}.sort
        end
      end



      private
      def check(flag)
        raise InvalidFlagType,"Flags must be defined as symbols or classes; invalid flag: #{flag.inspect}" unless flag.kind_of?(Symbol) || flag.instance_of?(Class)

        @values[flag] if @values # raises an invalid flag error if flag is invalid
        true
      end

      def compatible_values?(v)
        #@values.object_id==v.object_id
        @values == v
      end

    end

    module_function

    # Constructor for FlagValues
    def FlagValues(*params)
      if params.size==1 && params.first.kind_of?(FlagValues)
        params.first
      else
        FlagValues.new(*params)
      end
    end

    # Constructor for Flags
    def Flags(*params)
      if params.size==1 && params.first.kind_of?(Flags)
        params.first
      else
        Flags.new(*params)
      end
    end

    #
    # these are functions from Nio::Clinger, generalized for arbitrary floating point formats
    # Clinger algorithms to read floating point numbers from text literas with correct rounding.
    # from his paper: "How to Read Floating Point Numbers Accurately"
    # (William D. Clinger)
    module Clinger #:nodoc:

      module_function

      # Given exact positive integers u and v with beta**(n-1) <= u/v < beta**n
      # and exact integer k, returns the floating point number closest to u/v * beta**n
      # (beta is the floating-point radix)
      def ratio_float(context, u, v, k, round_mode)
        # since this handles only positive numbers and ceiling and floor
        # are not symmetrical, they should have been swapped before calling this.
        q = u.div v
        r = u-q*v
        v_r = v-r
        z = context.Num(+1,q,k)
        exact = (r==0)
        if (round_mode == :down || round_mode == :floor)
          # z = z
        elsif (round_mode == :up || round_mode == :ceiling) && r>0
          z = z.next_plus(context)
        elsif r<v_r
          # z = z
        elsif r>v_r
          z = z.next_plus(context)
        else
          # tie
          if (round_mode == :half_down) || (round_mode == :half_even && ((q%2)==0)) ||
             (round_mode == :down) || (round_mode == :floor)
             # z = z
          else
            z = z.next_plus(context)
          end
        end
        return z, exact
      end

      # AlgorithmM:
      # Given exact integers f and e, with f nonnegative, returns the floating-point number
      # closest to f * eb**e
      # (eb is the input radix)
      #
      # This is Clinger's \cd{AlgorithmM} modified to handle denormalized numbers and cope with overflow.
      def algM(context, f, e, round_mode, eb=10) # ceiling & floor must be swapped for negative numbers
        if e<0
         u,v,k = f,eb**(-e),0
        else
          u,v,k = f*(eb**e),1,0
        end

        if exact_mode = context.exact?
          exact_mode = :quiet if !context.traps[Num::Inexact]
          n = [(Math.log(u)/Math.log(2)).ceil,1].max # TODO: check if correct and optimize
          context.precision = n
        else
          n = context.precision
        end
        min_e = context.etiny
        max_e = context.etop

        rp_n = context.num_class.int_radix_power(n)
        rp_n_1 = context.num_class.int_radix_power(n-1)
        r = context.num_class.radix
        loop do
           x = u.div(v) # bottleneck
           # overflow if k>=max_e
           if (x>=rp_n_1 && x<rp_n) || k==min_e || k==max_e
              result = ratio_float(context,u,v,k,round_mode)
              context.exact = exact_mode if exact_mode
              return result
           elsif x<rp_n_1
             u *= r
             k -= 1
           elsif x>=rp_n
             v *= r
             k += 1
           end
        end

      end

    end # Clinger

    # Burger and Dybvig free formatting algorithm, translated directly from Scheme;
    # from their paper: "Printing Floating-Point Numbers Quickly and Accurately"
    # (Robert G. Burger, R. Kent Dybvig)
    #
    # After some testing, of the three different implementations in their
    # paper, the second seems to be more efficient in Ruby.
    #
    # This algorithm formats arbitrary base floating pont numbers as decimal
    # text literals.
    module BurgerDybvig # :nodoc: all
      module_function
      # This method converts v = f*b**e into a sequence of _B-base digits,
      # so that if the digits are converted back to a floating-point value
      # of precision p (correctly rounded), the result is v.
      # If round_mode is not nil, just enough digits to produce v using
      # that rounding is used; otherwise enough digits to produce v with
      # any rounding are delivered.
      #
      # If the +all+ parameter is true, all significant digits are generated,
      # i.e. all digits that, if used on input, cannot arbitrarily change
      # preserving the parsed value of the floating point number.
      # This will be useful to generate a fixed number of digits or if
      # as many digits as possible are required.
      # In this case an additional logical value that tells if the last digit
      # should be rounded-up.
      def float_to_digits(v, f, e, round_mode, min_e, p, b, _B, all=false)
        # Since this method handles only positive numbers and ceiling and floor
        # are not symmetrical, they should have been swapped before the call.
        roundl, roundh = rounding_l_h(round_mode, f)
        if e >= 0
          if f != exptt(b, p-1)
            be = exptt(b, e)
            r, s, m_p, m_m, k = scale(f*be*2, 2, be, be, 0, _B, roundl, roundh, v)
          else
            be = exptt(b, e)
            be1 = be*b
            r, s, m_p, m_m, k = scale(f*be1*2, b*2, be1, be, 0, _B, roundl, roundh, v)
          end
        else
          if e==min_e or f != exptt(b, p-1)
            r, s, m_p, m_m, k = scale(f*2, exptt(b, -e)*2, 1, 1, 0, _B, roundl, roundh,v)
          else
            r, s, m_p, m_m, k = scale(f*b*2, exptt(b,1-e)*2, b, 1, 0, _B, roundl ,roundh, v)
          end
        end
        # The value to be formatted is v=r/s; m- = m_m/s = (v - v-)/2; m+ = m_p/s = (v+ - v)/2
        m_m, m_p = rounding_range(r, s, m_m, m_p, round_mode)
        # Now m_m, m_p define the rounding range
        if all
          [k] + generate_max(r, s, m_p, m_m, _B, roundl, roundh)
        else
          [k,nil] + generate(r, s, m_p, m_m, _B, roundl, roundh)
        end
      end

      # Compute two flags, l (low), h (high) that determine if the lower upper limits
      # of the rounding range of v (f is the significand of v) are included in the range.
      # The range limits are based on m-, m+ for round to nearest rounding modes (:half_...),
      # on v-, v for round up and on v, v+ or round down.
      # m- = (v - v-)/2 and m+ = (v+ - v)/2 with v-, v+ he adjacent values to v,
      # v.next_minus, v.next_plus
      def rounding_l_h(round_mode, f)
        case round_mode
          when :half_even
            # rounding rage is (v-m-,v+m+) if v is odd and [v+m-,v+m+] if even
            l = h = ((f%2)==0)
          when :up, :ceiling
            # rounding rage is (v-,v]
            # ceiling is treated here assuming f>0
            l, h = false, true
          when :down, :floor
            # rounding rage is [v,v+)
            # floor is treated here assuming f>0
            l, h = true, false
          when :half_up
            # rounding rage is [v+m-,v+m+)
            l, h = true, false
          when :half_down
            # rounding rage is (v+m-,v+m+]
            l, h = false, true
          else
            # Here we don't assume any rounding in the floating point numbers
            # the result is valid for any rounding but may produce more digits
            # than stricly necessary for specifica rounding modes.
            # That is, enough digits are generated so that when the result is
            # converted to floating point with the specified precision and
            # correct rounding, the result is the original number.
            # rounding range is (v+m-,v+m+)
            l = h = false
        end
        return l, h
      end

      # Compute the limits of the rounding range (as differences from v)
      # The value to be formatted is v=r/s; m- = m_m/s = (v- - v)/2; m+ = m_p/s = (v - v+)/2
      def rounding_range(r, s, m_m, m_p, round_mode)
        case round_mode
        when :up, :ceiling
          # ceiling is treated here assuming f>0
          # rounding range is -v,v
          [m_m*2, 0]
        when :down, :floor
          # floor is treated here assuming f>0
          # rounding range is v,v+
          [0, m_p*2]
        else
          # rounding range is v-,v+
          [m_m, m_p]
        end
      end

      def scale(r,s,m_p,m_m,k,_B,low_ok ,high_ok,v)
        # return scale2(r,s,m_p,m_m,k,_B,low_ok ,high_ok) # testing
        return scale2(r,s,m_p,m_m,k,_B,low_ok ,high_ok) if v==0
        # TODO: estimate using v's arithmetic, not Float
        est = estimate_log(_B, v)
        if est>=0
          fixup(r,s*exptt(_B,est),m_p,m_m,est,_B,low_ok,high_ok)
        else
          sc = exptt(_B,-est)
          fixup(r*sc,s,m_p*sc,m_m*sc,est,_B,low_ok,high_ok)
        end
      end

      def fixup(r,s,m_p,m_m,k,_B,low_ok,high_ok)
        if (high_ok ? (r+m_p >= s) : (r+m_p > s)) # too low?
          [r,s*_B,m_p,m_m,k+1]
        else
          [r,s,m_p,m_m,k]
        end
      end

      def scale2(r,s,m_p,m_m,k,_B,low_ok ,high_ok)
        loop do
          if (high_ok ? (r+m_p >= s) : (r+m_p > s)) # k is too low
            s *= _B
            k += 1
          elsif (high_ok ? ((r+m_p)*_B<s) : ((r+m_p)*_B<=s)) # k is too high
            r *= _B
            m_p *= _B
            m_m *= _B
            k -= 1
          else
            break
          end
        end
        [r,s,m_p,m_m,k]
      end

      def generate(r,s,m_p,m_m,_B,low_ok ,high_ok)
        list = []
        loop do
          d,r = (r*_B).divmod(s)
          m_p *= _B
          m_m *= _B
          tc1 = low_ok ? (r<=m_m) : (r<m_m)
          tc2 = high_ok ? (r+m_p >= s) : (r+m_p > s)

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
        list
      end

      def generate_max(r,s,m_p,m_m,_B,low_ok ,high_ok)
        list = [false]
        loop do
          d,r = (r*_B).divmod(s)
          m_p *= _B
          m_m *= _B

          list << d

          tc1 = low_ok ? (r<=m_m) : (r<m_m)
          tc2 = high_ok ? (r+m_p >= s) : (r+m_p > s)

          if tc1 && tc2
            list[0] = true if r*2 >= s
            break
          end
        end
        list
      end

      def adjust(dec_pos, roundup, digits, base)
        if roundup
          # carry = roundup ? 1 : 0
          # digits = digits.reverse.map{|d| d += carry; d>=base ? 0 : (carry=0;d)}.reverse
          # if carry != 0
          #   digits.unshift carry
          #   dec_pos += 1
          # end
          i = digits.size - 1
          while i>=0
            digits[i] += 1
            if digits[i] == base
              digits[i] == 0
            else
              break
            end
            i -= 1
          end
          if i<0
            dec_pos += 1
            digits.unshift 1
          end
        end
        return dec_pos, digits
      end

      def exptt(_B, k)
        _B**k # TODO: memoize computed values or use table for common bases and exponents
      end

      def estimate_log(b, v)
        # TODO: memoization of 1/logB based on b and v's type
        case v
        when DecNum
          l = nil
          DecNum.context(:precision=>11) do
            case b
            when 10
              l = v.abs.log10
            else
              l = v.abs.ln/Flt.DecNum(b).ln
            end
          end
          l -= Flt.DecNum(+1,1,-10)
          l.ceil
        else
          # TODO: handle the case of a BinFloat > Float::MAX
          l = nil
          case b
          when 10
            l = Math.log10(v.abs.to_f)
          else
            l = Math.log(v.abs.to_f)/Math.log(b)
          end
          l -= 1E-10
          l.ceil
        end
      end

      def logB(_B, x)
        case x
        when DecNum
          DecNum.context(:precision=>15) do
            case _B
            when 10
              x.log10
            else
              x.ln/DecNum(_B).ln
            end
          end
        else
          Math.log(x.to_f)/Math.log(_B) # TODO: memoize 1/log(_B)
        end
      end

    end # BurgerDybvig

    module AuxiliarFunctions

      module_function

      # Number of bits in binary representation of the positive integer n, or 0 if n == 0.
      def _nbits(x)
        raise  TypeError, "The argument to _nbits should be nonnegative." if x < 0
        if x.is_a?(Fixnum)
          return 0 if x==0
          x.to_s(2).length
        elsif x <= NBITS_LIMIT
          Math.frexp(x).last
        else
          n = 0
          while x!=0
            y = x
            x >>= NBITS_BLOCK
            n += NBITS_BLOCK
          end
          n += y.to_s(2).length - NBITS_BLOCK if y!=0
          n
        end
      end
      NBITS_BLOCK = 32
      NBITS_LIMIT = Math.ldexp(1,Float::MANT_DIG)

      def detect_float_rounding
        x = x = Math::ldexp(1, Float::MANT_DIG+1) # 10000...00*Float::RADIX**2 == Float::RADIX**(Float::MANT_DIG+1)
        y = x + Math::ldexp(1, 2)                 # 00000...01*Float::RADIX**2 == Float::RADIX**2
        h = Float::RADIX/2
        b = h*Float::RADIX
        z = Float::RADIX**2 - 1
        if x + 1 == y
          if (y + 1 == y) && Float::RADIX==10
            :up05
          elsif -x - 1 == -y
            :up
          else
            :ceiling
          end
        else # x + 1 == x
          if x + z == x
            if -x - z == -x
              :down
            else
              :floor
            end
          else # x + z == y
            # round to nearest
            if x + b == x
              if y + b == y
                :half_down
              else
                :half_even
              end
            else # x + b == y
              :half_up
            end
          end
        end
      end

    end # AuxiliarFunctions

  end # Support




end # Flt