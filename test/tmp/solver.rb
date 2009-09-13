require File.dirname(__FILE__) + '/../../lib/flt'
require File.dirname(__FILE__) + '/../../lib/flt/math'
#require File.dirname(__FILE__) + '/../../lib/flt/float'
include Flt


# DecNum.context.math do
#   puts "SELF #{self.class}"
#   x = DecNum(1)
#   y = sin(2)*exp(x+1)
#   #puts exp(1).inspect
#   puts y.inspect
# end
#
# l = lambda{ puts "l SELF #{self.class}";2}
# DecNum.context.math &l
# puts "......"
# DecNum.context.math do
#   puts "out SELF #{self.class}"
#   instance_eval &l
# end

#exit

# TODO: .math tests
# (check type and result value) T.context.math{exp(1)} == T.Num(1).exp

# DecNum.context.math do
#   x = DecNum(1)
#   y = sin(2)*exp(x+1)
#   #puts exp(1).inspect
#   puts y.inspect
# end
#
#
# x = DecNum(1)
# DecNum.context.math do
#   y = sin(2)*exp(x+1)
#   #puts exp(1).inspect
#   puts y.inspect
# end
#
# x = 1.0
# Float.context.math do
#   y = sin(2)*exp(x+1)
#   #puts exp(1).inspect
#   puts y.inspect
# end
#
#
# exit

# puts DecNum::Math.sin(DecNum('0.5'))
# puts DecNum('0.5').sin
# puts DecNum.context.sin('0.5')
#
# puts Math.sin(0.5)
# puts 0.5.sin
# puts Float.context.sin(0.5)
#
# exit


# TODO: add method to check for result: zero or sign reversal / extrema / inflection / asymptote

# TODO: automatic guesses if single guess or no guesses

# Base class for Fixed-Point Numeric Solvers
class FPSolverBase

  # default_guesses: nil for no pre-guess, or one or two guesses (use array for two)
  def initialize(context, default_guesses, tol, eqn=nil, &blk)
    @context = context
    @default_guesses = Array(default_guesses)
    @x = @default_guesses.first
    @f = eqn || blk
    @tol = tol # user-requested tolerance
    @l_x = nil
    @fx = nil
    @l_fx = nil
    @ok = true
    @conv = false
    @max_it = 8192
  end

  # value of parameters[var] is used as a guess in precedence to the pre-guesses if not nil
  # use Array for two guesses
  def root(*guesses)
    @guess = (guesses + @default_guesses).map{|g| num(g)}
    @l_x = @x = @guess.first
    @l_fx = @fx = eval_f(@x)
    @ok = true
    @conv = false

    # Minimum tolerance of the numeric type used
    @numeric_tol = Tolerance(1,:ulps) # Tolerance(@context.epsilon, :floating)

    raise "Invalid parameters" unless validate

    @reason = nil
    @iteration = 0
    # TODO: handle NaNs (stop or try to find other guess)
    while @ok && @iteration < @max_it
      next_x = step()
      @l_x = @x
      @l_fx = @fx
      @x = next_x
      @fx = eval_f(@x)
      # puts "X=#{@x.inspect}[#{@fx.inspect}]"
      @conv = test_conv() if @ok
      break if @conv
      @iteration += 1
    end
    @ok = false if @iteration >= @max_it # TODO: set reason
    @x

  end

  def value
    @fx
  end

  attr_reader :reason, :iteration

  protected

  def eval_f(x)
    @context.math x, &@f
  end

  def num(v)
    @context.Num(v)
  end

  def zero?
    @tol.zero?(@fx)
  end

  def test_conv
    #@tol.eq?(@x, @l_x) || @tol.eq?(@fx, @l_fx) || zero?
    # puts "test #{@x} #{@fx}"
    # if @tol.eq?(@fx, @l_fx) && !(@tol.eq?(@x, @l_x) || zero?)
    #   puts "---> v=#{@tol.relative_to_many(:max, @fx, @l_fx)} #{@fx} #{@l_fx} x=#{@x}"
    # end

    # zero? || @x==@l_x || @fx == @l_fx
    #@numeric_tol.eq?(@x, @l_x) || zero? || @numeric_tol.eq?(@fx, @l_fx)

    # TODO : use symbols for reason
    if zero?
      @reason = "Zero found #{@fx.inspect} @ #{@x.inspect}"
    elsif @numeric_tol.eq?(@x, @l_x)
      @reason = "Critical point" # Sign Reversal (@fx != @l_fx) or vertical tangent / asymptote
    elsif @numeric_tol.eq?(@fx, @l_fx)
      @reason = "Flat" # flat function
    end
    !@reason.nil?

    # TODO: try to get out of flat; if @x==@l_x try to find other point?;

    #zero?
  end

  def validate
    true
  end

