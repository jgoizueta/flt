Decimal solves some of the difficulties of using BigDecimal and makes its use more --accord
to the Decimal...
Future versions may fully adapt to the specifications, either by using decNumber or borrowing from
the Python's implementation.

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
What Decimal currently does not implement:
  Exceptions...traps...
  Methods of general ...
  Correct rounding: the arithmetic is done internally with BigDecimal so its idiosincracies are inherited:
    only one digit beyond the rounding point is considered, which makes ... and .. incorrect
    also results are not correctly rounded, eg. 1E100-1E-100        

