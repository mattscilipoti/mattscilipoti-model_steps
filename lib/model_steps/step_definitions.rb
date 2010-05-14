Cucumber::Ast::Table.class_eval do
  def is_date_column?(column_name)
    column_name.columnify =~ /( at|_at|time|date)$/i
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
        parsed_value.to_s
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


#This file contains steps which work with rails' models, but are not for a specific model
Then /^I should see no (\D+)$/ do |requested_model|
  Then "I should see 0 #{requested_model}"
end

Then /^I should see (\d+) (\D+)$/ do |expected_count, requested_model|
  expected_count = expected_count.to_i
  css_class = requested_model.underscore
  if expected_count > 0
    response.should have_tag("table.#{css_class}") do
      with_tag("tbody tr", expected_count)
    end
  else
    #response.should have_tag("div.#{css_class}", translate(:none_found)) #TODO: undefined method `translate' for #<ActionController::Integration::Session:0xb4f3e9e0> (NoMethodError)
    response.should have_tag("div.#{css_class}", 'None found')
  end

end

Then /^I should see (?:these|this|the following) (\D+):$/ do |requested_model, table|
  # table is a Cucumber::Ast::Table
  table.map_chronic_columns!
  #WORKAROUND: why does table.diff! expect Trouble to be nil (vs. '')?
#  table.map_columns!(['Trouble']) {|trouble_message| trouble_message == '\nil' ? nil : trouble_message}

  mapped_table = map_table_headers(table)

  requested_table = (requested_model =~ /^(.+)[(](.+)[)]$/) ? $1 : requested_model

  css_class = requested_table.pluralize.underscore

  html_table = table(tableish("table.#{css_class} tr", 'td,th'))

  mapped_table.diff!(html_table)
end


#Given the following Camera Events exist:
#Note: use ((?!.*should) to avoid conflicts with
#  Given the following Camera Events should exist:
Given /^(?:these|this|the following) (?!.*should)(.+) exist:$/ do |requested_model, table|

  # table is a Cucumber::Ast::Table
  model = requested_model_to_model(requested_model)

  map_table_columns!(table)
  mapped_table = map_table_headers(table)
  mapped_table.hashes.each do |table_row|

    requested_params = table_row.dup

    model_params = requested_params_to_model_params(requested_params, model)

    model_under_test = Factory.create(model_to_factory_symbol(requested_model), model_params)

    model_under_test
  end

end

#Given ModelA:unique_ident exists
# Create a new ModelA with default_identifier_column = default_identifier
Given /^(.+):(.+) exists$/ do |requested_model, default_identifier|
  model = requested_model_to_model(requested_model)
  column_name = model.default_identifier_column
  Factory.create(model_to_factory_symbol(requested_model), column_name => default_identifier)
end

#Given ModelA:DI has 3 ModelBs
Given /^(.+):(.+) has (\d+) (?!.*with:)(.+)$/ do |requested_model, default_identifier, association_quantity, requested_association_name|
  association_quantity = association_quantity.to_i
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
  create_requested_model_associations(model_under_test, association_quantity, requested_association_name.pluralize)
end

#Given ModelA:DI has 3 ModelBs with:
#  |attribute_name|
#  |attribute_name|
#  |value         |
Given /^(\D+):(.+) has (\d+) (\D+) with:$/ do |requested_model, default_identifier, association_quantity, requested_association_name, table|
  association_quantity = association_quantity.to_i
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
#  default_params = table ? table.hashes.first : {}
  default_params = table.hashes.first
  create_requested_model_associations(model_under_test, association_quantity, requested_association_name.pluralize, [], default_params)
end

#7/09: find_or_create was not creating.  Validations?  Use Factory?
##Given ModelA:DI_A has ModelB:DI_B
Given /^(\D+):(.+) has (\D+):(.+)$/ do |requested_model, default_identifier, association_model_name, associated_model_default_identifier|
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
  associated_model = requested_model_to_model(association_model_name)
  factory_name = model_to_factory_symbol(associated_model)
  associated_model_under_test = associated_model.find_by_default_identifier(default_identifier) || Factory(factory_name, associated_model.default_identifier_column => default_identifier)

  possible_associations = [association_model_name.underscore, association_model_name.pluralize.underscore]
  association_name = possible_associations.detect {|association_name| model_under_test.respond_to?(association_name)}

  if association_name
    if association_name.pluralize == association_name
      associated_items = model_under_test.send(association_name)
      associated_items << associated_model_under_test
    else
      model_under_test.send(association_name + '=', associated_model_under_test)
    end
    model_under_test.save!

  else
    raise "Neither of these associations exist for #{model_under_test.class.name}: #{possible_associations.inspect}"
  end
