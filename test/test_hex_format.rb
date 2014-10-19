require File.expand_path(File.join(File.dirname(__FILE__),'helper.rb'))

class TestHexFormat< Test::Unit::TestCase

  def test_hex_input

    if RUBY_VERSION >= "1.9.2" # luckily there's no 1.9.10!

      data = [0.1, 1.0/3, 0.1e10, 1e10/3.0, 0.1e-10, 1e-10/3.0, 123456.789,
        -0.1, -1.0/3, -0.1e10, -1e10/3.0, -0.1e-10, -1e-10/3.0, -123456.789,
        Float::MAX, -Float::MIN, Float::MIN_D, Float::MAX_D, Float::MIN_D,
        -Float::MIN_D, -Float::MAX_D, -Float::MIN_D,
        Float.context.next_plus(0.1), Float.context.next_minus(0.1),
        -Float.context.next_plus(0.1), -Float.context.next_minus(0.1),
        0.5, Float.context.next_plus(0.5), Float.context.next_minus(0.5),
        -0.5, -Float.context.next_plus(0.5), -Float.context.next_minus(0.5),
        1E22, -1E22, 64.1, -64.1]

      BinNum.context(BinNum::FloatContext) do
        data.each do |number|
          hex_upcase = "%A" % number
          hex_downcase = "%a" % number

          assert_equal number, BinNum(hex_upcase).to_f, "Read #{hex_upcase} (number)"
          assert_equal number, BinNum(hex_downcase).to_f, "Read #{hex_downcase} (number)"
        end
      end

    end

  end

end
