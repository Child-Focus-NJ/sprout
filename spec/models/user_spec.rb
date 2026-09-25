require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'role' do
    it 'defaults new users to the non-admin "user" role, not admin' do
      user = User.create!(email: "newhire@passaiccountycasa.org")

      expect(user.role).to eq("user")
      expect(user).not_to be_admin
    end
  end

  describe '.normalize_email' do
    it 'strips whitespace and downcases' do
      expect(User.normalize_email(" Admin@PassaicCountyCASA.org ")).to eq("admin@passaiccountycasa.org")
    end

    it 'returns nil for blank input' do
      expect(User.normalize_email(nil)).to be_nil
      expect(User.normalize_email("")).to be_nil
    end
  end

  describe 'clearing google_uid when email changes' do
    it 'clears google_uid when the email is edited' do
      user = User.create!(email: "old@passaiccountycasa.org", google_uid: "google-uid-123")

      user.update!(email: "new@passaiccountycasa.org")

      expect(user.google_uid).to be_nil
    end

    it 'leaves google_uid alone when other attributes change' do
      user = User.create!(email: "admin@passaiccountycasa.org", google_uid: "google-uid-123")

      user.update!(first_name: "Jane")

      expect(user.google_uid).to eq("google-uid-123")
    end

    it 'no longer signs in with the old Google account after the email changes' do
      user = User.create!(email: "old@passaiccountycasa.org", google_uid: "google-uid-123")
      user.update!(email: "new@passaiccountycasa.org")

      auth = OmniAuth::AuthHash.new({
        uid: "google-uid-123",
        info: { email: "old@passaiccountycasa.org", first_name: "Jane", last_name: "Doe", name: "Jane Doe" }
      })

      expect(User.from_omniauth(auth)).to be_nil
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

    context 'when no whitelisted user matches the email' do
      it 'does not create a user' do
        expect { User.from_omniauth(auth) }.not_to change(User, :count)
      end

      it 'returns nil' do
        expect(User.from_omniauth(auth)).to be_nil
      end
    end

    context 'when a whitelisted user exists' do
      before do
        User.create!(email: "admin@passaiccountycasa.org", role: :user)
      end

      it 'does not create a new user' do
        expect { User.from_omniauth(auth) }.not_to change(User, :count)
      end

      it 'links the Google account without changing their role' do
        user = User.from_omniauth(auth)
        expect(user.role).to eq("user")
        expect(user.google_uid).to eq("google-uid-123")
      end

      it 'fills in their profile from Google' do
        user = User.from_omniauth(auth)
        expect(user.first_name).to eq("Jane")
        expect(user.last_name).to eq("Doe")
        expect(user.avatar_url).to eq("https://example.com/photo.jpg")
      end

      it 'matches regardless of email casing or whitespace in the Google response' do
        mixed_case_auth = OmniAuth::AuthHash.new({
          uid: "google-uid-999",
          info: {
            email: " Admin@PassaicCountyCASA.org ",
            first_name: "Jane",
            last_name: "Doe",
            name: "Jane Doe",
            image: nil
          }
        })

        expect { User.from_omniauth(mixed_case_auth) }.not_to change(User, :count)
      end

      it 'still matches by google_uid if the email Google reports later changes' do
        User.from_omniauth(auth)
        renamed_auth = OmniAuth::AuthHash.new({
          uid: "google-uid-123",
          info: {
            email: "renamed@passaiccountycasa.org",
            first_name: "Jane",
            last_name: "Doe",
            name: "Jane Doe",
            image: nil
          }
        })

        user = User.from_omniauth(renamed_auth)
        expect(user.email).to eq("admin@passaiccountycasa.org")
      end

      it 'links Google to an existing staff record with the same email' do
        existing = User.create!(
          email: "izzy@nyu.edu",
          first_name: "Staff",
          last_name: "Member"
        )
        auth_for_existing = OmniAuth::AuthHash.new({
          uid: "google-uid-existing",
          info: {
            email: "izzy@nyu.edu",
            first_name: "Izzy",
            last_name: "Member",
            name: "Izzy Member",
            image: nil
          }
        })

        expect { User.from_omniauth(auth_for_existing) }.not_to change(User, :count)
        expect(existing.reload.google_uid).to eq("google-uid-existing")
        expect(existing.first_name).to eq("Izzy")
      end

      it 'updates their info on subsequent logins' do
        User.from_omniauth(auth)
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

      before do
        User.create!(email: "admin@passaiccountycasa.org", role: :user)
      end

      it 'falls back to splitting the full name' do
        user = User.from_omniauth(auth_no_names)
        expect(user.first_name).to eq("Jane")
        expect(user.last_name).to eq("Doe")
      end
    end
  end
end