end

Given /^(.+):(.+) (?:has|had) (?:these|this|the following) attributes:$/ do |requested_model, default_identifier, table|
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)

  attributes = map_table_headers(table).hashes.first
  model_under_test.update_attributes!(attributes)
end

#Given ModelA has the following existing ModelB's (see table)
# Finds the ModelB's which match the conditions
#  And assigns themto ModelA.association
Given /^(\D+):(.+) has (?:these|this|the following) existing (\D+):$/ do |requested_model, default_identifier, requested_association_name, table|
  association_quantity = table.rows.size

  map_table_columns!(table)
  array_of_requested_params = table.hashes
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
  assign_requested_model_associations(model_under_test, association_quantity, requested_association_name, array_of_requested_params)
end

#Given ModelA has this ModelB (see table)
#Given ModelA has these ModelBs (see table)
#Given ModelA has the following ModelBs (see table)
#Given ModelA has these ModelBs(factory suffix) (see table)
Given /^(.+):(.+) (?:has|had) (?:these|this|the following) (?!existing |attributes)(.+)?:$/ do |requested_model, default_identifier, requested_association_name, table|
  #needs negative look behind (?!existing) for "has these existing ModelBs
  #needs negative look behind (?!existing|attributes) AND optional (.+)? for "has these attributes"
  association_quantity = table.rows.size

  map_table_columns!(table)
  array_of_requested_params = table.hashes
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
  create_requested_model_associations(model_under_test, association_quantity, requested_association_name, array_of_requested_params)
end

Given /^(\D+):(.*) performed (?:a|an) (?!\D+:)(\D+)$/ do |requested_model, default_identifier, requested_activity|
  model = requested_model_to_model(requested_model)

  perform_activity(model, default_identifier, requested_activity)
end

Given /^(\D+):(.*) performed the following (\D+)(?:s?):$/ do |requested_model, default_identifier, requested_activity, table|
  model = requested_model_to_model(requested_model)

  activity = perform_activity(model, default_identifier, requested_activity)

  map_table_columns!(table)
  table.hashes.each do |params|
    activity_params = params.dup
    #if successful, completed = started
    unless params[:completed_at] || params[:trouble]
      activity_params.merge!(:completed_at => params[:started_at])
    end
    activity.update_attributes!(activity_params)
  end

end

#Given no CameraEvents exist
#Destroys all CameraEvents
Given /^no (?!.*should)(\D+) exist$/ do |requested_models|
  model_klass = requested_model_to_model(requested_models)
  model_klass.destroy_all
  model_klass.count.should == 0
end

#Given x CameraEvents exist
#Creates x CameraEvents using FactoryGirl
Given /^(\d+) (?!.*should)(\D+) exist$/ do |requested_count, requested_models|
  requested_count = requested_count.to_i

  model_klass = requested_model_to_model(requested_models)
  factory_name = model_to_factory_symbol(requested_models)

  requested_count.times do
    Factory.create(factory_name)
  end

  model_klass.count.should == requested_count
end


Given /^(\D+):(.+) does not exist$/ do |requested_model, default_identifier|
  begin
    model = requested_model_to_model(requested_model)
    instance = model.find_by_default_identifier(default_identifier)
    if instance
      instance.destroy if instance
      instance.reload.should be_nil
    end
  rescue ActiveRecord::RecordNotFound
  end
end

#When I navigate to the page for listing the requested model
When /^I list (.+)s$/ do |requested_model|
  controller_name = requested_model.underscore.pluralize
  visit send(controller_name + "_path")
end

