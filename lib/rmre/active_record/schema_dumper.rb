require "active_record"
require "active_record/base"
require "active_record/schema_dumper"

module ActiveRecord
  class SchemaDumper
    def self.dump_with_fk(connection=ActiveRecord::Base.connection, foreign_keys=[], stream=STDOUT)
      new(connection).dump_with_fk(foreign_keys, stream)
      stream
    end

    def dump_with_fk(foreign_keys, stream)
      header(stream)
      tables(stream)

      foreign_keys.each do |fk|
stream.puts <<-SQL
  execute "ALTER TABLE #{fk['from_table']} ADD CONSTRAINT fk_#{fk['from_table']}_#{fk['to_table']}
           FOREIGN KEY (#{fk['from_column']}) REFERENCES #{fk['to_table']}(#{fk['to_column']})"
    SQL
      end

      trailer(stream)
      stream
    end

    def self.dump_table(table_name, connection = ActiveRecord::Base.connection, stream=STDOUT)
      new(connection).dump_table(table_name, stream)
    end

    def dump_table(table_name, stream)
      table(table_name, stream)
    end
  end
end
