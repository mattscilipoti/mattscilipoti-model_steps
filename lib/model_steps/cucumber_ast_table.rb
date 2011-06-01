require 'active_support/core_ext' # blank?
require 'active_support/inflector' # titleize
require 'chronic'
require 'cucumber/ast/table'

Cucumber::Ast::Table.class_eval do

  include ActiveSupport::Inflector

  def is_date_column?(column_name)
    column_name =~ /( at|_at|time|date)$/i
  end

  def chronic_parsable_columns
    chronic_parsable_columns = []
    headers.each do |col|
      next unless is_date_column?(col)

      chronic_parsable_columns << col
      chronic_parsable_columns << col.titleize
    end
    return chronic_parsable_columns
  end

  def map_chronic_columns!
    self.map_columns!(chronic_parsable_columns) do |cell_value|
      if cell_value.blank?
        cell_value
      else
        parsed_value = Chronic.parse(cell_value)
        raise "Chronic can not parse '#{cell_value}' to a date/time." unless parsed_value
        parsed_value
      end
    end
  end

  def map_columns!(headers_to_map)
    existing_headers = self.headers & headers_to_map
    existing_headers.each do |header|
      self.map_column!(header) { |cell_value| yield cell_value }
    end
  end

end


