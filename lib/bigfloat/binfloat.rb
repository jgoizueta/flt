require 'bigfloat/num'

module BigFloat

class BinFloat < Num

  class << self
    # Numerical base of Decimal.
    def radix
      2
    end

    # Integral power of the base: radix**n for integer n; returns an integer.
    def int_radix_power(n)
      (n < 0) ? (2**n) : (1<<n)
    end

    # Multiply by an integral power of the base: x*(radix**n) for x,n integer;
    # returns an integer.
    def int_mult_radix_power(x,n)
      x * ((n < 0) ? (2**n) : (1<<n))
    end

    # Divide by an integral power of the base: x/(radix**n) for x,n integer;
    # returns an integer.
    def int_div_radix_power(x,n)
      x / ((n < 0) ? (2**n) : (1<<n))
    end
  end

  # The context defines the arithmetic context: rounding mode, precision,...
  # Decimal.context is the current (thread-local) context.
  class Context < Num::ContextBase

    def initialize(*options)
      super(BinFloat, *options)
    end

  end

  class <<self

    def base_coercible_types
      unless defined? @base_coercible_types
        @base_coercible_types = super.merge(
          Float=>lambda{|x, context|
            if x.nan?
              BinFloat.nan
            elsif x.infinite?
              BinFloat.infinity(x<0 ? -1 : +1)
            elsif x.zero?
              BinFloat.zero((x.to_s[0,1].strip=="-") ? -1 : +1)
            else
              coeff, exp = Math.frexp(x)
              coeff = Math.ldexp(coeff, Float::MANT_DIG).to_i
              exp -= Float::MANT_DIG
              if coeff < 0
                sign = -1
                coeff = -coeff
              else
                sign = +1
              end
              BinFloat(sign, coeff, exp)
            end
          }
        )
      end
      @base_coercible_types
    end
  end

  # the DefaultContext is the base for new contexts; it can be changed.
  DefaultContext = BinFloat::Context.new(
                             :exact=>false, :precision=>53, :rounding=>:half_even,
                             :emin=> -1025, :emax=>+1023,
                             :flags=>[],
                             :traps=>[DivisionByZero, Overflow, InvalidOperation],
                             :ignored_flags=>[],
                             :capitals=>true,
                             :clamp=>true)

  ExtendedContext = BinFloat::Context.new(DefaultContext,
                             :traps=>[], :flags=>[], :clamp=>false)


  def initialize(*args)
    super(*args)
  end

  # Ruby-style to string conversion.
  def to_s(eng=false,context=nil)
    # (context || num_class.context).to_string(self)
    context = define_context(context)
    sgn = sign<0 ? '-' : ''
    if special?
      if @exp==:inf
        "#{sgn}Infinity"
      elsif @exp==:nan
        "#{sgn}NaN#{@coeff}"
      else # exp==:snan
        "#{sgn}sNaN#{@coeff}"
      end
    else
      inexact = true
      rounding = context.rounding
      if @sign == -1
        if rounding == :ceiling
          rounding = :floor
        elsif rounding == :floor
          rounding = :ceiling
        end
      end
      output_radix = 10
      x = self.abs.to_f

      p = self.number_of_digits # use context.precision ? / handle exacts

      if false
        # use as many digits as possible
        dec_pos,r,*digits = BurgerDybvig.float_to_digits_max(x,@coeff,@exp,rounding,
                                 context.etiny,p,num_class.radix,output_radix)
        inexact = :roundup if r
      else
        # use as few digits as possible
        dec_pos,*digits = BurgerDybvig.float_to_digits(x,@coeff,@exp,rounding,
                                 context.etiny,p,num_class.radix,output_radix)
      end
      # TODO: format properly
      digits = digits.map{|d| d.to_s(output_radix)}.join
      if dec_pos <= 0
        if dec_pos >= -4 && digits.length <= 15
          digits = "0." + "0"*(-dec_pos) + digits
        else
          digits = digits[0,1]+"."+digits[1..-1]+"E#{dec_pos-1}"
        end
      elsif dec_pos > digits.length
        if dec_pos <= 20
          digits = digits + "0"*(dec_pos-digits.length)
        else
          # TODO: if digits.length == 1
          digits = digits[0,1]+"."+digits[1..-1]+"E#{dec_pos-1}"
        end
      elsif dec_pos != digits.length
        digits = digits[0...dec_pos] + "." + digits[dec_pos..-1]
      end
      txt = ((sign==-1) ? '-' : '') + digits
    end
  end

  # Specific to_f conversion TODO: check if it representes an optimization
  if Float::RADIX==2
    def to_f
      if special?
        super
      else
        Math.ldexp(@sign*@coeff, @exp)
      end
    end
  end

