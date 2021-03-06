require 'faraday'

class User < ActiveRecord::Base
  validates :username, :presence => true, :uniqueness => true
  validates :email, :presence => true

  has_many :runs
  has_many :friendships
  has_many :friends, :through => :friendships
  has_many :inverse_friendships, :class_name => "Friendship", :foreign_key => "friend_id"
  has_many :inverse_friends, :through => :inverse_friendships, :source => :user

  scope :except, proc {|user| where("id != ?", user.id)}

  def self.requestable_users(user)
    potential_friends = []
    where("id != ?", user.id).collect do |friend|
      if !user.total_approved_friends.include?(friend) && !user.total_pending_friends.include?(friend)
        potential_friends << friend
      end
    end
    potential_friends
  end

  def self.find_or_create_by_auth(user_data)
    where(:provider => user_data.provider, :uid => user_data.uid).first_or_create(
                                                                                  username: user_data.first_name + " " + user_data.last_name,
                                                                                  email: user_data.email,
                                                                                  token: user_data.token
                                                                                  )
  end

  def add_friend(friend)
    unless total_approved_friends.include?(friend)
      create_or_update_friendship(friend)
    end
  end

  def approve_friend(friend)
    friendship = Friendship.find_by(user_id: friend.id, friend_id: id) ||
                 Friendship.find_by(user_id: id, friend_id: friend.id)
    friendship.update(status: "approved")
  end

  def create_or_update_friendship(friend)
    Friendship.create(user_id: id, friend_id: friend.id, status: "pending")
    User.send_friend_request_email(friend.email, self.username)
  end

  def self.invite_new_friend_email(email, username)
    link = "http://runline.tk"
    FriendRequestNotifier.invite_new_friend(email, username, link).deliver
  end

  def self.send_friend_request_email(email, username)
    link = "http://runline.tk"
    FriendRequestNotifier.request_friend(email, username, link).deliver
  end

  def total_average_mile_pace
    RunStatCalculator.total_average_mile_pace_for(self)
  end

  def compare_total_average_mile_pace_with(friend)
    RunStatCalculator.compare_total_average_mile_pace_for(self, friend)
  end

  def pace
    RunStatCalculator.pace_for(self)
  end

  def total_distance_in_miles
    RunStatCalculator.total_distance_in_miles_for(self)
  end

  def fastest_run
    RunStatCalculator.fastest_run_for(self)
  end

  def fastest_mile_pace
    RunStatCalculator.fastest_mile_pace_for(self)
  end

  def longest_run
    RunStatCalculator.longest_run_for(self)
  end

  def total_pending_friends
    total = pending_friends << pending_inverse_friends
    total.flatten
  end

  def total_approved_friends
    total = approved_friends << approved_inverse_friends
    total.flatten
  end

  def approved_friends
    approved_friendships.where(user_id: id).collect do |friendship|
      friendship.friend
    end
  end

  def approved_inverse_friends
    approved_inverse_friendships.where(friend_id: id).collect do |friendship|
      friendship.user
    end
  end

  def total_approved_friendships
    total = approved_friendships << approved_inverse_friendships
    total.flatten
  end

  def approved_friendships
    friendships.where(status: "approved")
  end

  def approved_inverse_friendships
    inverse_friendships.where(status: "approved")
  end

  def pending_friends
    pending_friendships.where(user_id: id).collect do |friendship|
      friendship.friend
    end
  end

  def pending_inverse_friends
    pending_inverse_friendships.where(friend_id: id).collect do |friendship|
      friendship.user
    end
  end

  def total_pending_friendships
    total = pending_friendships << pending_inverse_friendships
    total.flatten
  end

  def pending_friendships
    friendships.where(status: "pending")
  end

  def pending_inverse_friendships
    inverse_friendships.where(status: "pending")
  end

end
