require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_many(:sessions).dependent(:destroy) }
    it { should have_many(:decks).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:email_address) }
    it { should validate_uniqueness_of(:email_address).case_insensitive }

    it "is valid with email and password" do
      expect(build(:user)).to be_valid
    end

    it "is valid with email and google_uid and no password" do
      expect(build(:google_user)).to be_valid
    end

    it "is invalid with neither password_digest nor google_uid" do
      user = build(:user, password: nil, google_uid: nil)
      user.password_digest = nil
      expect(user).not_to be_valid
      expect(user.errors[:base]).to include("must have a password or sign in with Google")
    end
  end

  describe ".find_or_create_from_google" do
    let(:auth_hash) do
      OmniAuth::AuthHash.new(
        uid: "google-uid-123",
        info: OmniAuth::AuthHash::InfoHash.new(email: "test@example.com")
      )
    end

    context "when user exists with matching google_uid" do
      it "returns the existing user" do
        existing = create(:google_user, google_uid: "google-uid-123",
                          email_address: "test@example.com")
        result = User.find_or_create_from_google(auth_hash)
        expect(result).to eq(existing)
      end
    end

    context "when user exists with matching email but no google_uid" do
      it "backfills google_uid and returns the user" do
        existing = create(:user, email_address: "test@example.com", google_uid: nil)
        result = User.find_or_create_from_google(auth_hash)
        expect(result).to eq(existing)
        expect(existing.reload.google_uid).to eq("google-uid-123")
      end
    end

    context "when no matching user exists" do
      it "creates a new user with google_uid" do
        expect {
          User.find_or_create_from_google(auth_hash)
        }.to change(User, :count).by(1)

        user = User.find_by(google_uid: "google-uid-123")
        expect(user.email_address).to eq("test@example.com")
        expect(user.password_digest).to be_nil
      end
    end
  end
end
