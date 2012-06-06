require "tmpdir"
require "fileutils"
require "erubis"
require "rmre/active_record/schema_dumper"

module Rmre
  class Generator
    attr_reader :connection
    attr_reader :output_path

    SETTINGS_ROOT = File.expand_path('../../../../db', __FILE__)

    def initialize(options, out_path, include)
      @connection_options = options
      @connection = nil
      @output_path = out_path
      @include_prefixes = include
    end

    def connect
      return if @connection_options.empty?

      ActiveRecord::Base.establish_connection(@connection_options)
      @connection = ActiveRecord::Base.connection
    end

    def create_models(tables)
      return unless tables.is_a? Array

      FileUtils.mkdir_p(@output_path) if !Dir.exists?(@output_path)

      tables.each do |table_name|
        create_model(table_name) if process?(table_name)
      end
    end

    def dump_schema(stream)
      ActiveRecord::SchemaDumper.dump_with_fk(connection, foreign_keys, stream)
    end

    def create_model(table_name)
      File.open(File.join(output_path, "#{table_name.tableize.singularize}.rb"), "w") do |file|
        constraints = []

        foreign_keys.each do |fk|
          src = constraint_src(table_name, fk)
          constraints << src unless src.nil?
        end

        file.write generate_model_source(table_name, constraints)
      end
    end

    def process?(table_name)
      return true if @include_prefixes.nil? || @include_prefixes.empty?

      @include_prefixes.each do |prefix|
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
        fk = mysql_foreign_keys
      when 'postgresql'
        fk = psql_foreign_keys
      when 'sqlserver'
        fk = mssql_foreign_keys
      when 'oracle_enhanced'
        fk = oracle_foreign_keys
      end
      fk
    end

    def constraint_src(table_name, fk={})
      src = nil
      if fk['from_table'] == table_name
        src = "belongs_to :#{fk['to_table'].downcase.singularize}, :class_name => '#{fk['to_table'].tableize.classify}', :foreign_key => :#{fk['from_column']}"
      elsif fk['to_table'] == table_name
        src = "has_many :#{fk['from_table'].downcase.pluralize}, :class_name => '#{fk['from_table'].tableize.classify}'"
      end
      src
    end

    def generate_model_source(table_name, constraints)
      eruby = Erubis::Eruby.new(File.read(File.join(File.expand_path("../", __FILE__), 'model.eruby')))
      eruby.result(:table_name => table_name,
        :primary_key => connection.primary_key(table_name),
        :constraints => constraints,
        :has_type_column => connection.columns(table_name).find { |col| col.name == 'type' })
    end

    def mysql_foreign_keys
      sql = <<-SQL
select
 table_name as from_table,
 column_name as from_column,
 referenced_table_name as to_table,
 referenced_column_name as to_column
from information_schema.KEY_COLUMN_USAGE
where referenced_table_schema like '%'
 and constraint_schema = '#{@connection_options[:database]}'
 and referenced_table_name is not null
SQL
      connection.select_all(sql)
    end

    def psql_foreign_keys
      sql = <<-SQL
SELECT tc.table_name as from_table,
          kcu.column_name as from_column,
          ccu.table_name AS to_table,
          ccu.column_name AS to_column
     FROM information_schema.table_constraints tc
  LEFT JOIN information_schema.key_column_usage kcu
       ON tc.constraint_catalog = kcu.constraint_catalog
      AND tc.constraint_schema = kcu.constraint_schema
      AND tc.constraint_name = kcu.constraint_name

  LEFT JOIN information_schema.referential_constraints rc
       ON tc.constraint_catalog = rc.constraint_catalog
      AND tc.constraint_schema = rc.constraint_schema
      AND tc.constraint_name = rc.constraint_name
  LEFT JOIN information_schema.constraint_column_usage ccu
       ON rc.unique_constraint_catalog = ccu.constraint_catalog
      AND rc.unique_constraint_schema = ccu.constraint_schema
      AND rc.unique_constraint_name = ccu.constraint_name
    WHERE tc.table_name like '%'
    AND tc.constraint_type = 'FOREIGN KEY';
SQL
      connection.select_all(sql)
    end

    def mssql_foreign_keys
      sql = <<-SQL
SELECT C.TABLE_NAME [from_table],
       KCU.COLUMN_NAME [from_column],
       C2.TABLE_NAME [to_table],
       KCU2.COLUMN_NAME [to_column]
FROM   INFORMATION_SCHEMA.TABLE_CONSTRAINTS C
       INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE KCU
         ON C.CONSTRAINT_SCHEMA = KCU.CONSTRAINT_SCHEMA
            AND C.CONSTRAINT_NAME = KCU.CONSTRAINT_NAME
       INNER JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS RC
         ON C.CONSTRAINT_SCHEMA = RC.CONSTRAINT_SCHEMA
            AND C.CONSTRAINT_NAME = RC.CONSTRAINT_NAME
       INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS C2
         ON RC.UNIQUE_CONSTRAINT_SCHEMA = C2.CONSTRAINT_SCHEMA
            AND RC.UNIQUE_CONSTRAINT_NAME = C2.CONSTRAINT_NAME
       INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE KCU2
         ON C2.CONSTRAINT_SCHEMA = KCU2.CONSTRAINT_SCHEMA
            AND C2.CONSTRAINT_NAME = KCU2.CONSTRAINT_NAME
            AND KCU.ORDINAL_POSITION = KCU2.ORDINAL_POSITION
    WHERE  C.CONSTRAINT_TYPE = 'FOREIGN KEY'
SQL
      connection.select_all(sql)
    end

    def oracle_foreign_keys
      fk = []
      connection.tables.each do |table|
        connection.foreign_keys(table).each do |oracle_fk|
          table_fk = { 'from_table' => oracle_fk.from_table,
            'from_column' => oracle_fk.options[:columns][0],
            'to_table' => oracle_fk.to_table,
            'to_column' => oracle_fk.options[:references][0] }
          fk << table_fk
        end
      end
      fk
    end
  end
end
