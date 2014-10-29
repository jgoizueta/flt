module Flt
  module Support

    class InfiniteLoopError < StandardError
    end

    module_function
    # replace :ceiling and :floor rounding modes by :up/:down (depending on sign of the number to be rounded)
    def simplified_round_mode(round_mode, negative)
      if negative
        if round_mode == :ceiling
          round_mode = :floor
        elsif round_mode == :floor
          round_mode = :ceiling
        end
      end
      if round_mode == :ceiling
        round_mode = :up
      elsif round_mode == :floor
        round_mode = :down
      end
      round_mode
    end

    # Adjust truncated digits based on the rounding mode (:round_mode option)
    # and on the information about the following digits contained in the :round_up
    # parameter (nil for only zeros, :lo for nonzero values below tie, :tie for a :tie
    # and :hi for nonzero digits over the tie). Other parameters: :negative to consider
    # the number negative, :base the base of the number.
    def adjust_digits(dec_pos, digits, options={})
      round_mode = options[:round_mode]
      negative   = options[:negative]
      round_up   = options[:round_up]
      base       = options[:base]
      round_mode = simplified_round_mode(round_mode, negative)

      increment = (round_up && (round_mode != :down)) &&
                    ((round_mode == :up) ||
                     (round_up == :hi) ||
                     ((round_up == :tie) &&
                      ((round_mode==:half_up) ||
                       ((round_mode==:half_even) && ((digits.last % 2)==1)))))

      if increment
        digits = digits.dup
        # carry = increment ? 1 : 0
        # digits = digits.reverse.map{|d| d += carry; d>=base ? 0 : (carry=0;d)}.reverse
        # if carry != 0
        #   digits.unshift carry
        #   dec_pos += 1
        # end
        i = digits.size - 1
        while i>=0
          digits[i] += 1
          if digits[i] == base
            digits[i] = 0
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
      [dec_pos, digits]
    end

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
      NBITS_LIMIT = Math.ldexp(1,Float::MANT_DIG).to_i

      # Number of base b digits in an integer
      def _ndigits(x, b)
        raise  TypeError, "The argument to _ndigits should be nonnegative." if x < 0
        return 0 unless x.is_a?(Integer)
        return _nbits(x) if b==2
        if x.is_a?(Fixnum)
          return 0 if x==0
          x.to_s(b).length
        elsif x <= NDIGITS_LIMIT
          (Math.log(x)/Math.log(b)).floor + 1
        else
          n = 0
          block = b**NDIGITS_BLOCK
          while x!=0
            y = x
            x /= block
            n += NDIGITS_BLOCK
          end
          n += y.to_s(b).length - NDIGITS_BLOCK if y!=0
          n
        end
      end
      NDIGITS_BLOCK = 50
      NDIGITS_LIMIT = Float::MAX.to_i

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

# The math method of context needs instance_exec to pass parameters to the blocks evaluated
# with a modified self (pointing to a context object.) intance_exec is available in Ruby 1.9.1 and
# is also defined by ActiveRecord. Here we use Mauricio Fernández implementation if it is not
# available.
class Object
  unless defined? instance_exec
    module InstanceExecHelper; end
    include InstanceExecHelper
    def instance_exec(*args, &block) # !> method redefined; discarding old instance_exec
      mname = "__instance_exec_#{Thread.current.object_id.abs}_#{object_id.abs}"
      InstanceExecHelper.module_eval{ define_method(mname, &block) }
      begin
        ret = send(mname, *args)
      ensure
        InstanceExecHelper.module_eval{ undef_method(mname) } rescue nil
      end
      ret
    end
  end
end
