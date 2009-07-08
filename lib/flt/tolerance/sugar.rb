# Syntax sugar for Tolerance definitions
#
# Examples
#   '0.03'.absolute_tolerance # == Tolerance('0.03', :absolute) == AbsoluteTolerance.new('0.03')
#   '0.03'.relative_tolerance # == Tolerance('0.03', :relative) == RelativeTolerance.new('0.03')
#     0.03.absolute_tolerance # == Tolerance(0.03, :absolute) == AbsoluteTolerance.new(0.03)
#    3.percent_tolerance # == Tolerance(3, :percent) == PercentTolerance.new(3)
#    3.ulps_tolerance # == Tolerance(3, :ulps) == UlpsTolerance.new(3)
#    1.epsilon_tolerance # == Tolerance(:epsilon) == EpsilonTolerance.new()
#

require 'flt/tolerance'

module Flt
  def Tolerance.define_sugar(value_class, *tol_classes) #:nodoc:
    tol_classes.each do |tol_class|
      suffix = tol_class.to_s.split('::').last.
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      value_class.send(:define_method, suffix) do
        tol_class.new(self)
      end
    end
  end
end

Flt::Tolerance.define_sugar Integer,
  AbsoluteTolerance,
  RelativeTolerance, PercentTolerance, PermilleTolerance,
  FloatingTolerance, UlpsTolerance,
  SigDecimalsTolerance, DecimalsTolerance,
  SigBitsTolerance,
  EpsilonTolerance, AbsEpsilonTolerance, FltEpsilonTolerance,
  BigEpsilonTolerance, AbsBigEpsilonTolerance, FltBigEpsilonTolerance

Flt::Tolerance.define_sugar String,
  AbsoluteTolerance,
  RelativeTolerance, PercentTolerance, PermilleTolerance,
  FloatingTolerance, UlpsTolerance,
  EpsilonTolerance, AbsEpsilonTolerance, FltEpsilonTolerance,
  BigEpsilonTolerance, AbsBigEpsilonTolerance, FltBigEpsilonTolerance

Flt::Tolerance.define_sugar Float,
  AbsoluteTolerance,
  RelativeTolerance, PercentTolerance, PermilleTolerance,
  FloatingTolerance, UlpsTolerance,
  SigDecimalsTolerance, DecimalsTolerance,
  SigBitsTolerance,
  EpsilonTolerance, AbsEpsilonTolerance, FltEpsilonTolerance,
  BigEpsilonTolerance, AbsBigEpsilonTolerance, FltBigEpsilonTolerance

Flt::Tolerance.define_sugar Rational,
  AbsoluteTolerance,
  RelativeTolerance, PercentTolerance, PermilleTolerance,
  FloatingTolerance, UlpsTolerance,
  SigDecimalsTolerance, DecimalsTolerance,
  SigBitsTolerance,
  EpsilonTolerance, AbsEpsilonTolerance, FltEpsilonTolerance,
  BigEpsilonTolerance, AbsBigEpsilonTolerance, FltBigEpsilonTolerance

Flt::Tolerance.define_sugar Flt::DecNum,
  AbsoluteTolerance,
  RelativeTolerance, PercentTolerance, PermilleTolerance,
  FloatingTolerance, UlpsTolerance,
  SigDecimalsTolerance, DecimalsTolerance,
  SigBitsTolerance,
  EpsilonTolerance, AbsEpsilonTolerance, FltEpsilonTolerance,
  BigEpsilonTolerance, AbsBigEpsilonTolerance, FltBigEpsilonTolerance

Flt::Tolerance.define_sugar Flt::BinNum,
  AbsoluteTolerance,
  RelativeTolerance, PercentTolerance, PermilleTolerance,
  FloatingTolerance, UlpsTolerance,
  SigDecimalsTolerance, DecimalsTolerance,
  SigBitsTolerance,
  EpsilonTolerance, AbsEpsilonTolerance, FltEpsilonTolerance,
  BigEpsilonTolerance, AbsBigEpsilonTolerance, FltBigEpsilonTolerance
