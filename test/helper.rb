require 'test/unit'
require File.dirname(__FILE__) + '/../lib/decimal'
include BigFloat

def initialize_context
  Decimal.context = Decimal::ExtendedContext
  BinFloat.context = BinFloat::ExtendedContext
end

