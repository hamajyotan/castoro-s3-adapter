
class S3Object < ActiveRecord::Base

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

end

