%{
 test_flags.rb
 test_basic.rb
 test_basic.rb
 test_exact.rb
 test_round.rb
 test_multithreading.rb
 test_comparisons.rb
 test_coercion.rb
 test_to_int.rb
 test_to_rf.rb
 test_define_conversions.rb
 test_odd_even.rb
 test_odd_epsilon.rb
 test_ulp.rb
 test_bin.rb
 test_binfloat_conversion.rb
 test_bin_arithmetic.rb
 test_num_constructor.rb
}.each do |tst|
  require File.expand_path(File.join(File.dirname(__FILE__), tst))
end

