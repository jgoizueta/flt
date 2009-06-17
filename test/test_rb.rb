# Test only RB Decimal (use with "rake test TEST=test/test_rb.rb")
require File.dirname(__FILE__) + '/test_helper.rb'
$implementations_to_test = [FPNum::RB]
require File.dirname(__FILE__) + '/all_tests.rb'
