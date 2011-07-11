
class S3Object < ActiveRecord::Base

  def to_basket
    Castoro::BasketKey.new basket_id, basket_type, basket_rev
  end

  def next_basket_id type
    (S3Object.maximum(:basket_id, :conditions => {:basket_type => type} ) || 0) + 1
  end

end

