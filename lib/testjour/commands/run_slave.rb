require "testjour/commands/command"
require "cucumber"
require "daemons/daemonize"
require "testjour/cucumber_extensions/http_formatter"
require "testjour/mysql"
require "stringio"

module Testjour
module Commands
    
  class RunSlave < Command
    
    def execute
      daemonize
      Testjour.logger.info "Starting run:slave"
      
      parse_options
      
      setup_mysql if mysql_mode?
      
      initialize_cucumber
      require_files
      work
    end
    
    def parse_options
      @queue_uri = @args.shift
      @mysql_mode = @args.delete("--create-mysql-db")
    end
    
    def setup_mysql
      mysql = MysqlDatabaseSetup.new
      mysql.create_database
      ENV["TESTJOUR_DB"] = mysql.runner_database_name
      
      if File.exist?(File.expand_path("./db/schema.rb"))
        silence_stream(STDOUT) do
          system schema_load_command(mysql.runner_database_name)
        end
      end
          
      at_exit do
        mysql.drop_database
      end
    end
    
    def mysql_mode?
      return true if @mysql_mode
      return false unless File.exist?("testjour.yml")
      testjour_yml = File.read("testjour.yml")
      testjour_yml.include?("--create-mysql-db")
    end
    
    def daemonize
      original_working_directory = File.expand_path(".")
      logfile = File.expand_path("./testjour.log")
      Daemonize.daemonize(logfile)
      Dir.chdir(original_working_directory)
      Testjour.setup_logger
    end
    
    def initialize_cucumber
      require 'cucumber/cli/main'
      
      cucumber_configuration.load_language
      step_mother.options = cucumber_configuration.options
    end
    
    def work
      HttpQueue.with_queue(@queue_uri) do |queue|
        feature_file = true
        
        while feature_file
          begin
            feature_file = queue.pop(:feature_files)
          rescue Curl::Err::ConnectionFailedError
            feature_file = false
          end
          
          if feature_file
            Testjour.logger.info "Running: #{feature_file}"
            features = load_plain_text_features(feature_file)
            execute_features(features)
          end
        end
      end
    end
    
    def execute_features(features)
      visitor = Testjour::HttpFormatter.new(step_mother, StringIO.new, cucumber_configuration.options, @queue_uri)
      visitor.visit_features(features)
    end
    
    def require_files
      cucumber_configuration.files_to_require.each do |lib|
        Testjour.logger.info "Requiring: #{lib}"
        require lib
      end
    end
    
    def schema_load_command(database_name)
      "#{testjour_path} mysql:load_schema #{database_name}"
    end
    
  end
  
end
end