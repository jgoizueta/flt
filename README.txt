= Introduction

Decimal is a standards-compliant arbitrary precision decimal floating-point type for Ruby.
It is based on the Python Decimal class.

The current implementation is written completely in Ruby, so it is rather slow.
The intentention is to experiment with this pure-ruby implementation to
define a nice feature-set and API for Decimal and have a good test suite for its
specification. Then an efficient implementation could be written, for example
by using a C extension wrapper around the decNumber library.

The documentation for this package is available at http://ruby-decimal.rubyforge.org/

The code is at http://github.com/jgoizueta/ruby-decimal/

== Standars compliance.

Decimal pretends to be conformant to the General Decimal Arithmetic Specification
and the revised IEEE 754 standard (IEEE 754-2008).

= Examples of use

To install the library use gem from the command line: (you may not need +sudo+)
  sudo gem install ruby-decimal

Then require the library in your code (if it fails you may need to <tt>require 'rubygems'</tt> first)
  require 'decimal'

Now we can use the Decimal class simply like this:

  puts Decimal(1)/Decimal(3)                         -> 0.3333333333333333333333333333

Decimal() is a constructor that can be used instead of Decimal.new()

== Contexts

Contexts are environments for arithmetic operations. They govern precision, set rules
for rounding, determine which signals are treated as exceptions, and limit the range
for exponents.

Each thread has an active context that can be accessed like this:

  puts Decimal.context.precision                     -> 28

The active context can be globally for the current thread:

  Decimal.context.precision = 2
  puts Decimal.context.precision                     -> 2
  puts Decimal(1)/Decimal(3)                         -> 0.33
  Decimal.context.precision += 7
  puts Decimal.context.precision                     -> 9
  puts Decimal(1)/Decimal(3)                         -> 0.333333333

Or it can be altered locally inside a block:

  Decimal.context do
    Decimal.context.precision = 5
    puts Decimal.context.precision
  end                                                -> 5
  puts Decimal.context.precision                     -> 9

The block for a local context can be passed the current context as an argument:

  Decimal.context do |local_context|
    local_context.precision = 5
    puts Decimal.context.precision
  end                                                -> 5
  puts Decimal.context.precision                     -> 9

A context object can be used to define the local context:

  my_context = Decimal::Context(:precision=>20)
  Decimal.context(my_context) do |context|
    puts context.precision
  end                                                -> 20

And individual parameters can be assigned like this:

  puts Decimal.context.precision                     -> 9
  puts Decimal.context.rounding                      -> half_even
  Decimal.context(:rounding=>:down) do |context|
    puts context.precision                           -> 9
    puts context.rounding                            -> down
  end

Contexts created with the Decimal::Context() constructor
inherit from Decimal::DefaultContext.
Default context attributes can be established by modifying
that object:

  Decimal::DefaultContext.precision = 10
  Decimal.context = Decimal::Context(:rounding=>:half_up)
  puts Decimal.context.precision                     -> 10

Note that a context object assigned to Decimal.context is copied,
so it is not altered through Decimal.context:

  puts my_context.precision                          -> 20
  Decimal.context = my_context
  Decimal.context.precision = 2
  puts my_context.precision                          -> 20

So, DefaultContext is not altered when modifying Decimal.context.

Methods that use a context have an optional parameter to override
the active context (Decimal.context) :

  Decimal.context.precision = 3
  puts Decimal(1).divide(3)                          -> 0.333
  puts Decimal(1).divide(3, my_context)              -> 0.33333333333333333333

Individual context parameters can also be overriden:

  puts Decimal(1).divide(3, :precision=>6)           -> 0.333333

There are two additional predefined contexts Decimal::ExtendedContext
and Decimal::BasicContext that are not meant to be modified; they
can be used to achieve reproducible results. We will use
Decimal::ExtendedContext in the following examples:

  Decimal.context = Decimal::ExtendedContext

Most decimal operations can be executed by using either Context or Decimal methods:

  puts Decimal.context.exp(1)                        -> 2.71828183
  puts Decimal(1).exp                                -> 2.71828183

If using Context methods, values are automatically converted as if the Decimal() constructor
was used.

==Rounding

Results are normally rounded using the precision (number of significant digits)
and rounding mode defined in the context.

  Decimal.context.precision = 4
  puts Decimal(1)/Decimal(3)                         -> 0.3333
  puts Decimal('1E20')-Decimal('1E-20')              -> 1.000E+20
  Decimal.context.rounding = :half_up
  puts +Decimal('100.05')                            -> 100.1
  Decimal.context.rounding = :half_even
  puts +Decimal('100.05')                            -> 100.0

Note that input values are not rounded, only results; we use
the plus operator to force rounding here:

  Decimal.context.precision = 4
  x = Decimal('123.45678')
  puts x                                             -> 123.45678
  puts +x                                            -> 123.5

