require "rmre/dynamic_db"

# conf = YAML.load_file('rmre_db.yml')
# Rmre::Migrate.prepare(conf[:db_source], conf[:db_target])
# tables = Rmre::Migrate::Source::Db.connection.tables
# tables.each {|tbl| Rmre::Migrate.copy_table(tbl)}
module Rmre
  module Source
    include DynamicDb

    class Db < ActiveRecord::Base
    end
  end

  module Target
    include DynamicDb

    class Db < ActiveRecord::Base
    end
  end

  module Migrate
    def self.prepare(source_db_options, target_db_options)
      Source.connection_options = source_db_options
      Target.connection_options = target_db_options
      Source::Db.establish_connection(Source.connection_options)
      Target::Db.establish_connection(Target.connection_options)
    end

    def self.copy_table(table)
      unless Target::Db.connection.table_exists?(table)
        puts "Copying structure for #{table}..."
        create_table(table, Source::Db.connection.columns(table))
        copy_data(table)
      end
    end

    def self.create_table(table, source_columns)
      Target::Db.connection.create_table(table)
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

        Target::Db.connection.add_column(table, sc.name, col_type, options)
      end
    end

    def self.copy_data(table_name)
    end
  end
end
