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
      return if @connection_options.empty?
      
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
        constraints = []
        foreign_keys.each do |fk|
          src = constraint_src(table_name, fk)
          constraints << src unless src.nil?
        end
        
        file.write generate_model_source(table_name, constraints)
      end
    end

    def process?(table_name, include_prefixes)
      return true if include_prefixes.empty?
      
      include_prefixes.each do |prefix|
        return true if table_name =~ /^#{prefix}/
      end

      false
    end

    def foreign_keys
      @foreign_keys ||= fetch_foreign_keys
    end

    private
    def fetch_foreign_keys
      fk = []
      case @connection_options[:adapter]
      when 'mysql'
        fk = connection.select_all(mysql_fk_sql)
      end
    end

    def constraint_src(table_name, fk={})
      src = nil
      if fk['from_table'] == table_name
        src = "belongs_to :#{fk['to_table']}, :class_name => '#{fk['to_table'].classify}', :foreign_key => :#{fk['from_column']}"
      elsif fk['to_table'] == table_name
        src = "has_many :#{fk['from_table'].pluralize}, :class_name => '#{fk['from_table'].classify}'"
      end
      src
    end
    
    def generate_model_source(table_name, constraints)
      src = "class #{table_name.classify} < ActiveRecord::Base\n"
      primary_key = connection.primary_key(table_name)
      src << "  set_primary_key :#{primary_key}\n" unless "id" == primary_key || primary_key.nil?
      src << "  set_table_name '#{table_name}'\n" unless table_name == table_name.classify.tableize
      src << "  #{constraints.join("\n  ")}"
      src << "\nend\n"
    end

    def mysql_fk_sql
      sql = <<-SQL
select
 table_name as from_table,
 column_name as from_column,
 referenced_table_name as to_table,
 referenced_column_name as to_column
from information_schema.KEY_COLUMN_USAGE
where referenced_table_schema like '%'
 and referenced_table_name is not null
SQL
    end
  end
end