end

# Secant method solver
# Bisect method is used is bracketing found (sign(f(a)) != sign(f(b)))
class SecantSolver < FPSolverBase

  def initialize(context, default_guesses, tol, eqn=nil, &blk)
    super context, default_guesses, tol, eqn, &blk
    @a = @b = @fa = @fb = nil
    @bracketing = false
    @half = num(Rational(1,2))
  end

  def step
    return @guess[1] if @iteration == 0
    bisect = false
    dy = @fx - @l_fx

    if @tol.zero?(dy)
      if @bracketing
        bisect = true
      else
        @ok = false
        return @x
      end
    end

    if !bisect
      next_x = @x - ((@x - @l_x)*@fx)/dy
      bisect = true if @bracketing && (next_x < @a || next_x > @b)
    end
    next_x = (@a + @b)*@half if bisect
    next_fx = eval_f(next_x)

    if @bracketing
      if @context.sign(@fa) == @context.sign(next_fx)
        @a = next_x
        @fa = next_fx
      else
        @b = next_x
        @fb = next_fx
      end
    else
      if @context.sign(next_fx) != @context.sign(@fx)
        @a, @b = @x, next_x
        @a, @b = @b, @a if @a > @b
        @fa = eval_f(@a)
        @fb = eval_f(@b)
        @bracketing = true
      end
    end
    next_x
  end

  def validate
    @guess = @guess.uniq
    if @guess.size < 2
      return false if @guess.empty?
      @guess << (@guess.first + 1)
    end
    true
  end

end


if true
solver = SecantSolver.new(Float.context, [0.0, 100.0], Tolerance(3, :decimals)) do |x|
  2*x+11.0
end

v = solver.root # with guess: v = solver.root(5.0)
puts v

# TODO: if guesses are 0,100 => result is not valid because value at 100 is too large =>
solver = SecantSolver.new(Float.context, [0.0, 10.0], Tolerance(3, :decimals)) do |x|
  y = 2
  y*exp(x)-10
end

v = solver.root # with guess: v = solver.root(5)
puts v

end


# Regula-Falsi/Secant method solver
# Secant is used if no bracketing is available
class RFSecantSolver < FPSolverBase

  def initialize(context, default_guesses, tol, eqn=nil, &blk)
    super context, default_guesses, tol, eqn, &blk
    @a = @b = @fa = @fb = nil
    @bracketing = false
    @half = num(Rational(1,2))
  end

  def step
    return @guess[1] if @iteration == 0
    regula_falsi = false
    dy = @fx - @l_fx

    if @tol.zero?(dy)
      if @bracketing
        regula_falsi = true
      else
        @ok = false
        return @x
      end
    end

    if !regula_falsi
      next_x = @x - ((@x - @l_x)*@fx)/dy
      regula_falsi = true if @bracketing && (next_x < @a || next_x > @b)
    end
    next_x = @b - (@b - @a)*@fb/(@fb - @fa) if regula_falsi
    next_fx = eval_f(next_x)

    if @bracketing
      if @context.sign(@fa) == @context.sign(next_fx)
        @a = next_x
        @fa = next_fx
      else
        @b = next_x
        @fb = next_fx
      end
    else
      if @context.sign(next_fx) != @context.sign(@fx)
        @a, @b = @x, next_x
        @a, @b = @b, @a if @a > @b
        @fa = eval_f(@a)
        @fb = eval_f(@b)
        @bracketing = true
      end
    end
    # puts "br: #{@bracketing} r-f: #{regula_falsi} x:#{@x}[#{@fx}] l_x:#{@l_x}[#{@l_fx}] #{next_x}"
    next_x
  end

  def validate
    @guess = @guess.uniq
    if @guess.size < 2
      return false if @guess.empty?
      @guess << (@guess.first + 1)
    end
    true
  end

