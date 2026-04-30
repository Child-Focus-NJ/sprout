require 'rails_helper'

RSpec.describe User, type: :model do
  describe '.allowed_email?' do
    it 'returns true for passaiccountycasa.org emails' do
      expect(User.allowed_email?("admin@passaiccountycasa.org")).to be true
    end

    it 'returns true for nyu.edu emails' do
      expect(User.allowed_email?("izzy@nyu.edu")).to be true
    end

    it 'returns false for gmail.com emails' do
      expect(User.allowed_email?("someone@gmail.com")).to be false
    end

    it 'returns false for nil' do
      expect(User.allowed_email?(nil)).to be false
    end
  end

  describe '.from_omniauth' do
    let(:auth) do
      OmniAuth::AuthHash.new({
        uid: "google-uid-123",
        info: {
          email: "admin@passaiccountycasa.org",
          first_name: "Jane",
          last_name: "Doe",
          name: "Jane Doe",
          image: "https://example.com/photo.jpg"
        }
      })
    end

    context 'when user does not exist' do
      it 'creates a new user' do
        expect { User.from_omniauth(auth) }.to change(User, :count).by(1)
      end

      it 'sets the correct attributes' do
        user = User.from_omniauth(auth)
        expect(user.email).to eq("admin@passaiccountycasa.org")
        expect(user.first_name).to eq("Jane")
        expect(user.last_name).to eq("Doe")
        expect(user.google_uid).to eq("google-uid-123")
        expect(user.avatar_url).to eq("https://example.com/photo.jpg")
      end
    end

    context 'when user already exists' do
      before { User.from_omniauth(auth) }

      it 'does not create a new user' do
        expect { User.from_omniauth(auth) }.not_to change(User, :count)
      end

      it 'updates their info' do
        updated_auth = OmniAuth::AuthHash.new({
          uid: "google-uid-123",
          info: {
            email: "admin@passaiccountycasa.org",
            first_name: "Janet",
            last_name: "Doe",
            name: "Janet Doe",
            image: "https://example.com/new_photo.jpg"
          }
        })
        user = User.from_omniauth(updated_auth)
        expect(user.first_name).to eq("Janet")
        expect(user.avatar_url).to eq("https://example.com/new_photo.jpg")
      end
    end

    context 'when auth is missing first/last name' do
      let(:auth_no_names) do
        OmniAuth::AuthHash.new({
          uid: "google-uid-456",
          info: {
            email: "admin@passaiccountycasa.org",
            first_name: nil,
            last_name: nil,
            name: "Jane Doe",
            image: nil
          }
        })
      end

      it 'falls back to splitting the full name' do
        user = User.from_omniauth(auth_no_names)
        expect(user.first_name).to eq("Jane")
        expect(user.last_name).to eq("Doe")
      end
    end
  end
end