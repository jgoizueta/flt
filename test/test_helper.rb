require 'test/unit'
require File.dirname(__FILE__) + '/../lib/decimal_bd'
require File.dirname(__FILE__) + '/../lib/decimal_rb'
$implementations_to_test = [FPNum::BD, FPNum::RB]

def initialize_context(mod)
  mod::Decimal.context = mod::Decimal::ExtendedContext
end

