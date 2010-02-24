$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
#require 'model_steps/step_definitions'

require 'micronaut/expectations'

World(Micronaut::Matchers)
