require File.dirname(__FILE__) + '/test_helper.rb'
require File.dirname(__FILE__) + '/test_flags.rb'
require File.dirname(__FILE__) + '/test_basic.rb'
if TESTING!=:bd
  require File.dirname(__FILE__) + '/test_dectest.rb'
end
require File.dirname(__FILE__) + '/test_multithreading.rb'

