require "tmpdir"
require "fileutils"
require "active_record"

module ModelGenerator
  class Generator
    attr_reader :connection
    attr_reader :output_path

    SETTINGS_ROOT = File.expand_path('../../../../db', __FILE__)
    
    def initialize(options, out_path = nil)
      @connection_options = options
      @connection = nil
      @output_path = out_path || File.expand_path(File.join(Dir.tmpdir, "rmre_models"))
    end

    def connect
      return if db_settings.empty? || db_settings.nil?
      
      ActiveRecord::Base.establish_connection(@connection_options)
      @connection = ActiveRecord::Base.connection
    end

    def create_models(tables = [], include_prefixes = [])
      FileUtils.mkdir_p(@output_path) if !Dir.exists?(@output_path)

      tables.each do |table_name|
        create_model(table_name) if process?(table_name, include_prefixes)
      end
    end
    
    def create_model(table_name)
      File.open(File.join(output_path, "#{table_name}.rb"), "w") do |file|
        file.write generate_model_source(table_name)
      end
    end

    def process?(table_name, include_prefixes)
      include_prefixes.each do |prefix|
        return true if table_name =~ /^#{prefix}/
      end
      false
    end
    
    def generate_model_source(table_name)
      src = <<-EOS
class #{table_name.camelize} < ActiveRecord::Base
  set_table_name '#{table_name}'
end
EOS
    end
  end
end
