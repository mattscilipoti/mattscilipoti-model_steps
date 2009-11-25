$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
require 'mattscilipoti-model_steps'

require 'micronaut/expectations'

World(Micronaut::Matchers)
