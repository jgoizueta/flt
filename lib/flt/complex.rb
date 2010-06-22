# Complex number support for Flt::Num types.
#
# Complex is extended to handle properly components of Num types.
#
# Examples:
#   require 'flt/complex'
#   include Flt
#   DecNum.context(:precision=>4) do
#     puts (Complex(1,2)*DecNum(2)).abs.inspect            # => DecNum('4.472')
#   end
#
# Complex functions are provided through Num.ccontext object, Context#.cmath blocks and CMath modules.
#
# Examples:
#   require 'flt/complex'
#   include Flt
#   DecNum.context.precision = 10
#   puts DecNum.ccontext.sqrt(-2)                           # => 0+1.414213562i
#   puts DecNum.ccontext(:precision=>5).sqrt(-2)            # => 0+1.4142i
#   puts DecNum.context(:precision=>6).cmath{sqrt(-2)}      # => 0+1.41421i
#
# CMath Examples:
#   DecNum.context(:precision=>5) do
#     puts DecNum::CMath.sqrt(-2)                           # => 0+1.4142i
#   end
#   DecNum.context.precision = 10
#   include DecNum::CMath
#   puts sqrt(-2)                                           # => 0+1.414213562i
#

require 'flt/math'
require 'complex'

class Complex

  alias abs! abs
  def abs
    num_class.nil? ? abs! : num_class.context.hypot(real, imag)
  end

  alias polar! polar
  def polar
    num_class.nil? ? polar! : [num_class.context.hypot(real, imag), num_class.context.atan2(imag, real)]
  end

  # alias power! **
  # def **(other)
  #   if classnum_class_num.nil? && other.class_num.nil?
  #     self.power!(other)
  #   else
  #     num_class.ccontext.power(self, other)
  #   end
  # end

  private

  def num_class
    real.kind_of?(Flt::Num) ? real.class : imag.kind_of?(Flt::Num) ? imag.class : nil
  end

end # Complex

