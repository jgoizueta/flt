# Reader tests are lengthy and are not executed by default
# Must be explicitely executed, e.g. with
#  rake test TEST=test/reader.rb

require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestReader < Test::Unit::TestCase


  def setup
    initialize_context
  end

  def test_algorithms_coherence
    srand 1023022
    data = []
    DecNum.context(:precision=>15, :elimit=>90) do
      data += [DecNum('1.448997445238699'), DecNum('1E23'),DecNum('-6.22320623338259E+16'),
               DecNum('-3.83501075447972E-10'), DecNum('1.448997445238699')]
      data += %w{
        1E23
        1.448997445238699
        -6.22320623338259E+16
        -3.83501075447972E-10
        1.448997445238699
        1.23E-30
        1.23456789E-20
        1.23456789E-30
        1.234567890123456789
        0.9999999999999995559107901499
        0.9999999999999996114219413812
        0.9999999999999996669330926125
        0.9999999999999997224442438437
        0.9999999999999997779553950750
        0.9999999999999998334665463062
        0.9999999999999998889776975375
        0.9999999999999999444888487687
        1
        1.000000000000000111022302463
        1.000000000000000222044604925
        1.000000000000000333066907388
        1.000000000000000444089209850
        1.000000000000000555111512313
        1.000000000000000666133814775
        1.000000000000000777156117238
        1.000000000000000888178419700
      }.map{ |num| DecNum(num) }
      data += Array.new(10000){random_num(DecNum)}
    end
    algs = [:M, :R, :A]
    readers = algs.map{|alg| Flt::Support::Reader.new(:algorithm=>alg)}
    [:half_even, :half_up, :half_down, :down, :up, :ceiling, :floor].each do |rounding|
      data.each do |x|
        s,f,e = x.split
        b = x.num_class.radix
        results = readers.map{|reader|
          reader.read(BinNum.context, rounding, s, f, e, b)
        }
        (1...results.size).each do |i|
          assert_equal results.first, results[i], "Read #{x} Alg. #{algs.first} (#{results.first}) != Alg. #{algs[i]} (#{results[i]})"
        end
      end

    end

  end

end