end

if true
solver = RFSecantSolver.new(Float.context, [0.0, 100.0], Tolerance(3, :decimals)) do |x|
  2*x+11.0
end

v = solver.root # with guess: v = solver.root(5.0)
puts v

solver = RFSecantSolver.new(Float.context, [0.0, 10.0], Tolerance(3, :decimals)) do |x|
  y = 2
  y*exp(x)-10
end

v = solver.root # with guess: v = solver.root(5.0)
puts v

end


# TODO: Crenshaw/Secant method

# Solver with equation parameters in a hash
class PSolver
  def initialize(context, tol, *vars, &blk)

    if vars.first.is_a?(Class)
      solver_class = vars.shift
    end
    solver_class ||= RFSecantSolver
    @solver_class = solver_class

    @vars = vars

    @eqn = blk


    @default_guesses = nil

    @context = context
    @tol = tol
    @solver = nil

  end

  def default_guesses=(*g)
    @default_guesses = g
    @solver = nil
  end

  def root(var, parameters)
    init_solver
    @var = var
    @parameters = parameters
    guesses = Array(parameters[var])
    @solver.root *guesses
  end

  def equation_value(v)
    values = @parameters.merge(@var=>v)
    @context.math(*@vars.map{|v| @context.Num(values[v])}, &@eqn)
  end

  private
  def init_solver
    this = self
    @solver ||= @solver_class.new(@context, @default_guesses, @tol){|v| this.equation_value(v)}
  end

end
# + clean eqn syntax
# - redundancy in paramter declaration

# ln(x+1)
def lnp1(context, x)
  v = x + 1
  (v == 1) ? x : (x*context.ln(v) / (v - 1))
end


tvm = PSolver.new(Float.context, Tolerance(3,:decimals), :m, :t, :m0, :pmt, :i, :p) do |m, t, m0, pmt, i, p|
  i /= 100
  i /= p
  n = -t
  k = exp(lnp1(self, i)*n) # (i+1)**n
  # Equation: -m*k = m0 + pmt*(1-k)/i
  m0 + pmt*(Num(1)-k)/i + m*k
end

tvm.default_guesses = 1,2
sol = tvm.root :pmt, :t=>240, :m0=>10000, :m=>0, :i=>3, :p=>12 #, :pmt=>[1,2]
puts sol.inspect

# --------------------------


# how to get Proc paramters names?
# one way: http://github.com/wycats/merb/tree/master/merb-action-args
# In Ruby 1.9.2: eqn.parameters.map(&:last)

