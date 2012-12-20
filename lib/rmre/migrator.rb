require "rmre/db_utils"
require "rmre/dynamic_db"
require "contrib/progressbar"

module Rmre
  module Source
    include DynamicDb

    class Db < ActiveRecord::Base
      self.abstract_class = true
    end
  end

  module Target
    include DynamicDb

    class Db < ActiveRecord::Base
      self.abstract_class = true
    end
  end

  class Migrator
    def initialize(source_db_options, target_db_options, options = {})
      # If set to true will call AR create_table with force (table will be dropped if exists)
      @force_table_create = false
      @rails_copy_mode = options[:rails_copy_mode]
      @skip_existing_tables = options[:skip_existing]
      @verbose = options[:verbose]

      Rmre::Source.connection_options = source_db_options
      Rmre::Target.connection_options = target_db_options
      Rmre::Source::Db.establish_connection(Rmre::Source.connection_options)
      Rmre::Target::Db.establish_connection(Rmre::Target.connection_options)
    end

    # Before we start copying we call block if it is given so some additional options
    # can be set. For example MS SQL adapter has option to use lowercase names for
    # all entities. We can set this options in a following way:
    #
    # mig = Migrator.new(..)
    # mig.copy(true) do
    #   ActiveRecord::ConnectionAdapters::SQLServerAdapter.lowercase_schema_reflection = true
    # end
    def copy(force = false)
      yield if block_given?

      @force_table_create = force
      tables_count = Rmre::Source::Db.connection.tables.length
      Rmre::Source::Db.connection.tables.sort.each_with_index do |table, idx|
        info "Copying table #{table} (#{idx + 1}/#{tables_count})..."
        copy_table(table)
      end
    end

    def copy_table(table)
      if @skip_existing_tables && Rmre::Target::Db.connection.table_exists?(table)
        info "Skipping"
        return
      end

      if !Rmre::Target::Db.connection.table_exists?(table) || @force_table_create
        create_table(table, Rmre::Source::Db.connection.columns(table))
      end
      copy_data(table)
    end

    def create_table(table, source_columns)
      opts = {:id => @rails_copy_mode, :force => @force_table_create}
      Rmre::Target::Db.connection.create_table(table, opts) do |t|
        source_columns.reject {|col| col.name.downcase == 'id' && @rails_copy_mode }.each do |sc|
          options = {
            :null => sc.null,
            :default => sc.default
          }

          # Some adapters do not convert all types to Rails value. Example is oracle_enhanced adapter
          # which for 'LONG' column type sets column's type to nil but keeps sql_type as 'LONG'.
          # Therefore we will use one of these values so we can, in DbUtils, handle all possible
          # column type mappings when we are migrating from one DB to anohter (Oracle -> MySQL,
          # MS SQL -> PostgreSQL, etc).
          source_type = sc.type.nil? ? sc.sql_type : sc.type
          col_type = Rmre::DbUtils.convert_column_type(Rmre::Target::Db.connection.adapter_name, source_type)
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

          t.column(sc.name, col_type, options)
        end
      end
    end

    def table_has_type_column(table)
      Rmre::Source::Db.connection.columns(table).find {|col| col.name == 'type'}
    end

    def copy_data(table_name)
      src_model = Rmre::Source.create_model_for(table_name)
      src_model.inheritance_column = 'ruby_type' if table_has_type_column(table_name)
      tgt_model = Rmre::Target.create_model_for(table_name)

      rec_count = src_model.count
      copy_options = {}
      # If we are copying legacy databases or table has column 'type'
      # we must skip protection because ActiveRecord::AttributeAssignment::assign_attributes
      # will skip it and later value for that column will be set to nil. Similar thing
      # will happend for 'id' column if we are not in Rails copy mode
      copy_options[:without_protection] = (!@rails_copy_mode || table_has_type_column(table_name))
      progress_bar = Console::ProgressBar.new(table_name, rec_count) if @verbose
      src_model.all.each do |src_rec|
        tgt_model.create!(src_rec.attributes, copy_options)
        progress_bar.inc if @verbose
      end
    end

    private

    def info(msg)
      puts msg if @verbose
    end
  end
end
