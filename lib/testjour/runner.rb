#!/usr/bin/env ruby

require File.expand_path("./vendor/plugins/cucumber/lib/cucumber")
require File.expand_path(File.dirname(__FILE__) + "/../testjour")

# Trick Cucumber into not runing anything itself
module Cucumber
 class CLI
   def self.execute_called?
     true
    end
  end
end

ENV["RAILS_ENV"] = "test"
require File.expand_path('./config/environment')

Testjour::MysqlDatabaseSetup.with_new_database do
  
  drb_url = ARGV.shift
  DRb.start_service
  queue_server = DRbObject.new(nil, drb_url)

  # TODO - More Cucumber boilerplate
  extend Cucumber::StepMethods
  extend Cucumber::Tree
  Cucumber.load_language("en")
  $executor = Cucumber::Executor.new(Testjour::DRbFormatter.new(queue_server), step_mother)
  ARGV.clear # Shut up RSpec
  require "cucumber/treetop_parser/feature_en"
  require "cucumber/treetop_parser/feature_parser"
  
  Dir[File.expand_path("./features/steps/*.rb")].each do |file|
    require file
  end
  
  puts
  puts "Connected to #{drb_url}"
  puts
  puts "Ready..."
  puts
  
  parser = Cucumber::TreetopParser::FeatureParser.new

  begin
    loop do
      begin
        file = queue_server.take_work
        
        # TODO - More Cucumber boilerplate
        puts File.expand_path(file)
        features = parser.parse_feature(File.expand_path(file))
        $executor.visit_features(features)
      rescue Testjour::QueueServer::NoWorkUnitsAvailableError
        # If no work, ignore and keep looping
      end
    end
  rescue DRb::DRbConnError
    # DRb server shutdown - we're done
  end
  
end