# Time Value of Money
class TVM

  def initialize(tol, context=Float.context)
    @context = context
    @var_descriptions = {
      :m=>'money value at time t',
      :t=>'time',
      :m0=>'initial money value',
      :pmt=>'payment per time unit',
      :i=>'percent interest per year',
      :p=>'numer of time units per year'
    }
    # cannot, do @vars = @var_descriptions.keys, because we depend on the order of the variables to cal equation
    @vars = [:m, :t, :m0, :pmt, :i, :p]
    vars = @vars
    tvm = self
    @solver = PSolver.new(context, tol, :m, :t, :m0, :pmt, :i, :p) do |m, t, m0, pmt, i, p|
      tvm.equation(m, t, m0, pmt, i, p)
    end
    @solver.default_guesses = 1,2
    @one = @context.Num(1)
  end

  def parameter_descriptions
    @var_descriptions
  end

  # parámetros:
  #  :t tiempo en periodos
  #  :p nº periodos por año
  #  :i interés anual porcentual
  #  :pmt pago por periodo
  #  :m0 valor inicial
  #  :m valor en :t
  def solve(parameters)
    nil_vars = @vars.select{|var| parameters[var].nil?}
    raise "Too many unknowns" if nil_vars.size>1
    raise "Nothing to solve" if nil_vars.empty?
    var = nil_vars.first
    # determine sensible initial value? => parameters[var] = initial_value
    {var=>@solver.root(var, parameters)}
  end

  def value(parameters)
    equation(*@vars.map{|var| @context.Num(parameters[var])})
  end

  def equation(m, t, m0, pmt, i, p)
    i /= 100
    i /= p
    n = -t
    k = @context.exp(lnp1(i)*n) # (i+1)**n
    # Equation: -m*k = m0 + pmt*(1-k)/i
    m0 + pmt*(@one-k)/i + m*k
  end

  # ln(x+1)
  def lnp1(x)
    v = x + 1
    (v == 1) ? x : (x*@context.ln(v) / (v - 1))
  end


end

puts "TVM tests"

tvm = TVM.new(Tolerance(3, :decimals), Float.context)
sol = tvm.solve(:t=>240, :m0=>10000, :m=>0, :i=>3, :p=>12)
puts sol.inspect

#puts tvm.value({:t=>240, :m0=>10000, :m=>0, :i=>3, :p=>12}.merge(sol))

tvm = TVM.new(Tolerance(3, :decimals), DecNum.context)
sol = tvm.solve(:t=>240, :m0=>10000, :m=>0, :i=>3, :p=>12)
puts sol.inspect


tol = Tolerance(4, :decimals)
tol = Tolerance(4, :sig_decimals)
tol = Tolerance(1, :epsilon)
tol = Tolerance(40, :sig_decimals)
#tol = Tolerance(Rational(1,1000000), :relative)

puts "\nTOL: #{tol}"

puts "\nExpected: 63,000,031.4433"
tvm = TVM.new(tol, Float.context)
sol = tvm.solve(:t=>63, :m0=>0, :pmt=>-1000000, :i=>0.00000161*12, :p=>12)
puts sol.inspect

# DecNum.context.precision = 12

tvm = TVM.new(tol, DecNum.context)
sol = tvm.solve(:t=>63, :m0=>0, :pmt=>-1000000, :i=>DecNum('0.00000161')*12, :p=>12)
puts sol.inspect


puts "\nExpected: 331,667.006691"
n = 31536000
tvm = TVM.new(tol, Float.context)
sol = tvm.solve(:t=>n, :m0=>0, :pmt=>-0.01, :i=>10.0/n, :p=>1)
puts sol.inspect



n = 31536000
tvm = TVM.new(tol, DecNum.context)
sol = tvm.solve(:t=>n, :m0=>0, :pmt=>-DecNum('0.01'), :i=>DecNum(10)/n, :p=>1)
puts sol.inspect

puts "============="

# n=63
# i=0.00000161
# PV=0
# PMT=-1,000,000
# END Mode
#
# Solving for FV:
# (correct is 63,000,031.4433)
#




# Example 2:
#
# n=31536000
# i=10/n
# PV=0
# PMT=-0.01
# END Mode
#
# Solving for FV:
# (correct is 331,667.006691)

#exit

puts " Solver tests"

