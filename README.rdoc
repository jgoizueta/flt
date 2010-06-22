= Introduction

This library provides arbitrary precision floating-point types for Ruby. All types and
functions are within a namespace called Flt. Decimal and Binary floating point numbers
are implemented in classes Flt::DecNum and Flt::BinNum. These types are completely
written in Ruby using the multiple precision native integers. The performance
could be improved in the future by using a C extension based on the decNumber libray.

The Flt::Tolerance classes and the Flt.Tolerance() constructor handle floating point
tolerances defined in flexible ways.

Context classes are define in the files
flt/float.rb[link:lib/flt/float_rb.html] and
flt/bigdecimal.rb[link:lib/flt/bigdecimal_rb.html]
for Float and BigDecimal numbers that aid to the interchangeability of floating point types. This
represent the only definition of identifiers outside the Flt namespace: the methods
Float.context() and BigDecimal.context() and some contants in Float.

This library is the successor of the ruby-decimal gem, that defined the Decimal class
for decimal floating point; that class has been renamed to Flt::DecNum and support
has been added for binary floating point and tolerances.

The documentation for this package is available at http://flt.rubyforge.org/

The code is at http://github.com/jgoizueta/flt/

= DecNum

Flt::DecNum is a standards-compliant arbitrary precision decimal floating-point type for Ruby.
It is based on the Python Decimal class.

== Standars compliance.

DecNum pretends to be conformant to the General Decimal Arithmetic Specification
and the revised IEEE 754 standard (IEEE 754-2008).

= Examples of use

To install the library use gem from the command line: (you may not need +sudo+)
FIXME: The flt gem is not publicly available yet.
  sudo gem install flt

Then require the library in your code (if it fails you may need to <tt>require 'rubygems'</tt> first)
  require 'flt'
  include Flt

Now we can use the DecNum class simply like this:

  puts DecNum(1)/DecNum(3)                         # -> 0.3333333333333333333333333333

DecNum() is a constructor that can be used instead of DecNum.new()

== Contexts

Contexts are environments for arithmetic operations. They govern precision, set rules
for rounding, determine which signals are treated as exceptions, and limit the range
for exponents.

Each thread has an active context that can be accessed like this:

  puts DecNum.context.precision                    # -> 28

The active context can be globally for the current thread:

  DecNum.context.precision = 2
  puts DecNum.context.precision                    # -> 2
  puts DecNum(1)/DecNum(3)                         # -> 0.33
  DecNum.context.precision += 7
  puts DecNum.context.precision                    # -> 9
  puts DecNum(1)/DecNum(3)                         # -> 0.333333333

Or it can be altered locally inside a block:

  DecNum.context do
    DecNum.context.precision = 5
    puts DecNum.context.precision                  # -> 5
  end
  puts DecNum.context.precision                    # -> 9

The block for a local context can be passed the current context as an argument:

  DecNum.context do |local_context|
    local_context.precision = 5
    puts DecNum.context.precision                  # -> 5
  end
  puts DecNum.context.precision                    # -> 9

A context object can be used to define the local context:

  my_context = DecNum::Context(:precision=>20)
  DecNum.context(my_context) do |context|
    puts context.precision
  end                                              # -> 20

And individual parameters can be assigned like this:

  puts DecNum.context.precision                    # -> 9
  puts DecNum.context.rounding                     # -> half_even
  DecNum.context(:rounding=>:down) do |context|
    puts context.precision                         # -> 9
    puts context.rounding                          # -> down
  end


Contexts created with the DecNum::Context() constructor
inherit from DecNum::DefaultContext.
Default context attributes can be established by modifying
that object:

  DecNum::DefaultContext.precision = 10
  DecNum.context = DecNum::Context(:rounding=>:half_up)
  puts DecNum.context.precision                    # -> 10

Note that a context object assigned to DecNum.context is copied,
so it is not altered through DecNum.context:

  puts my_context.precision                        # -> 20
  DecNum.context = my_context
  DecNum.context.precision = 2
  puts my_context.precision                        # -> 20

So, DefaultContext is not altered when modifying DecNum.context.

Methods that use a context have an optional parameter to override
the active context (DecNum.context) :

  DecNum.context.precision = 3
  puts DecNum(1).divide(3)                         # -> 0.333
  puts DecNum(1).divide(3, my_context)             # -> 0.33333333333333333333

Individual context parameters can also be overriden:

  puts DecNum(1).divide(3, :precision=>6)          # -> 0.333333

