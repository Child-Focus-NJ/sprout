require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'role' do
    it 'defaults new users to the non-admin "user" role, not admin' do
      user = User.create!(email: "newhire@passaiccountycasa.org")

      expect(user.role).to eq("user")
      expect(user).not_to be_admin
    end
  end

  describe 'deactivation' do
    it 'can be deactivated while another admin is still active' do
      create(:user, role: :admin)
      sole_target = create(:user, role: :admin)

      expect(sole_target.update(active: false)).to be true
      expect(sole_target.reload).not_to be_active
    end

    it 'is unaffected by deactivating a regular user' do
      user = create(:user)

      expect(user.update(active: false)).to be true
    end
  end

  describe 'preventing the last admin from being removed' do
    it 'blocks deactivating the only active admin' do
      admin = create(:user, role: :admin)

      expect(admin.update(active: false)).to be false
      expect(admin.errors[:base]).to include("Cannot remove the last admin.")
      expect(admin.reload).to be_active
    end

    it 'blocks demoting the only active admin to user' do
      admin = create(:user, role: :admin)

      expect(admin.update(role: :user)).to be false
      expect(admin.reload).to be_admin
    end

    it 'allows deactivating an admin when another active admin remains' do
      create(:user, role: :admin)
      admin = create(:user, role: :admin)

      expect(admin.update(active: false)).to be true
    end

    it 'allows demoting an admin when another active admin remains' do
      create(:user, role: :admin)
      admin = create(:user, role: :admin)

      expect(admin.update(role: :user)).to be true
    end

    it 'is not tripped by an already-inactive admin being edited' do
      inactive_admin = create(:user, role: :admin, active: false)

      expect(inactive_admin.update(first_name: "Renamed")).to be true
    end

    it 'does not block unrelated changes to the only active admin' do
      admin = create(:user, role: :admin)

      expect(admin.update(first_name: "Renamed")).to be true
    end
  end

  describe '.allow_all_domains?' do
    after { ENV.delete("ALLOW_ALL_DOMAINS") }

    it 'defaults to true when ALLOW_ALL_DOMAINS is unset' do
      expect(User.allow_all_domains?).to be true
    end

    it 'is false when ALLOW_ALL_DOMAINS is set to "false"' do
      ENV["ALLOW_ALL_DOMAINS"] = "false"

      expect(User.allow_all_domains?).to be false
    end
  end

  describe '.domain_allowed?' do
    it 'returns true for passaiccountycasa.org emails' do
      expect(User.domain_allowed?("admin@passaiccountycasa.org")).to be true
    end

    it 'returns true for nyu.edu emails' do
      expect(User.domain_allowed?("izzy@nyu.edu")).to be true
    end

    it 'returns false for gmail.com emails' do
      expect(User.domain_allowed?("someone@gmail.com")).to be false
    end

    it 'returns false for nil' do
      expect(User.domain_allowed?(nil)).to be false
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

    context 'with ALLOW_ALL_DOMAINS at its default (true)' do
      context 'when no user exists yet' do
        it 'creates a new user on an allowed domain' do
          expect { User.from_omniauth(auth) }.to change(User, :count).by(1)
        end

        it 'signs the new user up with the non-admin "user" role by default' do
          user = User.from_omniauth(auth)
          expect(user).not_to be_admin
          expect(user.role).to eq("user")
        end

        it 'does not create a user on a non-allowed domain' do
          non_domain_auth = OmniAuth::AuthHash.new({
            uid: "google-uid-999",
            info: { email: "someone@gmail.com", first_name: "Jane", last_name: "Doe", name: "Jane Doe" }
          })

          expect { User.from_omniauth(non_domain_auth) }.not_to change(User, :count)
          expect(User.from_omniauth(non_domain_auth)).to be_nil
        end
      end
    end

    context 'with ALLOW_ALL_DOMAINS set to false' do
      before { ENV["ALLOW_ALL_DOMAINS"] = "false" }
      after { ENV.delete("ALLOW_ALL_DOMAINS") }

      it 'does not auto-create a user, even on an allowed domain' do
        expect { User.from_omniauth(auth) }.not_to change(User, :count)
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

    it 'no longer signs in with the old Google account after the email changes, under a strict whitelist' do
      ENV["ALLOW_ALL_DOMAINS"] = "false"
      user = User.create!(email: "old@passaiccountycasa.org", google_uid: "google-uid-123")
      user.update!(email: "new@passaiccountycasa.org")

      auth = OmniAuth::AuthHash.new({
        uid: "google-uid-123",
        info: { email: "old@passaiccountycasa.org", first_name: "Jane", last_name: "Doe", name: "Jane Doe" }
      })

      expect(User.from_omniauth(auth)).to be_nil
    ensure
      ENV.delete("ALLOW_ALL_DOMAINS")
    end

    it 'auto-provisions a fresh account for the old domain-matching email when domains are allowed' do
      user = User.create!(email: "old@passaiccountycasa.org", google_uid: "google-uid-123")
      user.update!(email: "new@passaiccountycasa.org")

      auth = OmniAuth::AuthHash.new({
        uid: "google-uid-123",
        info: { email: "old@passaiccountycasa.org", first_name: "Jane", last_name: "Doe", name: "Jane Doe" }
      })

      expect { User.from_omniauth(auth) }.to change(User, :count).by(1)
    end
  end
end