TESTS = [
  [ lambda{|x| x**3 + 3*x**2 - 10 }, 1.49203, [[-1,2], [1,2], [-1,1], [0,1], [1,1.1], [2,2.1],[0,0]] ],
  [ lambda{|x| x**3 + 4*x**2 - 10 }, 1.36523, [[-1,2], [1,2], [-1,1], [0,1], [1,1.1], [2,2.1],[0,0]] ],
  [ lambda{|x| sqrt(2)*sqrt(x)-x }, [0,2], [[0,3], [0,1], [1,3], [1,1.1], [2.1,2.2],[0,0]] ],
  [ lambda{|x| 8/(x-2)-x},[-2,4,2], [[-4,6],[-4,0],[0,3],[3,6],[-5,-4],[-1,0],[3,3.5],[5,6],[0,0]] ], # 2 asymptote
  [ lambda{|x| tan(x) }, [-Math::PI, -Math::PI/2, 0, Math::PI/2, Math::PI],[[-4,4],[-4,-2],[-2,-1],[-1,1],[1,2],[2,4],[-4,3.5],[-1,-0.5],[-0.5,-0.4],[0.4,0.5],[0.5,1],[3.5,4],[0,0]] ],
  [ lambda{|x| x**2/4 + x/2 - x }, [0,2], [[-1,3], [-1,1], [1,3], [-2,-1], [1,1.5], [3,4],[0,0]] ],
  [ lambda{|x| -x**2/4 - x/2 + 4 - x }, [-8,2], [[-10,5], [-10,-5], [-5,5], [-10,-9], [-5,0], [3,5],[0,0]] ],
  [ lambda{|x| exp(x)*3-cos(x)*4 },
                        [-7.853690396760657,-4.719081558132556,-1.381206099750212, 0.2548500590288502],
                        [[-10,1], [-10,-5], [-5,-2], [-2,-1], [-1,1], [-9,-8],[-6,-5],[-3,-2],[-1,0],[1,2],[0,0]] ],
  [ lambda{|x| 25*x**2 -10*x +1},[0.2],[[-1,1],[0,1],[-2,-1],[-1,0],[1,2],[0,0]]],
  [ lambda{|x| x**3-x+3}, -1.6717, [[-1,0],[-2,-1],[0,1],[1,2], [0,0]]], # problems: inflexion at 0 [-1,0] and min at 1 [0,1],[0,0]
  [ lambda{|x| exp(-x)-0.5}, Math.log(2.0), [[0,0.5],[0,1],[1,2],[0,2]]],
  [ lambda{|x| x-4*sin(x)+exp(-x**(-6))-5}, [ 3.314108580032628, 7.218026767151556, 7.972122037478666], [[-5,-4],[-4,2],[2,7.5],[7.5,9],[-5,10]]],
  [ lambda{|x| exp(-x)-0.5}, Math.log(2.0), [[0,0.5],[0,1],[1,2],[0,2]]],
  [ lambda{|x| -1+1.3*x-0.3*x**2-1E-15*x**13}, ['1.0000000000000014286','3.3333333333332804233','-300000000000004.33333'], [[-200000000000002.16,2.1666666666666],[-1,1],[-1,-2],[-1,5],[2,4]]]
]

# TODO: add difficult guesses: extrema...

# TODO: DSL for test case definition:
# tests = solver_tests do
#
#   test "Simple Equation" do
#     eqn{|x| exp(x)*sin(x)}
#     roots Rational(1,3), 7, '1.5'
#     guess ...
#     guess ...
#     guesses ...
#     comments %{
#        Has maximum at ...
#     }
#   end
#   ...
#   test_scenario RFSecantSolver, DecNum.context(:precision=>25)
#   test_scenario RFSecantSolver, Float.context
#
# end
# tests.run # and report

TESTS2 = [
  [ lambda{|x, context| context.atan(x)},0,[[-1,1],[-1,-2],[1,2],[0,0],[0.583312,1],[0.691958,0.791656]]],
]

DecNum.context.define_conversion_from(Float) do |x, dec_context|
  BinNum.context(:rounding=>dec_context.rounding) do |bin_context|
    BinNum(x).to_decimal
  end
end
DecNum.context.traps[DecNum::DivisionByZero] = false
DecNum.context.traps[DecNum::InvalidOperation] = false

