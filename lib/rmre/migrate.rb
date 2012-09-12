require "rmre/active_record/schema_dumper"

module Rmre
  module Migrate
    def self.prepare(source_db_options, target_db_options)
      require 'active_record'

      ActiveRecord::Base.configurations['db_source'] = source_db_options
      ActiveRecord::Base.configurations['db_target'] = target_db_options
      eval <<-EOS, nil, __FILE__, __LINE__
class TargetDb < ActiveRecord::Base
  establish_connection('db_target')
end

class SourceDb < ActiveRecord::Base
  establish_connection('db_source')
end
EOS
    end

    def self.copy_table(table)
      puts "Copying table #{table}"
      unless TargetDb.connection.table_exists?(table)
        create_table(table)
      end
      puts "  Copying data..."
    end

    def self.create_table(table)
      puts "  Creating table"
      create_table_stream = StringIO.new
      ActiveRecord::SchemaDumper.dump_table(table, SourceDb.connection, create_table_stream)
      TargetDb.connection.send(:eval, create_table_stream.string)
    end
  end
end
