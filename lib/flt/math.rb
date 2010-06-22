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
  module MathBase

    def self.included(base)
      base.extend ClassMethods
    end

    def context
      self.class_num.context
    end

    module ClassMethods
      def math_function(*fs)
        fs.each do |f|
          define_method f do |*args|
            self.num_class.context.send f, *args
          end
          module_function f
        end
      end
    end

  end

  # Math module for DecNum; uses the current DecNum Context. See Flt::MathBase.
  module DecNum::Math
    include MathBase
    def self.num_class
      DecNum
    end
    math_function *Trigonometry.public_instance_methods
    math_function :exp, :log, :log2, :log10, :sqrt
  end

  # Math module for DecNum; uses the current DecNum Context. See Flt::MathBase.
  module BinNum::Math
    include MathBase
    def self.num_class
      BinNum
    end
    math_function *Trigonometry.public_instance_methods
    math_function :exp, :log, :log2, :log10, :sqrt
  end

end # Flt
