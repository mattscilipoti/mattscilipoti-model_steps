require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "mattscilipoti-model_steps"
    gem.summary = %Q{Model Steps for cucumber}
    gem.description = %Q{Step Definitions for cucumber which support ActiveRecord Models}
    gem.email = "matt@scilipoti.name"
    gem.homepage = "http://github.com/mattscilipoti/mattscilipoti-model_steps"
    gem.authors = ["Matt Scilipoti", "Chris Cahoon"]
    gem.add_runtime_dependency "friendly_id", '~> 3.0'
    gem.add_runtime_dependency "aaronh-chronic", '~> 0.3.9'
    gem.add_development_dependency "micronaut"
    gem.add_development_dependency "cucumber"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

begin
  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new(:features)

  task :features => :check_dependencies
rescue LoadError
  task :features do
    abort "Cucumber is not available. In order to run features, you must: sudo gem install cucumber"
  end
end


require 'rake/testtask'

Rake::TestTask.new do |t|
  t.pattern = "test/*_spec.rb"
end
task :default => :test


require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "mattscilipoti-model_steps #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