module Flt

  class ComplexContext # consider: < Num::ContextBase

    def initialize(context)
      @context = context
    end

    def num_class
      @context.num_class
    end

    def math
      num_class.context
    end

    def Num(z)
      if z.kind_of?(Complex)
        Complex.rectangular(*z.rectangular.map{|v| @context.num_class[v]})
      else
        Complex.rectangular(@context.num_class[z])
      end
    end

    def abs(z)
      z.abs
    end

    def self.math_function(mth, negative_arg_to_complex=false, extra_prec=3, &blk)
      class_eval do
        define_method mth do |*args|
          is_complex = args.detect{|z| z.kind_of?(Complex)}
          if is_complex || (negative_arg_to_complex && args.first<0)
            num_class.context(:extra_precision=>extra_prec) do |mth|
              #Complex.rectangular *blk[mth, *args].map{|v| @context.plus(v)}
              Complex.rectangular *instance_exec(mth,*args,&blk).map{|v| @context.plus(v)}
            end
          else
            @context.send(mth, *args) # Num(@context.send(mth, *args)) ?
          end
        end
      end
    end

    math_function :exp do |mth, z|
      re_exp = mth.exp(z.real)
      [re_exp * mth.cos(z.imag), re_exp * mth.sin(z.imag)]
    end

    math_function :log, true do |mth, x, *args| # we can do |mth, x, b=nil| in Ruby 1.9 but not in 1.8
      b = args.first
      r, theta = Num(x).polar
      [mth.log(r, b), theta]
    end

    math_function :ln, true do |mth, x|
      r, theta = Num(x).polar
      [mth.ln(r), theta]
    end

    math_function :log2, true do |mth, x|
      r, theta = Num(x).polar
      [mth.log2(r), theta]
    end

    math_function :log10, true do |mth, x|
      r, theta = Num(x).polar
      [mth.log10(r), theta]
    end

    math_function :power, true, 4 do |mth, x, y|
      if (y.respond_to?(:zero?) && y.zero?) || y==0
        [1,0]
      else
        r, theta = Num(x).polar
        ore, oim = y.kind_of?(Complex) ? y.rectangular : [y, 0]
        log_r = mth.ln(r)
        nr = mth.exp(ore*log_r - oim*theta)
        ntheta = theta*ore + oim*log_r
        [nr*mth.cos(ntheta), nr*mth.sin(ntheta)]
      end
    end

    def sqrt(z)
      z_is_complex = z.kind_of?(Complex)
      if z_is_complex || z<0
        if z_is_complex
          re = im = nil
          num_class.context(:extra_precision=>3) do |mth|
            z = Num(z)
            i_sign = z.imag.sign
            r = abs(z)
            x = z.real
            re = ((r+x)/2).sqrt
            im = ((r-x)/2).sqrt.copy_sign(i_sign)
          end
          fix_rect(re, im)
        else
          Complex(0, @context.sqrt(-z))
        end
      else
        @context.sqrt(z)
      end
    end

    math_function :sin do |mth, z|
      [mth.sin(z.real)*mth.cosh(z.imag), mth.cos(z.real)*mth.sinh(z.imag)]
    end

    math_function :cos do |mth, z|
      [mth.cos(z.real)*mth.cosh(z.imag), -mth.sin(z.real)*mth.sinh(z.imag)]
    end

    math_function :tan do |mth, z|
      mth.cmath{sin(z)/cos(z)}.rectangular
    end

    math_function :atan do |mth, z|
      i = Complex(0,mth.num_class[1])
      mth.cmath{i*ln((i+z)/(i-z))*num_class.one_half}.rectangular
    end

    math_function :sinh do |mth, z|
      [mth.sinh(z.real)*mth.cos(z.imag), mth.cosh(z.real)*mth.sin(z.imag)]
    end

    math_function :cosh do |mth, z|
      [mth.cosh(z.real)*mth.cos(z.imag), mth.sinh(z.real)*mth.sin(z.imag)]
    end

    math_function :tanh do |mth, z|
      mth.cmath{sinh(z)/cosh(z)}.rectangular
    end

    math_function :asinh do |mth, z|
      mth.cmath{ln(z+sqrt(z*z+1))}.rectangular
    end

    def asin(z)
      z_is_complex = z.kind_of?(Complex)
      if z_is_complex || z.abs>1
        # z = Complex(1) unless z_is_complex
        i = Complex(0,@context.num_class[1])
        fix num_class.context(:extra_precision=>3).cmath {
          -i*ln(i*z + sqrt(1-z*z))
        }
      else
        @context.asin(z)
      end
    end

    def acos(z)
      z_is_complex = z.kind_of?(Complex)
      if z_is_complex || z.abs>1
        # z = Complex(1) unless z_is_complex
        i = Complex(0,@context.num_class[1])
        fix num_class.context(:extra_precision=>3).cmath {
          -i*ln(z + i*sqrt(1-z*z))
        }
      else
        @context.acos(z)
      end
    end

    def acosh(z)
      z_is_complex = z.kind_of?(Complex)
      if z_is_complex || z<=1
        # z = Complex(1) unless z_is_complex
        fix num_class.context(:extra_precision=>3).cmath{ ln(z + sqrt(z*z-1)) }
      else
        @context.acosh(z)
      end
    end

    def atanh(z)
      z_is_complex = z.kind_of?(Complex)
      if z_is_complex || z.abs>1
        # z = Complex(1) unless z_is_complex
        i = Complex(0,@context.num_class[1])
        fix num_class.context(:extra_precision=>3).cmath{ num_class.one_half*ln((1+z)/(1-z)) }
      else
        @context.atanh(z)
      end
    end

    extend Forwardable
    def_delegators :@context, :pi


    private

    def fix_rect(re, im)
      Complex(@context.plus(re), @context.plus(im))
    end

    def fix_polar(r, theta)
      num_class.context(:extra_precision=>3) do |mth|
        re = r*mth.cos(theta)
        im = r*mth.sin(theta)
      end
      fix_rect(re, im)
    end

    def fix(z)
      fix_rect *z.rectangular
    end

  end # ComplexContext

  class Num

    def self.ccontext(*args)
      ComplexContext(self.context(*args))
    end

    class ContextBase
      def cmath(*parameters, &blk)
        # if ComplexContext is derived from ContextBase: return ComplexContext(self).math(*parameters, &blk)
        num_class.context(self) do
          if parameters.empty?
            Flt.ComplexContext(num_class.context).instance_eval &blk
          else
            Flt.xiComplexContext(num_class.context).instance_exec *parameters, &blk
          end
        end
      end
    end

  end # Num

  module_function
  def ComplexContext(context)
    ComplexContext.new(context)
  end

  module DecNum::CMath
    include MathBase
    num_class(DecNum){num_class.ccontext}
    math_function *Trigonometry.public_instance_methods
    math_function :exp, :log, :log2, :log10, :sqrt
  end

  module BinNum::CMath
    include MathBase
    num_class(BinNum){num_class.ccontext}
    math_function *Trigonometry.public_instance_methods
    math_function :exp, :log, :log2, :log10, :sqrt
  end

end # Flt