require File.dirname(__FILE__) + '/test_helper.rb'


class TestFlags < Test::Unit::TestCase

  def test_flags
    f = FPNum::Flags(:flag_one, :flag_three)
    assert_equal "[:flag_one, :flag_three]",  f.to_a.sort_by{|flg| flg.to_s}.inspect
    f.values = FPNum::FlagValues(:flag_one, :flag_two, :flag_three)
    assert_equal "FPNum::Flags[flag_one, flag_three] (0x5)", f.inspect
    f[:flag_two] = true
    assert_equal "FPNum::Flags[flag_one, flag_two, flag_three] (0x7)", f.inspect
    f[:flag_one] = false
    assert_equal "FPNum::Flags[flag_two, flag_three] (0x6)", f.inspect
    f.clear!
    assert_equal "FPNum::Flags[] (0x0)", f.inspect
    f << [:flag_one,:flag_two]
    assert_equal "FPNum::Flags[flag_one, flag_two] (0x3)", f.inspect
    g = FPNum::Flags(f.values)
    g.bits = f.bits
    assert_equal "FPNum::Flags[flag_one, flag_two] (0x3)", g.inspect
    assert g==f
    g.set!
    assert_equal "FPNum::Flags[flag_one, flag_two, flag_three] (0x7)", g.inspect
    assert g!=f

    assert FPNum::Flags(:flag_one, :flag_three)==FPNum::Flags(:flag_three, :flag_one)
    assert FPNum::Flags(:flag_one, :flag_three)!=FPNum::Flags(:flag_one)



  end

end
