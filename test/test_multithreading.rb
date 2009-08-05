require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))



class TestMultithreading < Test::Unit::TestCase

  def setup
    initialize_context
  end

  def test_concurrent_precision
    threads = []
    for prec in (5..100)
      threads << Thread.new(prec) do |p|
        n = 10000/(p/3)
        n_fails = 0
        DecNum.local_context do
          DecNum.context.precision = p
          n.times do
            t = (DecNum(1)/DecNum(3)).to_s
            n_fails += 1 if (t.size!=(p+2)) || (DecNum.context.precision!=p)
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
