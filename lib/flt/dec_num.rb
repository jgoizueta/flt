require 'flt/num'
require 'flt/bigdecimal'

module Flt

# DecNum arbitrary precision floating point number.
# This implementation of DecNum is based on the Decimal module of Python,
# written by Eric Price, Facundo Batista, Raymond Hettinger, Aahz and Tim Peters.
class DecNum < Num

  class << self
    # Numerical base of DecNum.
    def radix
      10
    end

    # Integral power of the base: radix**n for integer n; returns an integer.
    def int_radix_power(n)
      10**n
    end

    # Multiply by an integral power of the base: x*(radix**n) for x,n integer;
    # returns an integer.
    def int_mult_radix_power(x,n)
      n < 0 ? (x / (10**(-n))) : (x * (10**n))
    end

    # Divide by an integral power of the base: x/(radix**n) for x,n integer;
    # returns an integer.
    def int_div_radix_power(x,n)
      n < 0 ? (x * (10**(-n))) : (x / (10**n))
    end
  end

  # This is the Context class for Flt::DecNum.
  #
  # The context defines the arithmetic context: rounding mode, precision,...
  #
  # DecNum.context is the current (thread-local) context for DecNum numbers.
  class Context < Num::ContextBase
    # See Flt::Num::ContextBase#new() for the valid options
    #
    # See also the context constructor method Flt::Num.Context().
    def initialize(*options)
      super(DecNum, *options)
    end
  end

  # the DefaultContext is the base for new contexts; it can be changed.
  DefaultContext = DecNum::Context.new(
                             :exact=>false, :precision=>28, :rounding=>:half_even,
                             :emin=> -999999999, :emax=>+999999999,
                             :flags=>[],
                             :traps=>[DivisionByZero, Overflow, InvalidOperation],
                             :ignored_flags=>[],
                             :capitals=>true,
                             :clamp=>true)

  BasicContext = DecNum::Context.new(DefaultContext,
                             :precision=>9, :rounding=>:half_up,
                             :traps=>[DivisionByZero, Overflow, InvalidOperation, Clamped, Underflow],
                             :flags=>[])

  ExtendedContext = DecNum::Context.new(DefaultContext,
                             :precision=>9, :rounding=>:half_even,
                             :traps=>[], :flags=>[], :clamp=>false)

  # A DecNum value can be defined by:
  # * A String containing a text representation of the number
  # * An Integer
  # * A Rational
  # * A Value of a type for which conversion is defined in the context.
  # * Another DecNum.
  # * A sign, coefficient and exponent (either as separate arguments, as an array or as a Hash with symbolic keys),
  #   or a signed coefficient and an exponent.
  #   This is the internal representation of Num, as returned by Num#split.
  #   The sign is +1 for plus and -1 for minus; the coefficient and exponent are
  #   integers, except for special values which are defined by :inf, :nan or :snan for the exponent.
  #
  # An optional Context can be passed after the value-definint argument to override the current context
  # and options can be passed in a last hash argument; alternatively context options can be overriden
  # by options of the hash argument.
  #
  # When the number is defined by a numeric literal (a String), it can be followed by a symbol that specifies
  # the mode used to convert the literal to a floating-point value:
  # * :free is currently the default for all cases. The precision of the input literal (including trailing zeros)
  #   is preserved and the precision of the context is ignored.
  #   When the literal is in base 10, (which is the case by default), the literal is preserved exactly.
  #   Otherwise, all significative digits that can be derived from the literal are generanted, significative
  #   meaning here that if the digit is changed and the value converted back to a literal of the same base and
  #   precision, the original literal will not be obtained.
  # * :short is a variation of :free in which only the minimun number of digits that are necessary to
  #   produce the original literal when the value is converted back with the same original precision.
  # * :fixed will round and normalize the value to the precision specified by the context (normalize meaning
  #   that exaclty the number of digits specified by the precision will be generated, even if the original
  #   literal has fewer digits.) This may fail returning NaN (and raising Inexact) if the context precision is
  #   :exact, but not if the floating-point radix is a multiple of the input base.
  #
  # Options that can be passed for construction from literal:
  # * :base is the numeric base of the input, 10 by default.
  #
  # The Flt.DecNum() constructor admits the same parameters and can be used as a shortcut for DecNum creation.
  # Examples:
  #   DecNum('0.1000')                                  # -> 0.1000
  #   DecNum('0.12345')                                 # -> 0.12345
  #   DecNum('1.2345E-1')                               # -> 0.12345
  #   DecNum('0.1000', :short)                          # -> 0.1
  #   DecNum('0.1000',:fixed, :precision=>20)           # -> 0.10000000000000000000
  #   DecNum('0.12345',:fixed, :precision=>20)          # -> 0.12345000000000000000
  #   DecNum('0.100110E3', :base=>2)                    # -> 4.8
  #   DecNum('0.1E-5', :free, :base=>2)                 # -> 0.016
  #   DecNum('0.1E-5', :short, :base=>2)                # -> 0.02
  #   DecNum('0.1E-5', :fixed, :base=>2, :exact=>true)  # -> 0.015625
  #   DecNum('0.1E-5', :fixed, :base=>2)                # -> 0.01562500000000000000000000000
  def initialize(*args)
    super(*args)
  end

  def number_of_digits
    @coeff.is_a?(Integer) ? _number_of_digits(@coeff) : 0
  end

  # Raises to the power of x, to modulo if given.
  #
  # With two arguments, compute self**other.  If self is negative then other
  # must be integral.  The result will be inexact unless other is
  # integral and the result is finite and can be expressed exactly
  # in 'precision' digits.
  #
  # With three arguments, compute (self**other) % modulo.  For the
  # three argument form, the following restrictions on the
  # arguments hold:
  #
  #  - all three arguments must be integral
  #  - other must be nonnegative
  #  - at least one of self or other must be nonzero
  #  - modulo must be nonzero and have at most 'precision' digits
  #
  # The result of a.power(b, modulo) is identical to the result
  # that would be obtained by computing (a**b) % modulo with
  # unbounded precision, but is computed more efficiently.  It is
  # always exact.
  def power(other, modulo=nil, context=nil)

    if context.nil? && (modulo.is_a?(Context) || modulo.is_a?(Hash))
      context = modulo
      modulo = nil
    end

    return self.power_modulo(other, modulo, context) if modulo

    context = DecNum.define_context(context)
    other = _convert(other)

    ans = _check_nans(context, other)
    return ans if ans

    # 0**0 = NaN (!), x**0 = 1 for nonzero x (including +/-Infinity)
    if other.zero?
      if self.zero?
        return context.exception(InvalidOperation, '0 ** 0')
      else
        return Num(1)
      end
    end

    # result has sign -1 iff self.sign is -1 and other is an odd integer
    result_sign = +1
    _self = self
    if _self.sign == -1
      if other.integral?
        result_sign = -1 if !other.even?
      else
        # -ve**noninteger = NaN
        # (-0)**noninteger = 0**noninteger
        unless self.zero?
          return context.exception(InvalidOperation, 'x ** y with x negative and y not an integer')
        end
      end
      # negate self, without doing any unwanted rounding
      _self = self.copy_negate
    end

    # 0**(+ve or Inf)= 0; 0**(-ve or -Inf) = Infinity
    if _self.zero?
      return (other.sign == +1) ? Num(result_sign, 0, 0) : num_class.infinity(result_sign)
    end

    # Inf**(+ve or Inf) = Inf; Inf**(-ve or -Inf) = 0
    if _self.infinite?
      return (other.sign == +1) ? num_class.infinity(result_sign) : Num(result_sign, 0, 0)
    end

    # 1**other = 1, but the choice of exponent and the flags
    # depend on the exponent of self, and on whether other is a
    # positive integer, a negative integer, or neither
    if _self == Num(1)
      return _self if context.exact?
      if other.integral?
        # exp = max(self._exp*max(int(other), 0),
        # 1-context.prec) but evaluating int(other) directly
        # is dangerous until we know other is small (other
        # could be 1e999999999)
        if other.sign == -1
          multiplier = 0
        elsif other > context.precision
          multiplier = context.precision
        else
          multiplier = other.to_i
        end

        exp = _self.exponent * multiplier
        if exp < 1-context.precision
          exp = 1-context.precision
          context.exception Rounded
        end
      else
        context.exception Rounded
        context.exception Inexact
        exp = 1-context.precision
      end

      return Num(result_sign, DecNum.int_radix_power(-exp), exp)
    end

    # compute adjusted exponent of self
    self_adj = _self.adjusted_exponent

    # self ** infinity is infinity if self > 1, 0 if self < 1
    # self ** -infinity is infinity if self < 1, 0 if self > 1
    if other.infinite?
      if (other.sign == +1) == (self_adj < 0)
        return Num(result_sign, 0, 0)
      else
        return DecNum.infinity(result_sign)
      end
    end

    # from here on, the result always goes through the call
    # to _fix at the end of this function.
    ans = nil

    # crude test to catch cases of extreme overflow/underflow.  If
    # log10(self)*other >= 10**bound and bound >= len(str(Emax))
    # then 10**bound >= 10**len(str(Emax)) >= Emax+1 and hence
    # self**other >= 10**(Emax+1), so overflow occurs.  The test
    # for underflow is similar.
    bound = _self._log10_exp_bound + other.adjusted_exponent
    if (self_adj >= 0) == (other.sign == +1)
      # self > 1 and other +ve, or self < 1 and other -ve
      # possibility of overflow
      if bound >= _number_of_digits(context.emax)
        ans = Num(result_sign, 1, context.emax+1)
      end
    else
      # self > 1 and other -ve, or self < 1 and other +ve
      # possibility of underflow to 0
      etiny = context.etiny
      if bound >= _number_of_digits(-etiny)
        ans = Num(result_sign, 1, etiny-1)
      end
    end

    # try for an exact result with precision +1
    if ans.nil?
      if context.exact?
        if other.adjusted_exponent < 100
          test_precision = _self.number_of_digits*other.to_i+1
        else
          test_precision = _self.number_of_digits+1
        end
      else
        test_precision = context.precision + 1
      end
      ans = _self._power_exact(other, test_precision)
      if !ans.nil? && (result_sign == -1)
        ans = Num(-1, ans.coefficient, ans.exponent)
      end
    end

    # usual case: inexact result, x**y computed directly as exp(y*log(x))
    if !ans.nil?
      return ans if context.exact?
    else
      return context.exception(Inexact, "Inexact power") if context.exact?

      p = context.precision
      xc = _self.coefficient
      xe = _self.exponent
      yc = other.coefficient
      ye = other.exponent
      yc = -yc if other.sign == -1

      # compute correctly rounded result:  start with precision +3,
      # then increase precision until result is unambiguously roundable
      extra = 3
      coeff, exp = nil, nil
      loop do
        coeff, exp = _dpower(xc, xe, yc, ye, p+extra)
        #break if (coeff % DecNum.int_mult_radix_power(5,coeff.to_s.length-p-1)) != 0
        break if (coeff % (5*10**(_number_of_digits(coeff)-p-1))) != 0
        extra += 3
      end
      ans = Num(result_sign, coeff, exp)
    end

    # the specification says that for non-integer other we need to
    # raise Inexact, even when the result is actually exact.  In
    # the same way, we need to raise Underflow here if the result
    # is subnormal.  (The call to _fix will take care of raising
    # Rounded and Subnormal, as usual.)
    if !other.integral?
      context.exception Inexact
      # pad with zeros up to length context.precision+1 if necessary
      if ans.number_of_digits <= context.precision
        expdiff = context.precision+1 - ans.number_of_digits
        ans = Num(ans.sign, DecNum.int_mult_radix_power(ans.coefficient, expdiff), ans.exponent-expdiff)
      end
      context.exception Underflow if ans.adjusted_exponent < context.emin
    end
    # unlike exp, ln and log10, the power function respects the
    # rounding mode; no need to use ROUND_HALF_EVEN here
    ans._fix(context)
  end

  # Returns the base 10 logarithm
  def log10(context=nil)
    context = DecNum.define_context(context)

    # log10(NaN) = NaN
    ans = _check_nans(context)
    return ans if ans

    # log10(0.0) == -Infinity
    return DecNum.infinity(-1) if self.zero?

    # log10(Infinity) = Infinity
    return DecNum.infinity if self.infinite? && self.sign == +1

    # log10(negative or -Infinity) raises InvalidOperation
    return context.exception(InvalidOperation, 'log10 of a negative value') if self.sign == -1

    digits = self.digits
    # log10(10**n) = n
    if digits.first == 1 && digits[1..-1].all?{|d| d==0}
      # answer may need rounding
      ans = Num(self.exponent + digits.size - 1)
      return ans if context.exact?
    else
      # result is irrational, so necessarily inexact
      return context.exception(Inexact, "Inexact power") if context.exact?
      c = self.coefficient
      e = self.exponent
      p = context.precision

      # correctly rounded result: repeatedly increase precision
      # until result is unambiguously roundable
      places = p-self._log10_exp_bound+2
      coeff = nil
      loop do
        coeff = _dlog10(c, e, places)
        # assert coeff.abs.to_s.length-p >= 1
        break if (coeff % (5*10**(_number_of_digits(coeff.abs)-p-1)))!=0
        places += 3
      end
      ans = Num(coeff<0 ? -1 : +1, coeff.abs, -places)
    end

    DecNum.context(context, :rounding=>:half_even) do |local_context|
      ans = ans._fix(local_context)
      context.flags = local_context.flags
    end
    return ans
  end

  # Exponential function
  def exp(context=nil)
    context = DecNum.define_context(context)

    # exp(NaN) = NaN
    ans = _check_nans(context)
    return ans if ans

    # exp(-Infinity) = 0
    return DecNum.zero if self.infinite? && (self.sign == -1)

    # exp(0) = 1
    return Num(1) if self.zero?

    # exp(Infinity) = Infinity
    return Num(self) if self.infinite?

    # the result is now guaranteed to be inexact (the true
    # mathematical result is transcendental). There's no need to
    # raise Rounded and Inexact here---they'll always be raised as
    # a result of the call to _fix.
    return context.exception(Inexact, 'Inexact exp') if context.exact?
    p = context.precision
    adj = self.adjusted_exponent

    # we only need to do any computation for quite a small range
    # of adjusted exponents---for example, -29 <= adj <= 10 for
    # the default context.  For smaller exponent the result is
    # indistinguishable from 1 at the given precision, while for
    # larger exponent the result either overflows or underflows.
    if self.sign == +1 and adj > _number_of_digits((context.emax+1)*3)
      # overflow
      ans = Num(+1, 1, context.emax+1)
    elsif self.sign == -1 and adj > _number_of_digits((-context.etiny+1)*3)
      # underflow to 0
      ans = Num(+1, 1, context.etiny-1)
    elsif self.sign == +1 and adj < -p
      # p+1 digits; final round will raise correct flags
      ans = Num(+1, DecNum.int_radix_power(p)+1, -p)
    elsif self.sign == -1 and adj < -p-1
      # p+1 digits; final round will raise correct flags
      ans = Num(+1, DecNum.int_radix_power(p+1)-1, -p-1)
    else
      # general case
      c = self.coefficient
      e = self.exponent
      c = -c if self.sign == -1

      # compute correctly rounded result: increase precision by
      # 3 digits at a time until we get an unambiguously
      # roundable result
      extra = 3
      coeff = exp = nil
      loop do
        coeff, exp = _dexp(c, e, p+extra)
        break if (coeff % (5*10**(_number_of_digits(coeff)-p-1)))!=0
        extra += 3
      end
      ans = Num(+1, coeff, exp)
    end

    # at this stage, ans should round correctly with *any*
    # rounding mode, not just with ROUND_HALF_EVEN
    DecNum.context(context, :rounding=>:half_even) do |local_context|
      ans = ans._fix(local_context)
      context.flags = local_context.flags
    end

    return ans
  end

  # Returns the natural (base e) logarithm
  def ln(context=nil)
    context = DecNum.define_context(context)

    # ln(NaN) = NaN
    ans = _check_nans(context)
    return ans if ans

    # ln(0.0) == -Infinity
    return DecNum.infinity(-1) if self.zero?

    # ln(Infinity) = Infinity
    return DecNum.infinity if self.infinite? && self.sign == +1

    # ln(1.0) == 0.0
    return DecNum.zero if self == Num(1)

    # ln(negative) raises InvalidOperation
    return context.exception(InvalidOperation, 'ln of a negative value') if self.sign==-1

    # result is irrational, so necessarily inexact
    return context.exception(Inexact, 'Inexact exp') if context.exact?

    c = self.coefficient
    e = self.exponent
    p = context.precision

    # correctly rounded result: repeatedly increase precision by 3
    # until we get an unambiguously roundable result
    places = p - self._ln_exp_bound + 2 # at least p+3 places
    coeff = nil
    loop do
      coeff = _dlog(c, e, places)
      # assert coeff.to_s.length-p >= 1
      break if (coeff % (5*10**(_number_of_digits(coeff.abs)-p-1))) != 0
      places += 3
    end
    ans = Num((coeff<0) ? -1 : +1, coeff.abs, -places)

    DecNum.context(context, :rounding=>:half_even) do |local_context|
      ans = ans._fix(local_context)
      context.flags = local_context.flags
    end
    return ans
  end

  # Auxiliar Methods



  # Power-modulo: self._power_modulo(other, modulo) == (self**other) % modulo
  # This is equivalent to Python's 3-argument version of pow()
  def _power_modulo(other, modulo, context=nil)

    context = DecNum.define_context(context)
    other = _convert(other)
    modulo = _convert(third)

    if self.nan? || other.nan? || modulo.nan?
      return context.exception(InvalidOperation, 'sNaN', self) if self.snan?
      return context.exception(InvalidOperation, 'sNaN', other) if other.snan?
      return context.exception(InvalidOperation, 'sNaN', modulo) if other.modulo?
      return self._fix_nan(context) if self.nan?
      return other._fix_nan(context) if other.nan?
      return modulo._fix_nan(context) # if modulo.nan?
    end

    if !(self.integral? && other.integral? && modulo.integral?)
      return context.exception(InvalidOperation, '3-argument power not allowed unless all arguments are integers.')
    end

    if other < 0
      return context.exception(InvalidOperation, '3-argument power cannot have a negative 2nd argument.')
    end

    if modulo.zero?
      return context.exception(InvalidOperation, '3-argument power cannot have a 0 3rd argument.')
    end

    if modulo.adjusted_exponent >= context.precision
      return context.exception(InvalidOperation, 'insufficient precision: power 3rd argument must not have more than precision digits')
    end

    if other.zero? && self.zero?
      return context.exception(InvalidOperation, "0**0 not defined")
    end

    sign = other.even? ? +1 : -1
    modulo = modulo.to_i.abs

    base = (self.coefficient % modulo * (DecNum.int_radix_power(self.exponent) % modulo)) % modulo

    other.exponent.times do
      base = (base**DecNum.radix) % modulo
    end
    base = (base**other.coefficient) % modulo

    Num(sign, base, 0)
  end

  # Attempt to compute self**other exactly
  # Given Decimals self and other and an integer p, attempt to
  # compute an exact result for the power self**other, with p
  # digits of precision.  Return nil if self**other is not
  # exactly representable in p digits.
  #
  # Assumes that elimination of special cases has already been
  # performed: self and other must both be nonspecial; self must
  # be positive and not numerically equal to 1; other must be
  # nonzero.  For efficiency, other.exponent should not be too large,
  # so that 10**other.exponent.abs is a feasible calculation.
  def _power_exact(other, p)

    # In the comments below, we write x for the value of self and
    # y for the value of other.  Write x = xc*10**xe and y =
    # yc*10**ye.

    # The main purpose of this method is to identify the *failure*
    # of x**y to be exactly representable with as little effort as
    # possible.  So we look for cheap and easy tests that
    # eliminate the possibility of x**y being exact.  Only if all
    # these tests are passed do we go on to actually compute x**y.

    # Here's the main idea.  First normalize both x and y.  We
    # express y as a rational m/n, with m and n relatively prime
    # and n>0.  Then for x**y to be exactly representable (at
    # *any* precision), xc must be the nth power of a positive
    # integer and xe must be divisible by n.  If m is negative
    # then additionally xc must be a power of either 2 or 5, hence
    # a power of 2**n or 5**n.
    #
    # There's a limit to how small |y| can be: if y=m/n as above
    # then:
    #
    #  (1) if xc != 1 then for the result to be representable we
    #      need xc**(1/n) >= 2, and hence also xc**|y| >= 2.  So
    #      if |y| <= 1/nbits(xc) then xc < 2**nbits(xc) <=
    #      2**(1/|y|), hence xc**|y| < 2 and the result is not
    #      representable.
    #
    #  (2) if xe != 0, |xe|*(1/n) >= 1, so |xe|*|y| >= 1.  Hence if
    #      |y| < 1/|xe| then the result is not representable.
    #
    # Note that since x is not equal to 1, at least one of (1) and
    # (2) must apply.  Now |y| < 1/nbits(xc) iff |yc|*nbits(xc) <
    # 10**-ye iff len(str(|yc|*nbits(xc)) <= -ye.
    #
    # There's also a limit to how large y can be, at least if it's
    # positive: the normalized result will have coefficient xc**y,
    # so if it's representable then xc**y < 10**p, and y <
    # p/log10(xc).  Hence if y*log10(xc) >= p then the result is
    # not exactly representable.

    # if len(str(abs(yc*xe)) <= -ye then abs(yc*xe) < 10**-ye,
    # so |y| < 1/xe and the result is not representable.
    # Similarly, len(str(abs(yc)*xc_bits)) <= -ye implies |y|
    # < 1/nbits(xc).

    xc = self.coefficient
    xe = self.exponent
    while (xc % DecNum.radix) == 0
      xc /= DecNum.radix
      xe += 1
    end

    yc = other.coefficient
    ye = other.exponent
    while (yc % DecNum.radix) == 0
      yc /= DecNum.radix
      ye += 1
    end

    # case where xc == 1: result is 10**(xe*y), with xe*y
    # required to be an integer
    if xc == 1
      if ye >= 0
        exponent = xe*yc*DecNum.int_radix_power(ye)
      else
        exponent, remainder = (xe*yc).divmod(DecNum.int_radix_power(-ye))
        return nil if remainder!=0
      end
      exponent = -exponent if other.sign == -1
      # if other is a nonnegative integer, use ideal exponent
      if other.integral? and (other.sign == +1)
        ideal_exponent = self.exponent*other.to_i
        zeros = [exponent-ideal_exponent, p-1].min
      else
        zeros = 0
      end
      return Num(+1, DecNum.int_radix_power(zeros), exponent-zeros)
    end

    # case where y is negative: xc must be either a power
    # of 2 or a power of 5.
    if other.sign == -1
      last_digit = (xc % 10)
      if [2,4,6,8].include?(last_digit)
        # quick test for power of 2
        return nil if xc & -xc != xc
        # now xc is a power of 2; e is its exponent
        e = _nbits(xc)-1
        # find e*y and xe*y; both must be integers
        if ye >= 0
          y_as_int = yc*DecNum.int_radix_power(ye)
          e = e*y_as_int
          xe = xe*y_as_int
        else
          ten_pow = DecNum.int_radix_power(-ye)
          e, remainder = (e*yc).divmod(ten_pow)
          return nil if remainder!=0
          xe, remainder = (xe*yc).divmod(ten_pow)
          return nil if remainder!=0
        end

        return nil if e*65 >= p*93 # 93/65 > log(10)/log(5)
        xc = 5**e
      elsif last_digit == 5
        # e >= log_5(xc) if xc is a power of 5; we have
        # equality all the way up to xc=5**2658
        e = _nbits(xc)*28/65
        xc, remainder = (5**e).divmod(xc)
        return nil if remainder!=0
        while (xc % 5) == 0
          xc /= 5
          e -= 1
        end
        if ye >= 0
          y_as_integer = DecNum.int_mult_radix_power(yc,ye)
          e = e*y_as_integer
          xe = xe*y_as_integer
        else
          ten_pow = DecNum.int_radix_power(-ye)
          e, remainder = (e*yc).divmod(ten_pow)
          return nil if remainder
          xe, remainder = (xe*yc).divmod(ten_pow)
          return nil if remainder
        end
        return nil if e*3 >= p*10 # 10/3 > log(10)/log(2)
        xc = 2**e
      else
        return nil
      end

      return nil if xc >= DecNum.int_radix_power(p)
      xe = -e-xe
      return Num(+1, xc, xe)

    end

    # now y is positive; find m and n such that y = m/n
    if ye >= 0
      m, n = yc*10**ye, 1
    else
      return nil if (xe != 0) and (_number_of_digits((yc*xe).abs) <= -ye)
      xc_bits = _nbits(xc)
      return nil if (xc != 1) and (_number_of_digits(yc.abs*xc_bits) <= -ye)
      m, n = yc, DecNum.int_radix_power(-ye)
      while ((m % 2) == 0) && ((n % 2) == 0)
        m /= 2
        n /= 2
      end
      while ((m % 5) == 0) && ((n % 5) == 0)
        m /= 5
        n /= 5
      end
    end

    # compute nth root of xc*10**xe
    if n > 1
      # if 1 < xc < 2**n then xc isn't an nth power
      return nil if xc != 1 and xc_bits <= n

      xe, rem = xe.divmod(n)
      return nil if rem != 0

      # compute nth root of xc using Newton's method
      a = 1 << -(-_nbits(xc)/n) # initial estimate
      q = r = nil
      loop do
        q, r = xc.divmod(a**(n-1))
        break if a <= q
        a = (a*(n-1) + q)/n
      end
      return nil if !((a == q) and (r == 0))
      xc = a
    end

    # now xc*10**xe is the nth root of the original xc*10**xe
    # compute mth power of xc*10**xe

    # if m > p*100/_log10_lb(xc) then m > p/log10(xc), hence xc**m >
    # 10**p and the result is not representable.
    return nil if (xc > 1) and (m > p*100/_log10_lb(xc))
    xc = xc**m
    xe *= m
    return nil if xc > 10**p

    # by this point the result *is* exactly representable
    # adjust the exponent to get as close as possible to the ideal
    # exponent, if necessary
    if other.integral? && other.sign == +1
      ideal_exponent = self.exponent*other.to_i
      zeros = [xe-ideal_exponent, p-_number_of_digits(xc)].min
    else
      zeros = 0
    end
    return Num(+1, DecNum.int_mult_radix_power(xc, zeros), xe-zeros)
  end

  # Compute a lower bound for the adjusted exponent of self.log10()
  # In other words, find r such that self.log10() >= 10**r.
  # Assumes that self is finite and positive and that self != 1.
  def _log10_exp_bound
    # For x >= 10 or x < 0.1 we only need a bound on the integer
    # part of log10(self), and this comes directly from the
    # exponent of x.  For 0.1 <= x <= 10 we use the inequalities
    # 1-1/x <= log(x) <= x-1. If x > 1 we have |log10(x)| >
    # (1-1/x)/2.31 > 0.  If x < 1 then |log10(x)| > (1-x)/2.31 > 0
    #
    # The original Python cod used lexical order (having converted to strings) for (num < den) and (num < 231)
    # so the results would be different e.g. for num = 9; Can this happen? What is the correct way?

    adj = self.exponent + number_of_digits - 1
    return _number_of_digits(adj) - 1 if adj >= 1 # self >= 10
    return _number_of_digits(-1-adj)-1 if adj <= -2 # self < 0.1

    c = self.coefficient
    e = self.exponent
    if adj == 0
      # 1 < self < 10
      num = (c - DecNum.int_radix_power(-e))
      den = (231*c)
      return _number_of_digits(num) - _number_of_digits(den) - ((num < den) ? 1 : 0) + 2
    end
    # adj == -1, 0.1 <= self < 1
    num = (DecNum.int_radix_power(-e)-c)
    return _number_of_digits(num.to_i) + e - ((num < 231) ? 1 : 0) - 1
  end

  # Compute a lower bound for the adjusted exponent of self.ln().
  # In other words, compute r such that self.ln() >= 10**r.  Assumes
  # that self is finite and positive and that self != 1.
  def _ln_exp_bound
    # for 0.1 <= x <= 10 we use the inequalities 1-1/x <= ln(x) <= x-1
    #
    # The original Python cod used lexical order (having converted to strings) for (num < den))
    # so the results would be different e.g. for num = 9m den=200; Can this happen? What is the correct way?

    adj = self.exponent + number_of_digits - 1
    if adj >= 1
      # argument >= 10; we use 23/10 = 2.3 as a lower bound for ln(10)
      return _number_of_digits(adj*23/10) - 1
    end
    if adj <= -2
      # argument <= 0.1
      return _number_of_digits((-1-adj)*23/10) - 1
    end
    c = self.coefficient
    e = self.exponent
    if adj == 0
      # 1 < self < 10
      num = c-(10**-e)
      den = c
      return _number_of_digits(num) - _number_of_digits(den) - ((num < den) ? 1 : 0)
    end
    # adj == -1, 0.1 <= self < 1
    return e + _number_of_digits(10**-e - c) - 1
  end

  module AuxiliarFunctions #:nodoc:

    module_function

    # Given integers xc, xe, yc and ye representing Decimals x = xc*10**xe and
    # y = yc*10**ye, compute x**y.  Returns a pair of integers (c, e) such that:
    #
    #   10**(p-1) <= c <= 10**p, and
    #   (c-1)*10**e < x**y < (c+1)*10**e
    #
    # in other words, c*10**e is an approximation to x**y with p digits
    # of precision, and with an error in c of at most 1.  (This is
    # almost, but not quite, the same as the error being < 1ulp: when c
    # == 10**(p-1) we can only guarantee error < 10ulp.)
    #
    # We assume that: x is positive and not equal to 1, and y is nonzero.
    def _dpower(xc, xe, yc, ye, p)
      # Find b such that 10**(b-1) <= |y| <= 10**b
      b = _number_of_digits(yc.abs) + ye

      # log(x) = lxc*10**(-p-b-1), to p+b+1 places after the decimal point
      lxc = _dlog(xc, xe, p+b+1)

      # compute product y*log(x) = yc*lxc*10**(-p-b-1+ye) = pc*10**(-p-1)
      shift = ye-b
      if shift >= 0
          pc = lxc*yc*10**shift
      else
          pc = _div_nearest(lxc*yc, 10**-shift)
      end

      if pc == 0
          # we prefer a result that isn't exactly 1; this makes it
          # easier to compute a correctly rounded result in __pow__
          if (_number_of_digits(xc) + xe >= 1) == (yc > 0) # if x**y > 1:
              coeff, exp = 10**(p-1)+1, 1-p
          else
              coeff, exp = 10**p-1, -p
          end
      else
          coeff, exp = _dexp(pc, -(p+1), p+1)
          coeff = _div_nearest(coeff, 10)
          exp += 1
      end

      return coeff, exp
    end

    # Compute an approximation to exp(c*10**e), with p decimal places of precision.
    # Returns integers d, f such that:
    #
    #   10**(p-1) <= d <= 10**p, and
    #   (d-1)*10**f < exp(c*10**e) < (d+1)*10**f
    #
    # In other words, d*10**f is an approximation to exp(c*10**e) with p
    # digits of precision, and with an error in d of at most 1.  This is
    # almost, but not quite, the same as the error being < 1ulp: when d
    # = 10**(p-1) the error could be up to 10 ulp.
    def _dexp(c, e, p)
        # we'll call iexp with M = 10**(p+2), giving p+3 digits of precision
        p += 2

        # compute log(10) with extra precision = adjusted exponent of c*10**e
        # TODO: without the .abs tests fail because c is negative: c should not be negative!!
        extra = [0, e + _number_of_digits(c.abs) - 1].max
        q = p + extra

        # compute quotient c*10**e/(log(10)) = c*10**(e+q)/(log(10)*10**q),
        # rounding down
        shift = e+q
        if shift >= 0
            cshift = c*10**shift
        else
            cshift = c/10**-shift
        end
        quot, rem = cshift.divmod(_log10_digits(q))

        # reduce remainder back to original precision
        rem = _div_nearest(rem, 10**extra)

        # error in result of _iexp < 120;  error after division < 0.62
        return _div_nearest(_iexp(rem, 10**p), 1000), quot - p + 3
    end

    # Closest integer to a/b, a and b positive integers; rounds to even
    # in the case of a tie.
    def _div_nearest(a, b)
      q, r = a.divmod(b)
      q + (((2*r + (q&1)) > b) ? 1 : 0)
    end

    # Closest integer to the square root of the positive integer n.  a is
    # an initial approximation to the square root.  Any positive integer
    # will do for a, but the closer a is to the square root of n the
    # faster convergence will be.
    def _sqrt_nearest(n, a)

        if n <= 0 or a <= 0
            raise ArgumentError, "Both arguments to _sqrt_nearest should be positive."
        end

        b=0
        while a != b
            b, a = a, a--n/a>>1 # ??
        end
        return a
    end

    # Given an integer x and a nonnegative integer shift, return closest
    # integer to x / 2**shift; use round-to-even in case of a tie.
    def _rshift_nearest(x, shift)
        b, q = (1 << shift), (x >> shift)
        return q + (((2*(x & (b-1)) + (q&1)) > b) ? 1 : 0)
        #return q + (2*(x & (b-1)) + (((q&1) > b) ? 1 : 0))
    end

    # Integer approximation to M*log(x/M), with absolute error boundable
    # in terms only of x/M.
    #
    # Given positive integers x and M, return an integer approximation to
    # M * log(x/M).  For L = 8 and 0.1 <= x/M <= 10 the difference
    # between the approximation and the exact result is at most 22.  For
    # L = 8 and 1.0 <= x/M <= 10.0 the difference is at most 15.  In
    # both cases these are upper bounds on the error; it will usually be
    # much smaller.
    def _ilog(x, m, l = 8)
      # The basic algorithm is the following: let log1p be the function
      # log1p(x) = log(1+x).  Then log(x/M) = log1p((x-M)/M).  We use
      # the reduction
      #
      #    log1p(y) = 2*log1p(y/(1+sqrt(1+y)))
      #
      # repeatedly until the argument to log1p is small (< 2**-L in
      # absolute value).  For small y we can use the Taylor series
      # expansion
      #
      #    log1p(y) ~ y - y**2/2 + y**3/3 - ... - (-y)**T/T
      #
      # truncating at T such that y**T is small enough.  The whole
      # computation is carried out in a form of fixed-point arithmetic,
      # with a real number z being represented by an integer
      # approximation to z*M.  To avoid loss of precision, the y below
      # is actually an integer approximation to 2**R*y*M, where R is the
      # number of reductions performed so far.

      y = x-m
      # argument reduction; R = number of reductions performed
      r = 0
      # while (r <= l && y.abs << l-r >= m ||
      #        r > l and y.abs>> r-l >= m)
      while (((r <= l) && ((y.abs << (l-r)) >= m)) ||
             ((r > l) && ((y.abs>>(r-l)) >= m)))
          y = _div_nearest((m*y) << 1,
                           m + _sqrt_nearest(m*(m+_rshift_nearest(y, r)), m))
          r += 1
      end

      # Taylor series with T terms
      t = -(-10*_number_of_digits(m)/(3*l)).to_i
      yshift = _rshift_nearest(y, r)
      w = _div_nearest(m, t)
      # (1...t).reverse_each do |k| # Ruby 1.9
      (1...t).to_a.reverse.each do |k|
         w = _div_nearest(m, k) - _div_nearest(yshift*w, m)
      end

      return _div_nearest(w*y, m)
    end

    # Given integers c, e and p with c > 0, p >= 0, compute an integer
    # approximation to 10**p * log10(c*10**e), with an absolute error of
    # at most 1.  Assumes that c*10**e is not exactly 1.
    def _dlog10(c, e, p)
       # increase precision by 2; compensate for this by dividing
      # final result by 100
      p += 2

      # write c*10**e as d*10**f with either:
      #   f >= 0 and 1 <= d <= 10, or
      #   f <= 0 and 0.1 <= d <= 1.
      # Thus for c*10**e close to 1, f = 0
      l = _number_of_digits(c)
      f = e+l - ((e+l >= 1) ? 1 : 0)

      if p > 0
        m = 10**p
        k = e+p-f
        if k >= 0
          c *= 10**k
        else
          c = _div_nearest(c, 10**-k)
        end
        log_d = _ilog(c, m) # error < 5 + 22 = 27
        log_10 = _log10_digits(p) # error < 1
        log_d = _div_nearest(log_d*m, log_10)
        log_tenpower = f*m # exact
      else
        log_d = 0  # error < 2.31
        log_tenpower = _div_nearest(f, 10**-p) # error < 0.5
      end

      return _div_nearest(log_tenpower+log_d, 100)
    end

    # Compute a lower bound for 100*log10(c) for a positive integer c.
    def _log10_lb(c)
        raise ArgumentError, "The argument to _log10_lb should be nonnegative." if c <= 0
        str_c = c.to_s
        return 100*str_c.length - LOG10_LB_CORRECTION[str_c[0,1]]
    end
    LOG10_LB_CORRECTION = { # (1..9).map_hash{|i| 100 - (100*Math.log10(i)).floor}
      '1'=> 100, '2'=> 70, '3'=> 53, '4'=> 40, '5'=> 31,
      '6'=> 23, '7'=> 16, '8'=> 10, '9'=> 5}

    # Given integers c, e and p with c > 0, compute an integer
    # approximation to 10**p * log(c*10**e), with an absolute error of
    # at most 1.  Assumes that c*10**e is not exactly 1.
    def _dlog(c, e, p)

        # Increase precision by 2. The precision increase is compensated
        # for at the end with a division by 100.
        p += 2

        # rewrite c*10**e as d*10**f with either f >= 0 and 1 <= d <= 10,
        # or f <= 0 and 0.1 <= d <= 1.  Then we can compute 10**p * log(c*10**e)
        # as 10**p * log(d) + 10**p*f * log(10).
        l = _number_of_digits(c)
        f = e+l - ((e+l >= 1) ? 1 : 0)

        # compute approximation to 10**p*log(d), with error < 27
        if p > 0
            k = e+p-f
            if k >= 0
                c *= 10**k
            else
                c = _div_nearest(c, 10**-k)  # error of <= 0.5 in c
            end

            # _ilog magnifies existing error in c by a factor of at most 10
            log_d = _ilog(c, 10**p) # error < 5 + 22 = 27
        else
            # p <= 0: just approximate the whole thing by 0; error < 2.31
            log_d = 0
        end

        # compute approximation to f*10**p*log(10), with error < 11.
        if f
            extra = _number_of_digits(f.abs) - 1
            if p + extra >= 0
                # error in f * _log10_digits(p+extra) < |f| * 1 = |f|
                # after division, error < |f|/10**extra + 0.5 < 10 + 0.5 < 11
                f_log_ten = _div_nearest(f*_log10_digits(p+extra), 10**extra)
            else
                f_log_ten = 0
            end
        else
            f_log_ten = 0
        end

        # error in sum < 11+27 = 38; error after division < 0.38 + 0.5 < 1
        return _div_nearest(f_log_ten + log_d, 100)
    end

    # Given integers x and M, M > 0, such that x/M is small in absolute
    # value, compute an integer approximation to M*exp(x/M).  For 0 <=
    # x/M <= 2.4, the absolute error in the result is bounded by 60 (and
    # is usually much smaller).
    def _iexp(x, m, l=8)

        # Algorithm: to compute exp(z) for a real number z, first divide z
        # by a suitable power R of 2 so that |z/2**R| < 2**-L.  Then
        # compute expm1(z/2**R) = exp(z/2**R) - 1 using the usual Taylor
        # series
        #
        #     expm1(x) = x + x**2/2! + x**3/3! + ...
        #
        # Now use the identity
        #
        #     expm1(2x) = expm1(x)*(expm1(x)+2)
        #
        # R times to compute the sequence expm1(z/2**R),
        # expm1(z/2**(R-1)), ... , exp(z/2), exp(z).

        # Find R such that x/2**R/M <= 2**-L
        r = _nbits((x<<l)/m)

        # Taylor series.  (2**L)**T > M
        t = -(-10*_number_of_digits(m)/(3*l)).to_i
        y = _div_nearest(x, t)
        mshift = m<<r
        (1...t).to_a.reverse.each do |i|
            y = _div_nearest(x*(mshift + y), mshift * i)
        end

        # Expansion
        (0...r).to_a.reverse.each do |k|
            mshift = m<<(k+2)
            y = _div_nearest(y*(y+mshift), mshift)
        end

        return m+y
    end

    # We'll memoize the digits of log(10):
    @log10_digits = "23025850929940456840179914546843642076011014886"
    class <<self
      attr_accessor :log10_digits
    end

    # Given an integer p >= 0, return floor(10**p)*log(10).
    def _log10_digits(p)
      # digits are stored as a string, for quick conversion to
      # integer in the case that we've already computed enough
      # digits; the stored digits should always be correct
      # (truncated, not rounded to nearest).
      raise ArgumentError, "p should be nonnegative" if p<0
      if p >= AuxiliarFunctions.log10_digits.length
          digits = nil
          # compute p+3, p+6, p+9, ... digits; continue until at
          # least one of the extra digits is nonzero
          extra = 3
          loop do
            # compute p+extra digits, correct to within 1ulp
            m = 10**(p+extra+2)
            digits = _div_nearest(_ilog(10*m, m), 100).to_s
            break if digits[-extra..-1] != '0'*extra
            extra += 3
          end
          # keep all reliable digits so far; remove trailing zeros
          # and next nonzero digit
          AuxiliarFunctions.log10_digits = digits.sub(/0*$/,'')[0...-1]
      end
      return (AuxiliarFunctions.log10_digits[0...p+1]).to_i
    end

    # Compute an approximation to exp(c*10**e), with p decimal places of
    # precision.
    #
    # Returns integers d, f such that:
    #
    #   10**(p-1) <= d <= 10**p, and
    #   (d-1)*10**f < exp(c*10**e) < (d+1)*10**f
    #
    # In other words, d*10**f is an approximation to exp(c*10**e) with p
    # digits of precision, and with an error in d of at most 1.  This is
    # almost, but not quite, the same as the error being < 1ulp: when d
    # = 10**(p-1) the error could be up to 10 ulp.
    def dexp(c, e, p)
      # we'll call iexp with M = 10**(p+2), giving p+3 digits of precision
      p += 2

      # compute log(10) with extra precision = adjusted exponent of c*10**e
      extra = [0, e + _number_of_digits(c) - 1].max
      q = p + extra

      # compute quotient c*10**e/(log(10)) = c*10**(e+q)/(log(10)*10**q),
      # rounding down
      shift = e+q
      if shift >= 0
          cshift = c*10**shift
      else
          cshift = c/10**-shift
      end
      quot, rem = cshift.divmod(_log10_digits(q))

      # reduce remainder back to original precision
      rem = _div_nearest(rem, 10**extra)

      # error in result of _iexp < 1s20;  error after division < 0.62
      return _div_nearest(_iexp(rem, 10**p), 1000), quot - p + 3
    end

    # number of bits in a nonnegative integer
    def _number_of_digits(i)
      raise  TypeError, "The argument to _number_of_digits should be nonnegative." if i < 0
      if i.is_a?(Fixnum) || (i > NUMBER_OF_DIGITS_MAX_VALID_LOG)
        # for short integers this is faster
        # note that here we return 1 for 0
        i.to_s.length
      else
        (::Math.log10(i)+1).floor
      end
    end
    NUMBER_OF_DIGITS_MAX_VALID_LOG = 10**(Float::DIG-1)

  end # AuxiliarFunctions

  # This is for using auxiliar functions from DecNum instance method
  # without the "AuxiliarFunctions." prefix
  include AuxiliarFunctions
  # If we need to use them from DecNum class methods, we can avoid
  # the use of the prefix with:
  # extend AuxiliarFunctions

end

module_function
# DecNum constructor. See DecNum#new for the parameters.
# If a DecNum is passed a reference to it is returned (no new object is created).
def DecNum(*args)
  DecNum.Num(*args)
end

end # Flt