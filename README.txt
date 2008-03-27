= Introduction

Decimal is a arbitrary precision decimal floating-point type for Ruby that solves
some of the difficulties of using BigDecimal and is standards compliant (in some
of its optional flavours).

== BigDecimal replacement

--
EXPAND-
++

One of the major problems with BigDecimal is that it's not easy to control the number of
significant digits: while addition, substraction and multiplication are exact (unless a limit is used),
divisions will need to be passed precision explicitly or they will loose an indeterminate number of digits.
With Decimal, Context objects are used to specify the exact number of digits to be used for all operations:
  Decimal.context.precision = 10
  puts Decimal(1)/Decimal(3)
Contexts are thread-safe and can be used for individual operations:
  puts Decimal(1).divide(Decimal(e), Decimal::Context.new(:precision=>4))
Or use locally in a block without affecting other code:
  Decimal.local_context {
    Decimal.context.precision = 3
    puts Decimal(1)/Decimal(3)
  }
  puts Decimal.context.precision
  
This allows in general to write simpler code; e.g. this is an exponential function, adapted from the
'recipes' in Python's Decimal:
    def exp(x,c=nil)
      i, lasts, s, fact, num = 0, 0, 1, 1, 1
      Decimal.local_context(c) do |context|
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
The result of this method does not have trailing insignificant digits, as is common with BigDecimal.
      
== Standars compliance.


Decimal pretends to be conformant to the General Decimal Arithmetic Specification
and the revised IEEE 7554 standard.

The BigDecimal implementations (one of the available Decimal flavours) is closer to these specifications
than the raw BigDecimal, but has some limitations:
- Bogus rounding (half_even & half_down) only looks at one extra digit
- Not all operation correctly rounded (sqrt,exp,log...)(even +/- : 1E100-1E-100 with ROUND_DOWN)
- Always in reduced form (no trailing zeros are kept)
- No real fma
- Some deviations in signal/flags handling from the standards

=Development state and plans


Currently two implementations of the same Decimal API are being developed:


[decimal-dn] Implemented as a C extension using the decnumber library. That would be fast and standards-compliant.
             A binary gem could be released for mswin32, but in general compilation and the presence of decnumber
             will be necessary to install this.
[decimal-rb] A pure Ruby implementation inspired by Python's Decimal. This is standards-compliant
             but performance is slow. Needs no Ruby extensions.
[decimal-bd] A BigDecimal-based implementation, which is faster than the pure-ruby
             but isn't currently.  It's not standards-compliant and needs no Ruby extensions
             (uses only the standard library).

The last two are currently being developed.

When all three implementations are available users will have these options:
If decimal-dn is available that would be the best choice. If it is not, then some compromise is necessary:
Choose standards compliance (accuracy) and have poor performance with decimal-rb or give away compliance
and have a better performance with decimal-bd.


We could have a pair of entry-points for requiring:

  
decimal_std.rb:
  begin
    require 'decimal/decimal_dc.rb'
  rescue
    require 'decimal/decimal_rb.rb' # decimal_rb.rb
  end
    
decimal_fast.rb:
  begin
    require 'decimal/decimal_dc.rb'
  rescue
    require 'decimal/decimal_bd.rb'
  end

So the user would require 'decimal_std' if standards-compilacne is preferred or 
require 'decimal_fast' if speed is considered more important.

=Development status

Two of the three planned Decimal alternatives are being developed: decimal_rb.rb is the decimal-rb mentioned above
and decimal_bd.rb is decimal-bd.

= Examples of use

--
EXPAND+
++

The classes, constants and methods of this library are defined inside a module FPNum
that acts asa namespece to avoid name collisions with other libraries.
Several Decimal implementations are available in this library and each uses a nested
namespace inside FPNum to allow coexistence: FPNum::RB for the pure ruby implementation,
FPNum::BD for the BigDecimal wrapper and FPNum::DN may be used in the future for a
decNumber implementation.

For the next examples we will use the RB implementation, so we include the module 
to economize writing:

  require 'decimal/decimal_rb'
  include FPNum::RB

Now we can use the Decimal class simply like this:

  puts Decimal(1)/Decimal(3)                         -> 0.3333333333333333333333333333
  
Decimal() is a constructor that can be used instead of Decimal.new()
  
== Contexts

Contexts are envrionments for arithmetic operations. They govern precision, set rules
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

  Decimal.local_context do
    Decimal.context.precision = 5
    puts Decimal.context.precision
  end                                                -> 5
  puts Decimal.context.precision                     -> 9
  
The block for a local context can be passed the current context as an argument:

  Decimal.local_context do |context|
    context.precision = 5
    puts Decimal.context.precision
  end                                                -> 5
  puts Decimal.context.precision                     -> 9
  
A context object can be used to define the local context:  
  
  my_context = Decimal::Context(:precision=>20)
  Decimal.local_context(my_context) do |context|
    puts context.precision
  end                                                -> 20
  
And individual parameters can be assigned like this:

  puts Decimal.context.precision                     -> 9
  puts Decimal.context.rounding                      -> half_even
  Decimal.local_context(:rounding=>:down) do |context|
    puts context.precision
    puts context.rounding
  end                                                -> 9
                                                     -> down
  
Contexts created with the Decimal::Context() constructor
inherit from Decimal::DefaultContext.
Default context attributes can be established by modifying
that object:
  
  Decimal::DefaultContext.precision = 10
  Decimal.context = Decimal::Context(:rounding=>:half_up)
  puts Decimal.context.precision                     -> 10
  
Note that a context object assigned to Decimal.context are copied,
so they are not altered through Decimal.context:

  puts my_context.precision                          -> 20
  Decimal.context = my_context
  Decimal.context.precision = 2
  puts my_context.precision                          -> 20
  
So DefaultContext is not altered when modifying Decimal.context.  
  
Methods that use a context have an optional parameter to override
the active context (Decimal.context) :

  Decimal.context.precision = 3
  puts Decimal(1).divide(3)                          -> 0.333
  puts Decimal(1).divide(3, my_context)              -> 0.33333333333333333333
  
And individual context parameter can also be overriden:

  puts Decimal(1).divide(3, :precision=>6)           -> 0.333333

There are two additional predefined contexts Decimal::ExtendedContext
and Decimal::BasicContext that are not meant to be modified; they
can be use to achieve reproducible results. We will use
Decimal::ExtendedContext in the following examples:

  Decimal.context = Decimal::ExtendedContext

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
  puts Decimal(1)/Decimal(3)                         -> Exception : FPNum::RB::Decimal::Inexact

  Decimal.context.precision = 5
  puts Decimal('1E20')-Decimal('1E-20')              -> 1.0000E+20
  puts Decimal(16).sqrt                              -> 4
  puts Decimal(16)/Decimal(4)                        -> 4
  puts Decimal(1)/Decimal(3)                         -> 0.33333

  
  # quantize, etc  
  
There are also some methods for excplicit rounding that provide
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

==Exceptions
