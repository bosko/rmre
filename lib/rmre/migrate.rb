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
        create_table(table, SourceDb.connection.columns(table))
      end
      puts "  Copying data..."
    end

    def self.create_table(table, source_columns)
      puts "  Creating table #{table}"
      TargetDb.connection.create_table(table)
      source_columns.each do |sc|
        options = {
          :null => sc.null,
          :default => sc.default
        }

        col_type = Rmre::DbUtils.convert_column_type(Rmre::Migrate::TargetDb.connection.adapter_name, sc.type)
        case col_type
        when :decimal
          options.merge!({
              :limit => sc.limit,
              :precision => sc.precision,
              :scale => sc.scale,
            })
        when :string
          options.merge!({
              :limit => sc.limit
            })
        end

        TargetDb.connection.add_column(table, sc.name, col_type, options)
      end
    end
  end
end
