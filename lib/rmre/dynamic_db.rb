require 'active_record'

module Rmre
  module DynamicDb
    def self.included(base)
      base.send :extend, Rmre::DynamicDb
    end

    def connection_options
      @connection_options
    end

    def connection_options= v
      @connection_options = v
    end

    def create_model_for(table_name, primary_key_name)
      model_name = table_name.classify
      module_eval <<-ruby_src, __FILE__, __LINE__ + 1
        class #{model_name} < Db
          self.table_name = '#{table_name}'
          establish_connection(#{connection_options})
        end
      ruby_src
      klass = const_get model_name
      klass.primary_key = primary_key_name if primary_key_name && primary_key_name != 'id'
      klass
    end
  end
end