class SolverStats
  def initialize
    @ok_n = 0
    @ok_it = 0
    @ok_max_it = 0
    @fail_n = 0
    @fail_it = 0
    @fail_max_it = 0
  end

  def add(ok, solver)
    if ok
      @ok_n += 1
      @ok_it += solver.iteration
      @ok_max_it = solver.iteration if solver.iteration>@ok_max_it
    else
      @fail_n += 0
      @fail_it += solver.iteration
      @fail_max_it = solver.iteration if solver.iteration>@fail_max_it
    end
  end

  def ok_avg_it
    @ok_n==0 ? 0 : @ok_it/@ok_n
  end

  def fail_avg_it
    @fail_n==0 ? 0 : @fail_it/@fail_n
  end

  attr_reader :ok_n, :ok_max_it, :fail_n, :fail_max_it

  def report
    msg = []
    msg << "OK #{ok_n} avg: #{ok_avg_it} max: #{ok_max_it}" if ok_n > 0
    msg << "FAIL #{fail_n} avg: #{fail_avg_it} max: #{fail_max_it}" if fail_n > 0
    msg.join("\n")
  end

end


class SolverTests
  def initialize(f, sols, tol, context, solver_class)
    @f = f
    @sols = sols
    @tol = tol
    @context = context
    @solver_class = solver_class

    @stats = SolverStats.new
  end
  def test(*guesses)
    # return status, report
    guesses = Array(guesses)
    if guesses.size == 1
      x1 = x2 = guesses.first
    else
      x1, x2 = guesses
    end
    x1 = @context.Num(x1)
    x2 = @context.Num(x2)
    context = @context
    f = @f
    solver = @solver_class.new(@context, [x1, x2], @tol) do |x|
      context.instance_exec(x, &f)
    end
    v = solver.root

    best = Array(@sols).map{|y| (v-@context.Num(y)).abs}.min
    msg =  "  #{context.num_class}: #{v} [#{best}] :: #{x1} #{x2} <#{solver.reason.inspect} #{solver.iteration}>"
    ok = @tol.zero?(best, v)
    @stats.add ok, solver
    self.class.stats.add ok, solver
    return ok, msg
  end

  attr_reader :stats

  class <<self
    attr_accessor :stats
  end

  self.stats = SolverStats.new

end

class SolverTestsDsl
end

tol = Tolerance(6,:sig_decimals)
TESTS.each do |f, sols, guesses|
  puts sols.inspect
  [Float.context, DecNum.context].each do |context|

    tester = SolverTests.new(f, sols, tol, context, RFSecantSolver)

    guesses.each do |x1, x2|
      ok, msg = tester.test x1, x2
      puts msg unless ok
    end

    puts "#{context.num_class}:\n#{tester.stats.report}"

  end
  puts "-----"
end
puts "============\n#{SolverTests.stats.report}"


def test_root(f, sols, guesses, tol, context=Float.context, solver_class=RFSecantSolver)
  guesses = Array(guesses)
  if guesses.size == 1
    x1 = x2 = guesses.first
  else
    x1, x2 = guesses
  end
  x1 = context.Num(x1)
  x2 = context.Num(x2)
  solver = solver_class.new(context, [x1, x2], tol) do |x|
    # To avoid this uglyness we could always handle parameters outside the solver...
    # i.e. solver only handles one variable (the one to be solved); in TVM we keep parameters and
    # solve variable in instance variables, used to call the equation method
    context.instance_exec(x, &f)
    # f.call(parameters[:x])
  end
  v = solver.root

  best = Array(sols).map{|y| (v-context.Num(y)).abs}.min
  msg =  "  #{context.num_class}: #{v} [#{best}] :: #{x1} #{x2} <#{solver.reason.inspect} #{solver.iteration}>"
  puts msg unless tol.zero?(best, v)
end

tol = Tolerance(6,:sig_decimals)
TESTS.each do |f, sols, guesses|
  puts sols.inspect
  guesses.each do |x1, x2|
    [Float.context, DecNum.context].each do |context|
      test_root f, sols, [x1, x2], tol, context
    end
  end
  puts "-----"
end




