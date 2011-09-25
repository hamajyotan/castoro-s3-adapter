
class S3Object < ActiveRecord::Base

  include S3Adapter::Acl

  def get_object? access_key_id
    readable? access_key_id
  end

  def get_object_acl? access_key_id
    acp_readable? access_key_id
  end

  def put_object_acl? access_key_id
    acp_writable? access_key_id
  end

  def get_owner? access_key_id
    acp_readable? access_key_id
  end

  before_save :serialize_object

  def to_basket
    Castoro::BasketKey.new id, basket_type, basket_rev
  end

  accessors = [
    :last_modified,
    :etag,
    :size,
    :content_type,
    :expires,
    :content_encoding,
    :content_disposition,
    :cache_control,
    :owner_access_key,
    :acl,
    :meta,
  ]

  accessors.each { |m|
    define_method(m) {
      metadata[m.to_s]
    }
    define_method("#{m}=") { |v|
      metadata[m.to_s] = v
    }
  }

  private

  def metadata
    @obj ||= JSON.parse(object.to_s.empty? ? "{}" : object)
  end

  def serialize_object
    self.object = metadata.to_json
  end

  named_scope :active, :conditions => { :deleted => false }
  named_scope :inactive, :conditions => { :deleted => true }

  def get_acl
    (self.acl || {})
  end

  def get_acl_owner
    self.owner_access_key
  end

end

