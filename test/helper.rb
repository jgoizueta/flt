require 'test/unit'
require File.dirname(__FILE__) + '/../lib/bigfloat'
include BigFloat

def initialize_context
  Decimal.context = Decimal::ExtendedContext
  BinFloat.context = BinFloat::ExtendedContext
end