#When I navigate to the page for showing/editing the requested model
When /^I (edit|show) (.+):(.+)$/ do |action, requested_model, default_identifier|
  parent_requested_model, requested_model = requested_model.split('/') if requested_model.include?('/')
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)

  action_prefix = case action
    when 'show'
      ''
    when 'edit'
      'edit_'
    else
      raise "That action (#{action}) is not currently supported."
  end

  #TODO: model.controllerize?
  controller_name = model_under_test.class.base_class.name.underscore

  if parent_requested_model
    parent_model = model_under_test.send(parent_requested_model.underscore)
    parent_prefix = "#{parent_requested_model.underscore}_"
    named_path = action_prefix + parent_prefix + controller_name + "_path"
    visit send( named_path, parent_model, model_under_test)
  else
    named_path = action_prefix + controller_name + "_path"
    visit send( named_path, model_under_test)
  end
  Then "I should not see an error message"

end

When /^I fill in required (.+) fields$/ do |requested_model|
  fill_in_required_fields requested_model
end

When /^I fill in required (.+) fields except:$/ do |requested_model, table|
  fill_in_required_fields(requested_model, table.rows.flatten)
end

#Follow from left to right
#Finds/Creates/assigns each model consecutively
# assigning each previous_model as parent to current
# |Jurisdiciton|Location|Batch|
# also supports assigning attributes to previous model.
# |Jurisdiciton|Location|location_code|
When /^we setup the following:$/ do |table|
  # table is a |US          |L1      |L1_B1           |

  table.rows.each do |row|
    previous_model = nil

    table.headers.each_with_index do |header, column_index|
      value = row[column_index]

      if previous_model && previous_model.respond_to?("#{header}=")
        previous_model.update_attributes!(header => value)
        next
      end

      factory_name = model_to_factory_symbol(header)
      model_klass = header.classify.constantize
      new_model = model_klass.find_by_default_identifier(value)

      new_model_params = {}
      if previous_model
        parent = previous_model
        parent_association = previous_model.class.name.underscore

        case model_klass.name
          when IncidentBatch.name #compare class to class did NOT work??
            parent = previous_model.location_camera
            parent_association = 'location_camera'
        end
        new_model_params.merge!({ parent_association => parent })
      end

      if new_model
        new_model.update_attributes! new_model_params
      else
        new_model_params.merge!({ model_klass.default_identifier_column => value })
        new_model = Factory.create(factory_name, new_model_params)
      end

      previous_model = new_model
    end
  end
end

#When method on ModelA:ID
When /^I "([^"]+)" for (.+):(.+)$/ do |requested_method_name, requested_model, default_identifier|
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
  model_under_test.send(requested_method_name.underscore)
end

#Then Model:default_identifier should exist
Then /^(.+):(.+) should exist$/ do |requested_model, default_identifier|
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
  model_under_test.should_not be_nil
end

Given /^no (\D+) should exist$/ do |requested_models|
  model_klass = requested_model_to_model(requested_models)
  model_klass.count.should == 0
end

#Then the following ModelAs should exist
#Works against actual models (instead of view)
#Verifies model count and each method in each row.
#Assumes:
# * Header = method name
# * the first column in each row is the default identifier for that row.
Then /^(?:these|this|the following) (.+) should exist:$/ do |requested_model, table|
  # table is a Cucumber::Ast::Table
  model_klass = requested_model_to_model(requested_model)

  models_to_verify = requested_models(requested_model)
  assert_models(models_to_verify, table)
end

Then /^there should be (\d*) (.*)$/ do |cnt, requested_model|
  requested_model_to_model(requested_model).count.should == cnt.to_i
end

###Predicates: Location:L1 should [not] be_reachable
###Moved these to rspec.  Left as example.  Feel free to delete.
#Then /^(\D+):(.+) (should|should not) (be \D+)$/ do |requested_model, default_identifier, expectation, predicate_matcher|
#  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
#  model_under_test.send(expectation.underscore, send(predicate_matcher.underscore))
#end

#Then Location:L1 should have the following Pings
#Or
#Then Location:L1 should have these attributes
#Works against actual models (instead of view)
#Verifies model count and each method in each row.
#Assumes:
# * Header = method name
# * the first column in each row is the default identifier for that row.
Then /^(\w+):(.+) (?!.not|NOT)should have (?:these|this|the following) (.+):$/ do |requested_model, default_identifier, association, table|
  # table is a Cucumber::Ast::Table
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
  if association == 'attributes'
    table.hashes.first.each do |attribute, expected_value|
      model_under_test.send(attribute).to_s.should == expected_value
    end
  else
    associated_models = model_under_test.send(association.underscore)
    assert_models(associated_models, table)
  end
end

