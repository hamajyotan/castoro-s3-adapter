
module S3Adapter::Acl
  class Bucket

    include S3Adapter::Acl

    def initialize bucket
      bs     = S3CONFIG['buckets'] || {}
      b      = bs[bucket]          || {}
      @acl   = b['acl']            || {}
      @owner = b['owner']
    end

    def get_bucket? access_key_id
      readable? access_key_id
    end

    def put_object? access_key_id
      writable? access_key_id
    end

    def put_object_copy? access_key_id
      writable? access_key_id
    end

    def delete_object? access_key_id
      writable? access_key_id
    end

    def get_bucket_acl? access_key_id
      acp_readable? access_key_id
    end

    def put_bucket_acl? access_key_id
      acp_writable? access_key_id
    end

    private

    def get_acl; @acl; end
    def get_acl_owner; @owner; end
  end
end

