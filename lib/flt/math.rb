require 'flt/dec_num'
require 'flt/bin_num'
require 'flt/trigonometry'

module Flt

  # Base module for Math modules for specific Num classes. Math modules area analogous to
  # ::Math and provide both a means to access math functions (of the current context for a Num class)
  # and, more useful here, a means to access the functions unqualified by including the module in some
  # scope.
  #
  # The math functions provided by Math modules are trigonometric (sin, cos, tan, asin, acos, atan, hypot),
  # exp, log, log2, and log10.
  #
  # Example:
  #   DecNum.context(:precision=>5) do
  #     puts DecNum::Math.sqrt(2)        # => 1.4142
  #   end
  #   DecNum.context.precision = 10
  #   include DecNum::Math
  #   puts sqrt(2)                       # => 1.414213562
  #
  module MathBase

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def num_class(cls, &blk)
        define_method(:num_class){cls}
        if blk
          define_method(:context, &blk)
        else
          define_method(:context){num_class.context}
        end
        module_function :num_class, :context
      end
      def math_function(*fs)
        fs.each do |f|
          define_method f do |*args|
            context.send f, *args
          end
          module_function f
        end
      end
    end

  end

  # Math module for DecNum; uses the current DecNum Context. See Flt::MathBase.
  module DecNum::Math
    include MathBase
    num_class DecNum
    math_function *Trigonometry.public_instance_methods
    math_function :exp, :log, :log2, :log10, :sqrt
  end

  # Math module for DecNum; uses the current DecNum Context. See Flt::MathBase.
  module BinNum::Math
    include MathBase
    num_class BinNum
    math_function *Trigonometry.public_instance_methods
    math_function :exp, :log, :log2, :log10, :sqrt
  end

end # Flt
