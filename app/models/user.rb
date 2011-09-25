
class User < ActiveRecord::Base

  ANONYMOUS_ID = '65a011a29cdf8ec533ec3d1ccaae921c'.freeze

  validates_presence_of   :access_key_id
  validates_length_of     :access_key_id, :maximum => 20, :allow_nil => true
  validates_format_of     :access_key_id, :with => /^[0-9A-Za-z]*$/
  validates_uniqueness_of :access_key_id

  validates_presence_of   :secret_access_key
  validates_length_of     :secret_access_key, :maximum => 40, :allow_nil => true
  validates_format_of     :secret_access_key, :with => /^[0-9A-Za-z]*$/

  validates_presence_of   :display_name
  validates_length_of     :display_name, :maximum => 20, :allow_nil => true
  validates_uniqueness_of :display_name

  def after_initialize
    return unless new_record?
    self.access_key_id     ||= random_string(20)
    self.secret_access_key ||= random_string(40)
    self.display_name      ||= random_string(20)
  end

  private

  def random_string size
    candidates = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    Array.new(size) { candidates[rand(candidates.size)] }.join
  end

end