end

def BinFloat(*args)
  BinFloat.Num(*args)
end

  # these are functions from Nio::Clinger, generalized for arbitrary floating point formats
  module Clinger #:nodoc:

    module_function

    def ratio_float(context, u,v,k,round_mode)
      # since this handles only positive numbers and ceiling and floor
      # are not symmetrical, they should have been swapped before calling this.
      q = u.div v
      r = u-q*v
      v_r = v-r
      z = context.num_class.new(+1,q,k)
      exact = (r==0)
      if (round_mode == :down || round_mode == :floor)
        # z = z
      elsif (round_mode == :up || round_mode == :ceiling)
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
  end

  # Burger and Dybvig free formatting algorithm, translated directly from Scheme;
  # after some testing, of the three different implementations in their
  # paper, the second seems to be more efficient in Ruby.
  # This algorithm formats arbitrary base floating pont numbers as decimal
  # text literals.
  module BurgerDybvig # :nodoc: all
    module_function
    def float_to_digits(v,f,e,round_mode,min_e,p,b,_B)
      # since this handles only positive numbers and ceiling and floor
      # are not symmetrical, they should have been swapped before calling this.
      roundl, roundh = rounding_h_l(round_mode, f)

        if e >= 0
          if f != exptt(b,p-1)
            be = exptt(b,e)
            r,s,m_p,m_m,k = scale(f*be*2,2,be,be,0,_B,roundl ,roundh,v)
          else
            be = exptt(b,e)
            be1 = be*b
            r,s,m_p,m_m,k = scale(f*be1*2,b*2,be1,be,0,_B,roundl ,roundh,v)
          end
        else
          if e==min_e or f != exptt(b,p-1)
            r,s,m_p,m_m,k = scale(f*2,exptt(b,-e)*2,1,1,0,_B,roundl ,roundh,v)
          else
            r,s,m_p,m_m,k = scale(f*b*2,exptt(b,1-e)*2,b,1,0,_B,roundl ,roundh,v)
          end
        end
        [k]+generate(r,s,m_p,m_m,_B,roundl ,roundh)
    end

    def float_to_digits_max(v,f,e,round_mode,min_e,p,b,_B)
      roundl, roundh = rounding_h_l(round_mode, f)
        if e >= 0
          if f != exptt(b,p-1)
            be = exptt(b,e)
            r,s,m_p,m_m,k = scale(f*be*2,2,be,be,0,_B,roundl ,roundh,v)
          else
            be = exptt(b,e)
            be1 = be*b
            r,s,m_p,m_m,k = scale(f*be1*2,b*2,be1,be,0,_B,roundl ,roundh,v)
          end
        else
          if e==min_e or f != exptt(b,p-1)
            r,s,m_p,m_m,k = scale(f*2,exptt(b,-e)*2,1,1,0,_B,roundl ,roundh,v)
          else
            r,s,m_p,m_m,k = scale(f*b*2,exptt(b,1-e)*2,b,1,0,_B,roundl ,roundh,v)
          end
        end
        [k]+generate_max(r,s,m_p,m_m,_B,roundl ,roundh)
    end

    def rounding_h_l(round_mode, f)
       # to support IEEE rounding modes (see algM) here,
       # the m_p,m_m passed to generate should be modified when the rounding
       # is :ieee_up,:ieee_down or :ieee_zero (here equivalent to :ieee_down since numbers as positive)
       # The should be substituted in those cases by r and r+1, and roundl,roundh would take
       # the values [true,false] for :ieee_down/:ieee_zero and [false,true] for :ieee_up
      case round_mode
        # TODO: review and complete
        when :half_even
          roundl = roundh = ((f%2)==0)
        when :up, :ceiling
          roundl = true
          roundh = false
        when :down, :floor
          roundl = false
          roundh = true
        else
          # here we don't assume any rounding in the floating point numbers
          # the result is valid for any rounding but may produce more digits
          # than stricly necessary for specifica rounding modes.
          roundl = false
          roundh = false
      end
      return roundl, roundh
    end

    def scale(r,s,m_p,m_m,k,_B,low_ok ,high_ok,v)
      return scale2(r,s,m_p,m_m,k,_B,low_ok ,high_ok) if v==0
      est = (logB(_B,v)-1E-10).ceil.to_i
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

    def exptt(_B, k)
      _B**k # TODO: memoize computed values or use table for common bases and exponents
    end

    def logB(_B, x)
      Math.log(x)/Math.log(_B) # TODO: memoize 1/log(_B)
    end

  end

end # BigFloat