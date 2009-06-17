# Test only BD Decimal (use with "rake test TEST=test/test_bd.rb")
require File.dirname(__FILE__) + '/test_helper.rb'
$implementations_to_test = [FPNum::BD]
require File.dirname(__FILE__) + '/all_tests.rb'
require File.dirname(__FILE__) + '/bd_tests.rb'

