# Generate test data for trigonometry tests (test_trig.rbG)

require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))
require File.dirname(__FILE__) + '/../lib/flt/math'
include Flt

def around(x)
  [x,x.next_plus,x.next_minus,x.next_plus.next_plus,x.next_minus.next_minus]
end

def near(x)
  ulp = x.ulp
  prec = x.num_class.context.precision
  xs = around(x)
  [2,3,4].each do |k|
    d = (prec/k)*ulp
    xs += around(x-d)
    xs += around(x+d)
  end
  xs.uniq
end

# random angles in radians for sin,cos,tan
def angle_data(num_class)
  xs = []
  pi = num_class::Math.pi
  (-8..8).each do |k|
    x = k*pi/4
    xs += near(x)
  end
  pi2 = pi/2
  50.times{ xs << random_num_one(num_class)*pi2}
  base = xs.dup
  (2...10).each do |k|
    xs += base.map{|x| x+num_class.int_radix_power(k)}
  end
  xs.uniq
end

# random data in [-1,-1] for asin, acos
def one_data(num_class)
  half = num_class.Num(1)/2
  zero = num_class.Num(0)
  one = num_class.Num(1)
  xs = [-one, -half, zero, half, one].map{|x| near(x)}.flatten
  50.times{ xs << random_num_one(num_class)}
  xs.uniq.reject{|x| x<-1 || x>1}
end

def random_num_one(num_class=DecNum)
  context = num_class.context
  if false # rand(20)==0
    # generate 5% of subnormals
    f = rand(context.radix**(context.precision-1))
    e = context.etiny
  elsif rand(20)==0
    # and some singular values too
    if rand(1) == 0
      f = context.radix**context.precision - 1
      f -= rand(3)
    else
      f = context.radix**(context.precision - 1)
      f += rand(3)
    end
    # e = random_integer(context.etiny, context.etop)
    if rand(1)==0
      e = random_integer(-context.precision-1,-context.precision)
     else
      e = random_integer(-context.precision-10,-context.precision)
    end
  else
    f = rand(context.radix**context.precision)
    # e = random_integer(context.etiny, context.etop)
    if rand(1)==0
      e = random_integer(-context.precision-1,-context.precision)
     else
      e = random_integer(-context.precision-10,-context.precision)
    end
  end
  # f = -f if rand(1)==0
  context.Num(f, e)
end


def gen_test_data(num_class, prec)
  dir = File.dirname(__FILE__)+'/trigtest'
  num_class.context(:precision=>prec) do
    angles = angle_data(num_class)
    File.open("#{dir}/sin#{prec}.txt","w") do |out|
      angles.each do |angle|
        result = +num_class.context(:precision=>prec+100) {
          num_class::Math.sin(angle)
        }
        out.puts "#{angle}\t#{result}"
      end
    end
    File.open("#{dir}/cos#{prec}.txt","w") do |out|
      angles.each do |angle|
        result = +num_class.context(:precision=>prec+100) {
          num_class::Math.cos(angle)
        }
        out.puts "#{angle}\t#{result}"
      end
    end
    File.open("#{dir}/tan#{prec}.txt","w") do |out|
      angles.each do |angle|
        result = +num_class.context(:precision=>prec+100) {
          num_class::Math.tan(angle)
        }
        out.puts "#{angle}\t#{result}"
      end
    end
    xs = one_data(num_class)
    File.open("#{dir}/asin#{prec}.txt","w") do |out|
      xs.each do |x|
        result = +num_class.context(:precision=>prec+100) {
          num_class::Math.asin(x)
        }
        out.puts "#{x}\t#{result}"
      end
    end
    File.open("#{dir}/acos#{prec}.txt","w") do |out|
      xs.each do |x|
        result = +num_class.context(:precision=>prec+100) {
          num_class::Math.acos(x)
        }
        out.puts "#{x}\t#{result}"
      end
    end
    xs += Array.new(100){random_num(num_class)}
    File.open("#{dir}/atan#{prec}.txt","w") do |out|
      xs.each do |x|
        result = +num_class.context(:precision=>prec+100) {
          num_class::Math.atan(x)
        }
        out.puts "#{x}\t#{result}"
      end
    end
  end
end

srand 12322
gen_test_data DecNum, 12

# TODO:
# 1. prepare test data for 12, 15, 25, 50 digits with gen_test_data
# 2. check with RPL, Mathematica:
#    programs that process test data and prepare RPL/Mathematica programs that yield results
#    then check results
#    RPL: (to be executed in emulator for speed/ease of I/O)
#     \<< [angle1, angle2, angle3, ...] N \-> D N \<< 1 N FOR I D I GET SIN NEXT N \->LIST \>> |>>
#    Mathematica:
#      F[x_]:=N[Sin[x],prec]
#      Map[F, {angle1.to_r.to_s, angle2.to_r.to_s, ...}]
# 3. add special number tests (nans, infinities)