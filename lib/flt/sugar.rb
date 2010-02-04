# Optional (and intrusive) shortcuts for numeric types
#
#    require 'flt/sugar'
#
#    puts 0.1.split.inspect
#    puts 0.1.sqrt
#    puts 0.1.next_plus
#
#    puts 11.odd?
#    puts 11.even?
#    puts 11.sign
#    puts 0.sign
#    puts (-11).sign
#
#    puts 11.0.odd?
#    puts 11.0.even?
#    puts 11.0.sign
#    puts 0.0.sign
#    puts (-0.0).sign
#    puts (-11.0).sign
#
#    puts Rational(11,3).split.inspect
#
#    puts BigDecimal::Math.sin(BigDecimal('0.1'), 20)
#    include BigDecimal::Math
#    puts sin(BigDecimal('0.1'), 20)
#

require 'flt/float'
require 'flt/bigdecimal'
require 'flt/d'
require 'flt/b'

class Float

  def self.radix
    context.radix
  end

  def self.Num(*args)
    context.Num(*args)
  end

  class <<self
    def _sugar_context_method(*methods) #:nodoc:
      methods.each do |method|
        define_method(method) do
          Float.context.send(method, self)
        end
      end
    end

    def _sugar_math_method(*methods) #:nodoc:
      methods.each do |method|
        define_method(method) do
          Math.send(method, self)
        end
      end
    end
  end

  _sugar_context_method :split, :to_int_scale, :next_plus, :next_minus, :sign,
                        :special?, :subnormal?, :normal?
  _sugar_math_method :sqrt, :log, :log10, :exp

  def next_toward(other)
    Float.context.next_toward(self, other)
  end

end

class Numeric

  def even?
    self.modulo(2) == 0
  end

  def odd?
    self.modulo(2) == 1
  end

  def sign
    self < 0 ? -1 : +1
  end

end

class Rational

  def split
    [numerator, denominator]
  end

end

module BigDecimal::Math
  include BigMath
  instance_methods.each do |method|
    module_function method
  end
end

# Shortcut to define DecNums, e.g. 1._234567890123456789 produces Flt::DecNum('1.234567890123456789')
# Based on http://coderrr.wordpress.com/2009/12/22/get-arbitrarily-precise-bigdecimals-in-ruby-for-just-one-extra-character/
class Integer
  def method_missing(m, *a, &b)
    return Flt::DecNum("#{self}.#{$1.tr('_','')}")  if m.to_s =~ /^_(\d[_\d]*)$/
    super
  end
end


