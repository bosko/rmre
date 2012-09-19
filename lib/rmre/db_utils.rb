module Rmre
  module DbUtils
    COLUMN_CONVERSIONS = {
      "Mysql2" => {
        :raw => :binary
      }
    }

    def self.convert_column_type(target_adapter_name, start_type)
      if COLUMN_CONVERSIONS[target_adapter_name] &&
         COLUMN_CONVERSIONS[target_adapter_name][start_type]
        return COLUMN_CONVERSIONS[target_adapter_name][start_type]
      end
      return start_type
    end
  end
end
