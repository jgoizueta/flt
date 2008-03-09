require 'test/unit'
ARGV.shift if ARGV.first=='--' # for Ruby 1.9
if !defined?(TESTING)
  if ARGV.first && ARGV.first.strip.downcase=='-bd'
    ARGV.shift
    #STDERR.puts "TESTING BD"
    TESTING = :bd
    require File.dirname(__FILE__) + '/../lib/decimal_bd'
  else
    #STDERR.puts "TESTING RB"
    TESTING = :ruby
    require File.dirname(__FILE__) + '/../lib/decimal'
  end
end

