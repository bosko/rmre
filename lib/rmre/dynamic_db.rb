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

    def create_model_for(table_name)
      module_eval <<-ruby_src, __FILE__, __LINE__ + 1
        class #{table_name.classify} < ActiveRecord::Base
          self.table_name = '#{table_name}'
          establish_connection(#{connection_options})
        end
        ruby_src
    end
  end
end