There are two additional predefined contexts DecNum::ExtendedContext
and DecNum::BasicContext that are not meant to be modified; they
can be used to achieve reproducible results. We will use
DecNum::ExtendedContext in the following examples:

  DecNum.context = DecNum::ExtendedContext

Most decimal operations can be executed by using either Context or DecNum methods:

  puts DecNum.context.exp(1)                       # -> 2.71828183
  puts DecNum(1).exp                               # -> 2.71828183

If using Context methods, values are automatically converted as if the DecNum() constructor
was used.

==Rounding

Results are normally rounded using the precision (number of significant digits)
and rounding mode defined in the context.

  DecNum.context.precision = 4
  puts DecNum(1)/DecNum(3)                         # -> 0.3333
  puts DecNum('1E20')-DecNum('1E-20')              # -> 1.000E+20
  DecNum.context.rounding = :half_up
  puts +DecNum('100.05')                           # -> 100.1
  DecNum.context.rounding = :half_even
  puts +DecNum('100.05')                           # -> 100.0

Note that input values are not rounded, only results; we use
the plus operator to force rounding here:

  DecNum.context.precision = 4
  x = DecNum('123.45678')
  puts x                                           # -> 123.45678
  puts +x                                          # -> 123.5

Precision can be also set to exact to avoid rounding, by using
the exact property or using a 0 precision. In exact mode results
are never rounded and results that have an infinite number of
digits trigger the DecNum::Inexact exception.

  DecNum.context.exact = true
  puts DecNum('1E20')-DecNum('1E-20')              # -> 99999999999999999999.99999999999999999999
  puts DecNum(16).sqrt                             # -> 4
  puts DecNum(16)/DecNum(4)                        # -> 4
  puts DecNum(1)/DecNum(3)                         # -> Exception : Flt::Num::Inexact

  DecNum.context.precision = 5
  puts DecNum('1E20')-DecNum('1E-20')              # -> 1.0000E+20
  puts DecNum(16).sqrt                             # -> 4
  puts DecNum(16)/DecNum(4)                        # -> 4
  puts DecNum(1)/DecNum(3)                         # -> 0.33333

There are also some methods for explicit rounding that provide
an interface compatible with the Ruby interface of Float:

  puts DecNum('101.5').round                       # -> 102
  puts DecNum('101.5').round(0)                    # -> 102
  puts DecNum('101.12345').round(2)                # -> 101.12
  puts DecNum('101.12345').round(-1)               # -> 1.0E+2
  puts DecNum('101.12345').round(:places=>2)       # -> 101.12
  puts DecNum('101.12345').round(:precision=>2)    # -> 1.0E+2
  puts DecNum('101.5').round(:rounding=>:half_up)  # -> 102
  puts DecNum('101.5').ceil                        # -> 102
  puts DecNum('101.5').floor                       # -> 101
  puts DecNum('101.5').truncate                    # -> 101

==Special values

In addition to finite numbers, a DecNum object can represent some special values:
* Infinity (+Infinity, -Infinity). The method DecNum#infinite? returns true for these to values.
  DecNum.infinity DecNum.infinity(-1) can be used to get these values.
* NaN (not a number) represents indefined results. The method DecNum#nan? returns true for it and
  DecNum.nan can be used to obtain it. There is a variant, sNaN (signaling NaN) that casues
  an invalid operation condition if used; it can be detected with DecNum.snan?.
  A NaN can also include diagnostic information in its sign and coefficient.

Any of the special values can be detected with DecNum#special?
Finite numbers can be clasified with
these methods:
* DecNum#zero? detects a zero value (note that there are two zero values: +0 and -0)
* DecNum#normal? detects normal values: those whose adjusted exponents are not less than the the emin.
* DecNum#subnormal? detects subnormal values: those whose adjusted exponents are less than the the emin.

==Exceptions

Exceptional conditions that may arise during operations have corresponding classes that represent them:
* DecNum::InvalidOperation
* DecNum::DivisionByZero
* DecNum::DivisionImpossible
* DecNum::DivisionUndefined
* DecNum::Inexact
* DecNum::Overflow
* DecNum::Underflow
* DecNum::Clamped
* DecNum::InvalidContext
* DecNum::Rounded
* DecNum::Subnormal
* DecNum::ConversionSyntax

For each condition, a flag and a trap (boolean values) exist in the context.
When a condition occurs, the corresponding flag in the context takes the value true (and remains
set until cleared) and a exception is raised if the corresponding trap has the value true.

  DecNum.context.traps[DecNum::DivisionByZero] = false
  DecNum.context.flags[DecNum::DivisionByZero] = false
  puts DecNum(1)/DecNum(0)                              # -> Infinity
  puts DecNum.context.flags[DecNum::DivisionByZero]     # -> true
  DecNum.context.traps[DecNum::DivisionByZero] = true
  puts DecNum(1)/DecNum(0)                              # -> Exception : Flt::Num::DivisionByZero

