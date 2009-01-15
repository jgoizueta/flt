# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  load 'tasks/setup.rb'
end

ensure_in_path 'lib'
#require 'decimal'
require 'decimal/version'

task :default => 'spec:run'


PROJ.name = 'ruby-decimal'
PROJ.description = "Ruby Decimal Type"
PROJ.authors = 'Javier Goizueta'
PROJ.email = 'javier@goizueta.info'
PROJ.version = FPNum::VERSION::STRING
PROJ.rubyforge.name = 'ruby-decimal'
PROJ.url = "http://#{PROJ.rubyforge.name}.rubyforge.org"
PROJ.rdoc.opts = [
  "--main", "README.txt",
  '--title', 'Ruby Decimal Documentation',
  "--opname", "index.html",
  "--line-numbers",
  "--inline-source"
  ]

# EOF
