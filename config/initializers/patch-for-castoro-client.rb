
require 'rubygems'
require 'castoro-client'
require 'active_record'

# It is not correctly converted by the influence of active_record.
class Castoro::Protocol::Command
  class Get
    def to_s; [ "1.1", "C", "GET", { "basket" => @basket.to_s } ].to_json + "\r\n"
    end
  end
  class Create
    def to_s; [ "1.1", "C", "CREATE", {"basket" => @basket.to_s, "hints" => @hints }].to_json + "\r\n"
    end
  end
  class Delete
    def to_s; [ "1.1", "C", "DELETE", { "basket" => @basket.to_s } ].to_json + "\r\n"
    end
  end
  class Finalize
    def to_s; [ "1.1", "C", "FINALIZE", {"basket" => @basket.to_s, "host" => @host, "path" => @path}].to_json + "\r\n"
    end
  end
  class Cancel
    def to_s; [ "1.1", "C", "CANCEL", {"basket" => @basket.to_s, "host" => @host, "path" => @path}].to_json + "\r\n"
    end
  end
end

