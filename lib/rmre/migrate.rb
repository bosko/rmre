require "rmre/db_utils"
require "rmre/dynamic_db"
require "contrib/progressbar"

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
    RAILS_COPY_MODE = 1
    LEGACY_COPY_MODE = 2
    @copy_mode = RAILS_COPY_MODE

    def self.prepare(source_db_options, target_db_options, mode = Rmre::Migrate::RAILS_COPY_MODE)
      @copy_mode = mode

      Rmre::Source.connection_options = source_db_options
      Rmre::Target.connection_options = target_db_options
      Rmre::Source::Db.establish_connection(Rmre::Source.connection_options)
      Rmre::Target::Db.establish_connection(Rmre::Target.connection_options)
    end

    def self.copy
      tables_count = Rmre::Source::Db.connection.tables.length
      Rmre::Source::Db.connection.tables.each_with_index do |table, idx|
        puts "Copying table #{table} (#{idx + 1}/#{tables_count})..."
        copy_table(table)
      end
    end

    def self.copy_table(table)
      unless Rmre::Target::Db.connection.table_exists?(table)
        create_table(table, Rmre::Source::Db.connection.columns(table))
      end
      copy_data(table)
    end

    def self.create_table(table, source_columns)
      Rmre::Target::Db.connection.create_table(table)
      source_columns.reject {|col| col.name.downcase == 'id' && @copy_mode == RAILS_COPY_MODE }.each do |sc|
        options = {
          :null => sc.null,
          :default => sc.default
        }

        col_type = Rmre::DbUtils.convert_column_type(Rmre::Target::Db.connection.adapter_name, sc.type)
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

        Rmre::Target::Db.connection.add_column(table, sc.name, col_type, options)
      end
    end

    def self.table_has_type_column(table)
      Rmre::Source::Db.connection.columns(table).find {|col| col.name == 'type'}
    end

    def self.copy_data(table_name)
      src_model = Rmre::Source.create_model_for(table_name)
      src_model.inheritance_column = 'ruby_type' if table_has_type_column(table_name)
      tgt_model = Rmre::Target.create_model_for(table_name)

      rec_count = src_model.count
      progress_bar = Console::ProgressBar.new(table_name, rec_count)
      src_model.all.each do |src_rec|
        tgt_model.create!(src_rec.attributes)
        progress_bar.inc
      end
    end
  end
end
