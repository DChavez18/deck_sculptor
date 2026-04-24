class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :decks, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :password, confirmation: true, allow_nil: true
  validate :password_or_google_uid_present

  def self.find_or_create_from_google(auth_hash)
    uid   = auth_hash.uid
    email = auth_hash.info.email.strip.downcase

    user = find_by(google_uid: uid)
    return user if user

    user = find_by(email_address: email)
    if user
      user.update!(google_uid: uid)
      return user
    end

    create!(email_address: email, google_uid: uid)
  end

  private

  def password_or_google_uid_present
    return if password_digest.present? || google_uid.present?
    errors.add(:base, "must have a password or sign in with Google")
  end
end
