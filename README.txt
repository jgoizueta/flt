= Introduction

Decimal is a arbitrary precision decimal floating-point type for Ruby that solves
some of the difficulties of using BigDecimal and is standards compliant (in some
of its optional flavours).

== BigDecimal replacement

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


