require 'rubygems'
require 'bundler/setup'
gem 'minitest'
require 'minitest/autorun'
# require 'minitest/pride'
require 'timecop'

require File.expand_path("../lib/cucumber_ast_table.rb", File.dirname(__FILE__))

module Cucumber::Ast
  describe Table do
    describe ".map_chronic_columns!" do
      it "should parse a column ending in '_at' through chronic" do
        Timecop.freeze do
          @table = Table.new(
            [ %w{created_at},
              ["2 days ago"]
          ])
          @table.map_chronic_columns!

          @table.hashes.first['created_at'].must_equal 2.days.ago
        end
      end
    end
  end
end
