class User < ActiveRecord::Base
  validates :username, :presence => true
  validates :email, :presence => true

  def self.find_or_create_by_auth(auth)
    find_or_create_by_provider_and_uid(auth["provider"], 
                                       auth["uid"],
                                       username: auth["info"]["name"],
                                       email: auth["info"]["email"])
  end
end
