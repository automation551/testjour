module Testjour
module Commands

  class Command
    
    def initialize(args = [], out_stream = STDOUT, err_stream = STDERR)
      @args = args
      @out_stream = out_stream
      @err_stream = err_stream
    end
    
  protected
  
    def cucumber_configuration
      return @cucumber_configuration if @cucumber_configuration
      
      @cucumber_configuration = Cucumber::Cli::Configuration.new(StringIO.new, StringIO.new)
      @cucumber_configuration.parse!(@args)
      @cucumber_configuration
    end
    
    def load_plain_text_features(files)
      features = Cucumber::Ast::Features.new(cucumber_configuration.ast_filter)
      
      Array(files).each do |file|
        features.add_feature(parser.parse_file(file))
      end
      
      return features
    end
    
    def parser
      @parser ||= Cucumber::Parser::FeatureParser.new
    end
    
    def step_mother
      Cucumber::Cli::Main.instance_variable_get("@step_mother")
    end
    
  end
  
end
end