Then /^(\w+):(.+) should (?:not|NOT) have (?:these|this|the following) (.+):$/ do |requested_model, default_identifier, association, table|
  # table is a Cucumber::Ast::Table
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)

  if association == 'attributes'
    table.hashes.first.each do |attribute, expected_value|
      model_under_test.send(attribute).to_s.should_not == expected_value
    end
  else
    associated_models = model_under_test.send(association.underscore)
    assert_models(associated_models, table, :should_not)
  end
end

#Then ModelA should have 1 ModelB
Then /^(\w+):(.+) should have (\d+) (.+)$/ do |requested_model, default_identifier, association_count, association|
  model_under_test = requested_model_with_identifier_to_model_instance(requested_model, default_identifier)

  associated_models = model_under_test.send(association.underscore)
  associated_models.size.should == association_count.to_i
end


private

#Compare table values against the expected_models' methods
#Use '*' as a wild card.
#
#Assumes:
# * Header = method name
# * the first column in each row is the default identifier for that row.
def assert_models(expected_models, table, should_not = false)
  model_klass = expected_models.first && expected_models.first.class.base_class rescue expected_models.first.class

  map_table_columns!(table)
  rows = map_table_headers(table).hashes
  if should_not
    expected_models.count.should_not == rows.size
  else
    expected_models.count.should == rows.size
  end

  first_column_name = table.headers[0]

  rows.each_with_index do |requested_params, row_index|
    #Assume first column is unique identifier
    #TODO: just use all columns as conditions.
    default_identifier = requested_params[first_column_name]

    #find the model for this row
    model_under_test = expected_models.detect {|model| model.send(first_column_name).to_s == default_identifier }

    unless should_not
      model_under_test.should_not be_nil
    end if

    if model_under_test
      #compare model with expectations
      requested_params.each do |attribute_name, expected_value|
        actual = model_under_test.send(attribute_name)
        if actual.is_a?(ActiveRecord::Base)
          actual = actual.send(actual.class.default_identifier_column)
        end
        if should_not
          err_msg = "Expected ##{attribute_name} for '#{model_klass.name}:#{default_identifier}'\n\t  to NOT have: '#{expected_value}'\n\tbut was: '#{actual}'\n * Expectations: #{requested_params.inspect} \n * #{model_klass.name}:#{default_identifier}: #{model_under_test.inspect}.\n\n"
          actual.to_s.should_not eql(expected_value), err_msg
        else
          err_msg = "Expected ##{attribute_name} for '#{model_klass.name}:#{default_identifier}'\n\t  to be: '#{expected_value}'\n\tbut was: '#{actual}'\n * Expectations: #{requested_params.inspect} \n * #{model_klass.name}:#{default_identifier}: #{model_under_test.inspect}.\n\n"
          actual.to_s.should eql(expected_value), err_msg
        end
      end
    end
  end
end


def requested_model_with_identifier_to_model_instance(requested_model, default_identifier)
  model = requested_model_to_model(requested_model)
  model_under_test = model.find_by_default_identifier!(default_identifier)
  return model_under_test
rescue ActiveRecord::RecordNotFound
  factory_name = model_to_factory_symbol(requested_model)
  Factory.create(factory_name, model.default_identifier_column => default_identifier)
end

def assign_requested_model_associations(model_under_test, association_quantity, requested_association_name, array_of_requested_params = [])
  model = model_under_test.class

  association_model = requested_model_to_model(requested_association_name)
  association_name = association_model.name.pluralize.underscore


  #TODO: utilize associations in find
  #convert {'location' => 'L1'}
  # to     {:location_id => 1}
  # aka    {:association.foreign_key => requested_model.id}

  existing_objects = array_of_requested_params.collect do |conditions|
    if conditions.keys.first == 'default_identifier'
      #for CameraEvent find by (ImportFile).name
      association_model.find_by_default_identifier(conditions.values.first)
    else
      association_model.find(:first, :conditions => conditions)
    end
  end

  #assign to parent
  model_under_test.send("#{association_name}=", existing_objects)

  assert_equal association_quantity, model_under_test.send(association_name).size, "#{model.name} has incorrect # of #{association_name}"
end