==Numerical conversion

By default, DecNum is interoperable with Integer and Rational.
Conversion happens automatically to operands:

  puts DecNum('0.1') + 1                           # -> 1.1
  puts 7 + DecNum('0.2')                           # -> 7.2
  puts Rational(5,2) + DecNum('3')                 # -> 5.5

Conversion can also be done explicitely with
the DecNum constructor:

   puts DecNum(7)                                  # -> 7
   puts DecNum(Rational(1,10))                     # -> 0.1

Converting a DecNum to other numerical types can be done with specific Ruby-style methods.

  puts DecNum('1.1').to_i                          # -> 1
  puts DecNum('1.1').to_r                          # -> 11/10

(note the truncated result of to_i)
Or with a generic method:
  puts DecNum('1.1').convert_to(Integer)           # -> 1
  puts DecNum('1.1').convert_to(Rational)          # -> 11/10

Thera are also GDAS style conversion operations:

  puts DecNum('1.1').to_integral_value             # -> 1

And conversion is also possible to Float:
  puts DecNum('1.1').to_f                          # -> 1.1
  puts DecNum('1.1').convert_to(Float)             # -> 1.1
  puts Float(DecNum('1.1'))                        # -> 1.1

Types with predefined bidirectional conversion (Integer and Rational)
can be operated with DecNum on either side of an operator, and the result will be a DecNum.
For Float there is no predefined bidirectional conversion (see below how to define it)
and the result of an operation between DecNum and Float will be of type Float.

  puts (DecNum('1.1') + 2.0).class                  # -> Float
  puts (2.0 + DecNum('1.1')).class                  # -> Float

The conversion system is extensible. For example, we can include BigDecimal into it
by defining suitable conversion procedures:

  DecNum.context.define_conversion_from(BigDecimal) do |x, context|
    DecNum(x.to_s)
  end
  DecNum.context.define_conversion_to(BigDecimal) do |x|
    BigDecimal.new(x.to_s)
  end

Now we can mix BigDecimals and Decimals in expressions and convert from DecNum
to BigDecimal:

  puts BigDecimal.new('1.1') + DecNum('2.2')       # -> 3.3
  puts DecNum('1.1').convert_to(BigDecimal)        # -> 0.11E1

Note that the conversions are defined in a Context object and will be available only
when that context applies. That way we can define conversions for specific purposes
without affecting a program globally.

As another example consider conversion from Float to DecNum, which is not defined by
default because it can be defined in different ways depending on the purpose.

A Float constant such as 0.1 defines a Float object which has a numerical value close to,
but not exactly 1/10. When converting that Float to DecNum we could decide to preserve
the exact numerical value of the number or try to find a simple decimal expression within
a given tolerance. If we take the first approach we can define this conversion:

  DecNum.context.define_conversion_from(Float) do |x, context|
    s,e = Math.frexp(x)
    s = Math.ldexp(s, Float::MANT_DIG).to_i
    e -= Float::MANT_DIG
    DecNum(s*(Float::RADIX**e))
  end

Note that the conversion we've defined depends on the context precision:

  DecNum.local_context(:precision=>20) { puts DecNum(0.1) } # -> 0.10000000000000000555

  DecNum.local_context(:precision=>12) { puts DecNum(0.1) } # -> 0.100000000000

  DecNum.local_context(:exact=>true) { puts DecNum(0.1) } # -> 0.1000000000000000055511151231257827021181583404541015625

A different approach for Float to DecNum conversion is to find the shortest (fewer digits) DecNum
that rounds to the Float with the binary precision that the Float has.
We will assume that the DecNum to Float conversion done with the rounding mode of the DecNum context.
The BinNum class has a method to perform this kind of conversion, so we will use it.

  DecNum.context.define_conversion_from(Float) do |x, dec_context|
    BinNum.context(:rounding=>dec_context.rounding) do |bin_context|
      BinNum(x).to_decimal
    end
  end

The result is independent of the context precision.

  puts DecNum(0.1)                                 # -> 0.1
  puts DecNum(1.0/3)                               # -> 0.3333333333333333

This conversion gives the results expected most of the time, but it must be noticed that
there must be some compromise, because different decimal literals convert to the same Float value:

  puts DecNum(0.10000000000000001)                 # -> 0.1