Precision can be also set to exact to avoid rounding, by using
the exact property or using a 0 precision. In exact mode results
are never rounded and results that have an infinite number of
digits trigger the Decimal::Inexact exception.

  Decimal.context.exact = true
  puts Decimal('1E20')-Decimal('1E-20')              -> 99999999999999999999.99999999999999999999
  puts Decimal(16).sqrt                              -> 4
  puts Decimal(16)/Decimal(4)                        -> 4
  puts Decimal(1)/Decimal(3)                         -> Exception : Decimal::Inexact

  Decimal.context.precision = 5
  puts Decimal('1E20')-Decimal('1E-20')              -> 1.0000E+20
  puts Decimal(16).sqrt                              -> 4
  puts Decimal(16)/Decimal(4)                        -> 4
  puts Decimal(1)/Decimal(3)                         -> 0.33333

There are also some methods for explicit rounding that provide
an interface compatible with the Ruby interface of Float:

  puts Decimal('101.5').round                        -> 102
  puts Decimal('101.5').round(0)                     -> 102
  puts Decimal('101.12345').round(2)                 -> 101.12
  puts Decimal('101.12345').round(-1)                -> 1.0E+2
  puts Decimal('101.12345').round(:places=>2)        -> 101.12
  puts Decimal('101.12345').round(:precision=>2)     -> 1.0E+2
  puts Decimal('101.5').round(:rounding=>:half_up)   -> 102
  puts Decimal('101.5').ceil                         -> 102
  puts Decimal('101.5').floor                        -> 101
  puts Decimal('101.5').truncate                     -> 101

==Special values

In addition to finite numbers, a Decimal object can represent some special values:
* Infinity (+Infinity, -Infinity). The method Decimal#infinite? returns true for these to values.
  Decimal.infinity Decimal.infinity(-1) can be used to get these values.
* NaN (not a number) represents indefined results. The method Decimal#nan? returns true for it and
  Decimal.nan can be used to obtain it. There is a variant, sNaN (signaling NaN) that casues
  an invalid operation condition if used; it can be detected with Decimal.snan?.
  A NaN can also include diagnostic information in its sign and coefficient.

Any of the special values can be detected with Decimal#special?
Finite numbers can be clasified with
these methods:
* Decimal#zero? detects a zero value (note that there are two zero values: +0 and -0)
* Decimal#normal? detects normal values: those whose adjusted exponents are not less than the the emin.
* Decimal#subnormal? detects subnormal values: those whose adjusted exponents are less than the the emin.

==Exceptions

Exceptional conditions that may arise during operations have corresponding classes that represent them:
* Decimal::InvalidOperation
* Decimal::DivisionByZero
* Decimal::DivisionImpossible
* Decimal::DivisionUndefined
* Decimal::Inexact
* Decimal::Overflow
* Decimal::Underflow
* Decimal::Clamped
* Decimal::InvalidContext
* Decimal::Rounded
* Decimal::Subnormal
* Decimal::ConversionSyntax

For each condition, a flag and a trap (boolean values) exist in the context.
When a condition occurs, the corresponding flag in the context takes the value true (and remains
set until cleared) and a exception is raised if the corresponding trap has the value true.

  Decimal.context.traps[Decimal::DivisionByZero] = false
  Decimal.context.flags[Decimal::DivisionByZero] = false
  puts Decimal(1)/Decimal(0)                                -> Infinity
  puts Decimal.context.flags[Decimal::DivisionByZero]       -> true
  Decimal.context.traps[Decimal::DivisionByZero] = true
  puts Decimal(1)/Decimal(0)                                -> Exception : Decimal::DivisionByZero

==Numerical conversion

By default, Decimal is interoperable with Integer and Rational.
Conversion happens automatically to operands:

  puts Decimal('0.1') + 1                            -> 1.1
  puts 7 + Decimal('0.2')                            -> 7.2
  puts Rational(5,2) + Decimal('3')                  -> 5.5

Conversion can also be done explicitely with
the Decimal constructor:

   puts Decimal(7)                                   -> 7
   puts Decimal(Rational(1,10))                      -> 0.1

Converting a Decimal to other numerical types can be done with specific Ruby-style methods.

  puts Decimal('1.1').to_i                           -> 1
  puts Decimal('1.1').to_r                           -> 11/10

(note the truncated result of to_i)
Or with a generic method:
  puts Decimal('1.1').convert_to(Integer)            -> 1
  puts Decimal('1.1').convert_to(Rational)           -> 11/10

Conversion is also possible to Float:
  puts Decimal('1.1').to_f                           -> 1.1
  puts Decimal('1.1').convert_to(Float)              -> 1.1
  puts Float(Decimal('1.1'))                         -> 1.1

And with GDAS style operations:

  puts Decimal('1.1').to_integral_value              -> 1

The conversion system is extensible. For example, we can include BigDecimal into it
by defining suitable conversion procedures:

  Decimal.context.define_conversion_from(BigDecimal) do |x, context|
    Decimal(x.to_s)
  end
  Decimal.context.define_conversion_to(BigDecimal) do |x|
    BigDecimal.new(x.to_s)
  end

