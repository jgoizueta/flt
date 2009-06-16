require File.dirname(__FILE__) + '/test_helper.rb'



class TestMultithreading < Test::Unit::TestCase

  def setup
    $implementations_to_test.each do |mod|
      initialize_context mod
    end
  end

  def test_concurrent_precision
    $implementations_to_test.each do |mod|
      threads = []
      for prec in (5..100)
        threads << Thread.new(prec) do |p|
          n = 10000/(p/3)
          n_fails = 0
          mod::Decimal.local_context do
            mod::Decimal.context.precision = p
            n.times do
              t = (mod::Decimal(1)/mod::Decimal(3)).to_s
              n_fails += 1 if (t.size!=(p+2)) || (mod::Decimal.context.precision!=p)
            end
          end
          Thread.current[:n_fails] = n_fails
        end
      end
      total_fails = 0
      threads.each{|thr| thr.join; total_fails += thr[:n_fails]}
      assert total_fails==0,"Context precision different per thread"
    end
  end

end
