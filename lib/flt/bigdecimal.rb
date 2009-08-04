# This eases handling BigDecimals as DecNums

require 'flt'
require 'bigdecimal'
require 'bigdecimal/math'

def Flt.BigDecimalNumClass
  Flt::DecNum
end

def Flt.BigDecimalNum(*args)
  if args.size==1 && args.first.is_a?(BigDecimal)
    Flt.DecNum(args.first.to_s)
  else
    Flt.DecNum(*args)
  end
end