Now we can mix BigDecimals and Decimals in expressions and convert from Decimal
to BigDecimal:

  puts BigDecimal.new('1.1') + Decimal('2.2')        -> 3.3
  puts Decimal('1.1').convert_to(BigDecimal)         -> 0.11E1

Note that the conversions are defined in a Context object and will be available only
when that context applies. That way we can define conversions for specific purposes
without affecting a program globally.

As another example consider conversion from Float to Decimal, which is not defined by
default because it can be defined in different ways depending on the purpose.

A Float constant such as 0.1 defines a Float object which has a numerical value close to,
but not exactly 1/10. When converting that Float to Decimal we could decide to preserver
the exact numerical value of the number or try to find a simple decimal expression within
a given tolerance. If we take the first approach we can define this conversion:

  Decimal.context.define_conversion_from(Float) do |x, context|
    s,e = Math.frexp(x)
    s = Math.ldexp(s, Float::MANT_DIG).to_i
    e -= Float::MANT_DIG
    Decimal(s*(Float::RADIX**e))
  end

Note that the conversion we've defined depends on the context precision:

  Decimal.local_context(:precision=>20) { puts Decimal(0.1) } -> 0.10000000000000000555

  Decimal.local_context(:precision=>12) { puts Decimal(0.1) } -> 0.100000000000

  Decimal.local_context(:exact=>true) { puts Decimal(0.1) }   -> 0.1000000000000000055511151231257827021181583404541015625

== Abbreviation

The use of Decimal can be made less verbose by requiring:

  require 'decimal/shortcut'

This file defines +D+ as a synonym for +Decimal+:

  D.context.precision = 3
  puts +D('1.234')                                   -> 1.23

== Error analysis

The Decimal#ulp() method returns the value of a "unit in the last place" for a given number

  D.context.precision = 4
  puts D('1.5').ulp                                  -> 0.001
  puts D('1.5E10').ulp                               -> 1E+7

Whe can compute the error in ulps of an approximation +aprx+ to correclty rounded value +exct+ with:

  def ulps(exct, aprx)
    (aprx-exct).abs/exct.ulp
  end

  puts ulps(Decimal('0.5000'), Decimal('0.5003'))    -> 3
  puts ulps(Decimal('0.5000'), Decimal('0.4997'))    -> 3

  puts ulps(Decimal('0.1000'), Decimal('0.1003'))    -> 3E+1
  puts ulps(Decimal('0.1000'), Decimal('0.0997'))    -> 3E+1

  puts ulps(Decimal(1), Decimal(10).next_minus)      -> 8.999E+4
  puts ulps(Decimal(1), Decimal(10).next_plus)       -> 9.01E+4

Note that in the definition of ulps we use exct.ulp. If we had use aprx.ulp Decimal(10).next_plus
would seem to be a better approximation to Decimal(1) than Decimal(10).next_minus. (Admittedly,
such bad approximations should not be common.)

== More Information

Consult the documentation for the classes Decimal and Decimal::Context.

= Decimal vs BigDecimal

--
EXPAND-
++

Decimal solves some of the difficulties of using BigDecimal.

One of the major problems with BigDecimal is that it's not easy to control the number of
significant digits of the results. While addition, subtraction and multiplication are exact (unless a limit is used),
divisions will need to be passed precision explicitly or else an indeterminate number of significant digits will be lost.
Part of the problem is that numbers don't keep track of its precision (0.1000 is not distinguishable from 0.1.)

With Decimal, Context objects are used to specify the exact number of digits to be used for all operations making
the code cleaner and the results more easily predictable.

  Decimal.context.precision = 10
  puts Decimal(1)/Decimal(3)
Contexts are thread-safe and can be used for individual operations:
  puts Decimal(1).divide(Decimal(e), Decimal::Context(:precision=>4))
Which can be abbreviated:
puts Decimal(1).divide(Decimal(e), :precision=>4)
Or use locally in a block without affecting other code:
  Decimal.context {
    Decimal.context.precision = 3
    puts Decimal(1)/Decimal(3)
  }
  puts Decimal.context.precision
Which can also be abbreviated:
  Decimal.context(:precision=>3) { puts Decimal(1)/Decimal(3) }

This allows in general to write simpler code; e.g. this is an exponential function, adapted from the
'recipes' in Python's Decimal:
    def exp(x, c=nil)
      i, lasts, s, fact, num = 0, 0, 1, 1, 1
      Decimal.context(c) do |context|
        context.precision += 2
        while s != lasts
          lasts = s
          i += 1
          fact *= i
          num *= x
          s += num / fact
        end
      end
      return +s
    end

The final unary + applied to the result forces it to be rounded to the current precision
(because we have computed it with two extra digits)
The result of this method does not have trailing non-significant digits, as is common with BigDecimal
(e.g. in the exp implementation available in the standard Ruby library, in bigdecimal/math)

--
EXPAND+
++

= Roadmap

* Version 0.3.0: Implement the missing GDA functions:
  rotate, shift, trim, and, or, xor, invert,
  max, min, maxmag, minmag, comparetotal, comparetotmag