#polymorphic associations are handled during 'assign_to_parent'
def create_requested_model_associations(model_under_test, association_quantity, requested_association_name, array_of_requested_params = [], default_params = {})
  model = model_under_test.class

  association_model = requested_model_to_model(requested_association_name)
  association_name = model_to_association_method(requested_association_name)
  association_factory_name = model_to_factory_symbol(requested_association_name)

  parent_association = {}
  parent = model.name.underscore

  parent_association = {}
  if association_model.instance_methods.include?(parent)
    parent_association = {parent => model_under_test}
  elsif association_model.instance_methods.include?(parent.pluralize)
    parent_association = {parent.pluralize => [model_under_test]}
  end

  objects_to_associate = association_quantity.times.collect do |idx|

    #parse requested params
    converted_params = {}
    unless array_of_requested_params.blank?
      requested_params = array_of_requested_params[idx].dup
      converted_params = requested_params_to_model_params(requested_params, association_model)
    end

    association_model_params = {}
    association_model_params.merge!(parent_association)
    association_model_params.merge!(default_params.merge(converted_params))
    cleaned_params = {}
    association_model_params.each {|key, value| cleaned_params[key] = (value.blank? ? nil : value) }
    Factory.create(association_factory_name, cleaned_params)
  end

  #assign to parent
  if association_name == association_name.singularize
    model_under_test.send("#{association_name}=", objects_to_associate.first)

    #TODO: why odes it perform the assignment (verified in db), but still return nil?
    assert_not_nil model_under_test.send(association_name)
  else
    #append objects, do not assign array of objects.
    objects_to_associate.each do |associated_object|
      association = model_under_test.send("#{association_name}")
      association.send('<<', associated_object) unless association.include?(associated_object)
    end
#    model_under_test.send("#{association_name}=", objects_to_associate)
    scoped_association_name = model_to_association_method(requested_association_name, true)
    association, scope = scoped_association_name.split('.')
    associated_models = model_under_test.send(association)
    if scope
      associated_models = associated_models.send(scope)
    end
    assert_equal association_quantity, associated_models.size, "#{model.name} has incorrect # of #{scoped_association_name}"
  end
end

def fill_in_required_fields(requested_model, rejected_fields = [])
  model = requested_model_to_model(requested_model)
  model_under_test = model.new(Factory.attributes_for(requested_model.underscore.to_sym))
  testable_attributes = model_under_test.attributes.reject {|attribute_name, value| rejected_fields.include?(attribute_name) }

  testable_attributes.each do |attribute_name, value|
    if model_under_test.attribute_required?(attribute_name)
      When "I fill in \"#{attribute_name.to_s.titleize}\" with \"#{value}\""
    end
  end
end

def map_table_columns!(table)
  table.map_chronic_columns!
  table.map_columns!(['size']) { |cell_value| eval(cell_value) if cell_value }
  table.map_columns!(['trouble']) {|trouble_message| Factory.create(:trouble, :message => trouble_message)}
end

def map_table_header(header)
  #TODO: associations should be underscore'd
#  mapped_header = header.columnify
  mapped_header = header
#  mapped_header.sub!('#', 'Number')
  case header
    when 'printer'
      mapped_header = 'printer_prefix'
  end
  mapped_header
end

def map_table_headers(table)

  returning(mappings = {}) do
    table.headers.each do |header|
      mappings[header] = map_table_header(header)
    end
  end

  table.map_headers(mappings)
end

#converts model or model name to symbol for factory
#Examples:
#  image --> :image
#  Image --> :image
#  Images --> :image
#  Images(for scene A) --> :image_for_scene_a
#
def model_to_factory_symbol(model_or_name)
  model_name =
    case model_or_name
      when /^(.+)[(](.+)[)]$/ #handle model(with associations), model(for scene A)
        model_name = $1.singularize
        factory_suffix = $2
        "#{model_name}_#{factory_suffix}"
      when String
        model_or_name
      else
        model_or_name.name
    end
  model_name.singularize.underscore.to_sym
end

#converts model or model name to association method
#Examples:
#  image --> .image
#  Image --> .image
#  Images --> .images
#  Images(for scene A) --> .images.for_scene_a
#
def model_to_association_method(model_or_name, include_scope = false)
  requested_association =
    case model_or_name
      when /^(.+)[(](.+)[)]$/ #handle model(with associations), i.e. Image(for scene A)
        association = $1
        scope = $2
        include_scope ? "#{association}.#{scope}" : association
      when String
        model_or_name
      else
        model_or_name.name
    end
  requested_association.underscore
