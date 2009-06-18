require 'test/unit'
require File.dirname(__FILE__) + '/../lib/decimal'

def initialize_context
  Decimal.context = Decimal::ExtendedContext
end

