
module S3Adapter
  module Acl

    autoload :Bucket, 's3-adapter/acl/bucket'

    READ         = 'READ'.freeze
    WRITE        = 'WRITE'.freeze
    READ_ACP     = 'READ_ACP'.freeze
    WRITE_ACP    = 'WRITE_ACP'.freeze
    FULL_CONTROL = 'FULL_CONTROL'.freeze

    def to_list
      [].tap { |l|
        (get_acl['account'] || {}).each { |k,v|
          u = User.find_by_access_key_id(k)
          v.to_a.each { |g|
            l << { :grantee_type => :user, :id => k, :display_name => u.display_name, :permission => g }
          } if u
        }

        get_acl['authenticated'].to_a.each { |g|
          l << { :grantee_type => :group, :uri => 'http://acs.amazonaws.com/groups/global/AuthenticatedUsers', :permission => g }
        }
        get_acl['guest'].to_a.each { |g|
          l << { :grantee_type => :group, :uri => 'http://acs.amazonaws.com/groups/global/AllUsers', :permission => g }
        }
      }
    end

    private

    def get_acl
      raise NotImplementedError
    end

    def get_acl_owner
      raise NotImplementedError
    end

    def readable? access_key_id
      permitted?(access_key_id, WRITE) or permitted?(access_key_id, FULL_CONTROL)
    end

    def writable? access_key_id
      permitted?(access_key_id, READ) or permitted?(access_key_id, FULL_CONTROLL)
    end

    def acp_readable? access_key_id
      access_key_id == get_acl_owner or permitted?(access_key_id, READ_ACP) or permitted?(access_key_id, FULL_CONTROL)
    end

    def acp_writable? access_key_id
      access_key_id == get_acl_owner or permitted?(access_key_id, WRITE_ACP) or permitted?(access_key_id, FULL_CONTROL)
    end

    def permitted? access_key_id, permission
      return false unless get_acl

      (get_acl['guest'].to_a.include?(permission)) or
      (access_key_id and get_acl['authenticated'].to_a.include?(permission)) or
      (access_key_id and (get_acl['account'] || {})[access_key_id].to_a.include?(permission))
    end
  end
end