end

#Retrieves requested models
#
#examples:
#  image --> Image.all
#  Image --> Image.all
#  Images --> Image.all
#  Images(for scene A) --> Image.for_scene_a
#  Images(active, for scene A) --> Image.active.for_scene_a
def requested_models(requested_model)
  case requested_model
    when /^(.+)[(](.+)[)]$/ #handle model(with associations), i.e. Image(for scene A)
      base_model = $1.classify.constantize
      scopes = $2.split(',')
      models = base_model

      scopes.each do |scope|
        models = models.send(scope.strip)
      end

      models.all

    when String #is name
      requested_model.singularize.constantize.all
    else
      requested_model.all
  end
end


def perform_activity(model, default_identifier, requested_activity)
  model_under_test = model.find_by_default_identifier(default_identifier)
  activity = model_under_test.send("do#{requested_activity.singularize}".underscore)
end

#TODO: extract concept for these
def requested_model_to_model(requested_model)
  #move "cases" to mpr_model_steps.
  case requested_model
    when /^Site[s]?$/i, /^PhosphorylationSite[s]?$/i
      return StySiteAbstractGene
    when /^(.+)[(](.+)[)]$/ #handle model(with associations), model(for scene a)
      return requested_model_to_model($1)
    else
      possible_model_name = requested_model.singularize.underscore.classify
      #Note Ping class exists, so check for PingActivity first.
      return "#{possible_model_name}Activity".constantize rescue nil
      return possible_model_name.constantize rescue nil
  end

  raise "Requested Model (#{requested_model}, as #{possible_model_name}) is not supported."
end


def requested_params_to_model_params(requested_params, model)
  converted_params = {}
  #pull put associations
  association_names = model.reflect_on_all_associations.collect &:name

  mapped_params = {}
  requested_params.each {|header, value| mapped_params[header] = value}

  association_params = mapped_params.reject { |param_name, value| !association_names.include?(ModelSteps::Inflector.param_to_association_name(param_name)) }
  association_params.each do |param_name, value|
    next unless value

    association_name = ModelSteps::Inflector.param_to_association_name(param_name).to_s

    if value.include?(':') #is a model:unique_id
      associated_model_class_name, default_identifier = value.split(':')
    else
      association = model.reflect_on_all_associations.detect {|each_association| each_association.name == ModelSteps::Inflector.param_to_association_name(param_name)}
      associated_model_class_name = association.options[:class_name] || association_name.classify
      default_identifier = value
    end

    associated_model = associated_model_class_name.constantize.find_by_default_identifier(default_identifier)

    # TODO handle multiple associations
    if /s$/ =~ association_name
      converted_params[association_name] = [associated_model]
    else
      converted_params[association_name] = associated_model
    end
  end

  model_ar_attr_params = mapped_params.reject {|param_name, value| !model.column_names.include?(param_name)}
  model_attr_setter_params = mapped_params.reject {|param_name, value| !model.instance_methods.include?(param_name + '=') || association_params.keys.include?(param_name + '=')}


  model_setter_params = mapped_params.reject {|param_name, value| !model_ar_attr_params.keys.include?(param_name) && !model_attr_setter_params.keys.include?(param_name) }

  #TODO: pass date_column_names from class, instead of class?
  model_params = model_setter_params#.parse_dates(model)

  non_model_params = mapped_params.reject do |param_name, value|
    model_setter_params.keys.include?(param_name) || association_params.keys.include?(param_name)
  end

  non_model_params.each do |param_name, value|
    case param_name
      when 'location_code'
        location_association = model.new.is_a?(Activity) ? :toiler : :location
        converted_params[location_association] = Location.find_by_location_code(value)
      when 'success?'
        success = non_model_params['success?'].to_bool
        unless success
          converted_params[:command_trouble] = CommandTrouble.new(:message => 'TESTING TROUBLE')
        end
      when 'trouble'
        message = non_model_params['trouble']
        converted_params[:trouble] = Trouble.new(:message => message) if message
      else
        #TODO:
        raise "Header (#{param_name}) is not supported for #{model.name}."
    end
  end
  model_params.merge(converted_params)
end

module ModelSteps
  class Inflector
    def self.param_to_association_name(param_name)
      param_name.underscore.to_sym
    end
  end
end