There's also some uncertainty because the way the Ruby interpreter parses Float literals
may not be well specified; in the usual case (IEEE Double Floats and round-to-even)
the results will be as expected (correctly rounded Floats), but some platforms may
behave differently.

The BinNum also a instance method +to_decimal_exact+ to perform the previous 'exact' conversion, that
could have be written:

  DecNum.context.define_conversion_from(Float) do |x, context|
    DecNum.context(context) do
      BinNum(x).to_decimal_exact
    end
  end

== Abbreviation

The use of DecNum can be made less verbose by requiring:

  require 'flt/d'

This file defines +D+ as a synonym for +DecNum+:

  D.context.precision = 3
  puts +D('1.234')                                 # -> 1.23

Some convenient methods are added to numeric classes by requiring the optional
flt/sugar.rb[link:lib/flt/sugar_rb.html]. This must be explicitely required
because it could cause conflicts with other extensions of these classes.

  require 'flt/sugar'

  puts 34.odd?                                     # -> false
  puts 34.even?                                    # -> true
  puts 0.1.split.inspect                           # -> [1, 7205759403792794, -56]
  puts (-0.1).sign                                 # -> -1

A shortcut notation for DecNum is defined in this file (based on an idea by coderrr[http://coderrr.wordpress.com]
which allows exact definitions with almost literal decimal syntax (note the underscore after the dot.)

  puts 10._123456789123456789                      # -> 10.123456789123456789

Additional underscores can be used to separate digits at any place except before the decimal point:

  puts 100_000._000_001                            # -> 100000.000001
  puts 100_000._000_001.class                      # -> Flt::DecNum

But note that 100_000.000_001 is a valid Float (it's not a DecNum because there isn't an underscore just after the
decimal point):

  puts 100_000.000_001                            # -> 100000.000001
  puts 100_000.000_001.class                      # -> Float

There's also one important caveat with this notation: negative numbers with a zero integral part must be
parenthesed (otherwise the minus has no effect because it affects only the null integer part):

  puts -0._5                                      # -> 0.5
  puts -(0._5)                                    # -> -0.5

== Error analysis

The DecNum#ulp() method returns the value of a "unit in the last place" for a given number under
the current context.

  D.context.precision = 4
  puts D('1.5').ulp                                # -> 0.001
  puts D('1.5E10').ulp                             # -> 1E+7

Whe can compute the error in ulps of an approximation +aprx+ to correclty rounded value +exct+ with:

  def ulps(exct, aprx)
    (aprx-exct).abs/exct.ulp
  end

  puts ulps(DecNum('0.5000'), DecNum('0.5003'))    # -> 3
  puts ulps(DecNum('0.5000'), DecNum('0.4997'))    # -> 3

  puts ulps(DecNum('0.1000'), DecNum('0.1003'))    # -> 3E+1
  puts ulps(DecNum('0.1000'), DecNum('0.0997'))    # -> 3E+1

  puts ulps(DecNum(1), DecNum(10).next_minus)      # -> 8.999E+4
  puts ulps(DecNum(1), DecNum(10).next_plus)       # -> 9.01E+4

Note that in the definition of ulps we use exct.ulp. If we had use aprx.ulp DecNum(10).next_plus
would seem to be a better approximation to DecNum(1) than DecNum(10).next_minus. (Admittedly,
such bad approximations should not be common.)

== BinNum Input/Output

BinNum can be defined with a decimal string literal and converted to one with to_s, as DecNum,
but since this involves a change of base these are inexact operations subject to some specific precision limits.

If we define the number with a binary literal, no base conversion is involved and the result is exactly defined;
here we define a number with just one bit of precision:

  x = BinNum('0.001', :base=>2)
  puts x.number_of_digits                          # -> 1
  puts x.to_s(:base=>2)                            # -> 0.001

Note that we could have defined it with more precision, e.g.

  y = BinNum('0.001000', :base=>2)
  puts y.number_of_digits                          # -> 4
  puts y.to_s(:base=>2)                            # -> 0.001000

But let's get back to our one bit quantity, x, and convert it to a decimal string. Since the internal precision
is only one bit it contains very little information:

  puts x                                           # -> 0.1

We can obtain more digits with the :all_digits option which show all the decimal digits that are significative
for the given precision of 1 bit:

  puts x.to_s(:all_digits=>true)                     # -> 0.12

We can also obtain the exact value of x by using the Num.convert_exact method to convert it to decimal (base 10):

  puts Num.convert_exact(x,10)                     # -> 0.125

Let's convert the default decimal output back to another BinNum which will preserve its precision:

  y = BinNum(x.to_s)

The result may seem ok:

  puts y                                            # -> 0.1

But is not exactly what we originally had:

  puts y==x                                        # -> false
  puts y                                           # -> 0.1
  puts y.number_of_digits                          # -> 5
  puts y.to_s(:base=>2)                            # -> 0.00011010

The new value y has gained some digits because of the intermediate conversion to decimal: one decimal digit
contains more information than one bit, and the result shows that.

If we wanted to preserve exactly the number we should have done this:

  y = BinNum(x.to_s, :fixed, :precision=>x.number_of_digits)
  puts y==x                                         # -> true

To preserve the value we had to explicitly determine how many bits should y have.

With the :fixed options the number produced by BinNum is rounded to the context precision (which can be
overriden as in the example by other options):

  puts BinNum(x.to_s, :fixed, :precision=>32).to_s(:base=>2) # -> 0.00011001100110011001100110011001101
  puts BinNum(x.to_s, :fixed, :precision=>1).to_s(:base=>2)  # -> 0.001

Note also that if we normalize a value we will change it's precision to that of the context:

  puts x.number_of_digits                          # -> 1
  puts x.normalize.number_of_digits                # -> 53
  puts x.normalize.to_s                            # -> 0.125

== Mathematical functions

There are two mathematical functions modules analogous to Ruby's Math for Float,
Flt::DecNum::Math and Flt::BinNum::Math.
Currently they consist of basic trigonometric functions, including hypot, logarithms and the exponential
function, and the constants e and pi.

Its functions can be accessed in a number of ways:

  require 'flt/math'
  DecNum.context(:precision=>10) do |context|
    # As module functions, using the current context for the enclosing Num class:
    puts DecNum::Math.sin(1)*DecNum::Math.pi        # -> 2.643559064
    # As functions of a context object:
    puts context.sin(1)*context.pi                  # -> 2.643559064
    # Through a math block:
      puts DecNum.context.math{sin(1)*pi}           # -> 2.643559064
      puts DecNum.math{sin(1)*pi}                   # -> 2.643559064
    # And can be *included* to be used as private instance methods:
      include DecNum::Math
      puts sin(1)*pi                                # -> 2.643559064
  end

== More Information

* Decimal Floating point type: see the base Flt::Num class and the Flt::DecNum class
* Binary Floating point type: see the base Flt::Num class and the Flt::BinNum class
* Floating Point Contexts: see documentation for classes Flt::Num::ContextBase,
  Flt::DecNum::Context and Flt::BinNum::Context
* Floating Point Tolerance: see the flt/tolerance.rb[link:lib/flt/tolerance_rb.html] file
  and the Flt::Tolerance class
* Constructors: see Flt.DecNum(), Flt.BinNum() and Flt.Tolerance().
* Trigonometry functions: see Flt::Trigonometry.
* Complex number support: see the flt/complex.rb[link:lib/flt/complex_rb.html] file

= DecNum vs BigDecimal

--
EXPAND-
++

DecNum solves some of the difficulties of using BigDecimal.

One of the major problems with BigDecimal is that it's not easy to control the number of
significant digits of the results. While addition, subtraction and multiplication are exact (unless a limit is used),
divisions will need to be passed precision explicitly or else an indeterminate number of significant digits will be lost.
Part of the problem is that numbers don't keep track of its precision (0.1000 is not distinguishable from 0.1.)

With DecNum, Context objects are used to specify the exact number of digits to be used for all operations making
the code cleaner and the results more easily predictable.

  DecNum.context.precision = 10
  puts DecNum(1)/DecNum(3)
Contexts are thread-safe and can be used for individual operations:
  puts DecNum(1).divide(DecNum(e), DecNum::Context(:precision=>4))
Which can be abbreviated:
puts DecNum(1).divide(DecNum(e), :precision=>4)
Or use locally in a block without affecting other code:
  DecNum.context {
    DecNum.context.precision = 3
    puts DecNum(1)/DecNum(3)
  }
  puts DecNum.context.precision
Which can also be abbreviated:
  DecNum.context(:precision=>3) { puts DecNum(1)/DecNum(3) }

This allows in general to write simpler code; e.g. this is an exponential function, adapted from the
'recipes' in Python's Decimal:
    def exp(x, c=nil)
      i, lasts, s, fact, num = 0, 0, 1, 1, 1
      DecNum.context(c) do |context|
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

* Trigonometry optimizations
* Implement the missing GDA functions:
  rotate, shift, trim, and, or, xor, invert,
  max, min, maxmag, minmag, comparetotal, comparetotmag
