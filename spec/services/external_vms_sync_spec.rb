require "rails_helper"
require "webmock/rspec"

RSpec.describe ExternalVmsSync do
  let(:base_url) { "https://nj-passaic.evintotraining.com" }

  before do
    WebMock.disable_net_connect!
    ENV["EXTERNAL_VMS_USERNAME"] = "test_user"
    ENV["EXTERNAL_VMS_PASSWORD"] = "test_pass"

    stub_request(:get, "#{base_url}/Account/LogOn").to_return(status: 200, body: "<html></html>")
    stub_request(:post, "#{base_url}/Account/LogOn")
      .to_return(status: 302, headers: { "Set-Cookie" => ".ASPXAUTH=abc123" })
  end

  after do
    WebMock.allow_net_connect!
    ENV.delete("EXTERNAL_VMS_USERNAME")
    ENV.delete("EXTERNAL_VMS_PASSWORD")
  end

  describe "#create_inquiry!" do
    let(:inquiry_attrs) do
      { first_name: "John", last_name: "Doe", phone: "2015551234", email: "john@example.com", inquired: "9/16/2026" }
    end

    it "creates the inquiry, returns the VMS encrypted_id, and logs a completed push" do
      stub_request(:post, "#{base_url}/Inquiry/Create").to_return(status: 302)
      stub_request(:post, "#{base_url}/Inquiry/_Index?active=active").to_return(
        status: 200,
        body: {
          "Data" => [ { "FirstName" => "John", "LastName" => "Doe", "Email" => "john@example.com",
                       "EncryptedID" => "NjQxNjk5" } ],
          "Total" => 1
        }.to_json
      )

      expect { @encrypted_id = described_class.new.create_inquiry!(**inquiry_attrs) }
        .to change(ExternalSyncLog, :count).by(1)

      expect(@encrypted_id).to eq("NjQxNjk5")
      log = ExternalSyncLog.last
      expect(log).to have_attributes(sync_type: "push", sync_direction: "outbound", status: "completed")
    end

    it "raises and logs a failed push when the VMS rejects the create" do
      stub_request(:post, "#{base_url}/Inquiry/Create").to_return(status: 200, body: "validation error")

      expect { described_class.new.create_inquiry!(**inquiry_attrs) }
        .to raise_error("External VMS inquiry creation failed")
        .and change(ExternalSyncLog, :count).by(1)

      expect(ExternalSyncLog.last).to have_attributes(status: "failed")
    end
  end

  describe "#edit_inquiry!" do
    it "submits the hidden fields plus the requested changes and logs a completed push" do
      stub_request(:get, "#{base_url}/Inquiry/Edit/NjQxNjk5")
        .to_return(status: 200, body: '<input type="hidden" name="InquiryID" value="641699">')
      stub_request(:post, "#{base_url}/Inquiry/Edit/NjQxNjk5")
        .with(body: hash_including("InquiryID" => "641699", "Active" => "false", "PartyID" => "7217143"))
        .to_return(status: 302)

      expect(described_class.new.edit_inquiry!(encrypted_id: "NjQxNjk5", active: false, party_id: 7217143)).to be true
      expect(ExternalSyncLog.last).to have_attributes(sync_type: "push", status: "completed")
    end
  end

  describe "#delete_inquiry!" do
    it "confirms deletion using the page's hidden fields" do
      stub_request(:get, "#{base_url}/Inquiry/Delete/NjQxNjk5")
        .to_return(status: 200, body: '<input type="hidden" name="InquiryID" value="641699">')
      stub_request(:post, "#{base_url}/Inquiry/Delete/NjQxNjk5").to_return(status: 302)

      expect(described_class.new.delete_inquiry!(encrypted_id: "NjQxNjk5")).to be true
    end
  end

  describe "#create_volunteer!" do
    it "maps optional fields to their VMS PascalCase names" do
      stub_request(:post, "#{base_url}/Volunteers/Create")
        .with(body: hash_including("HomeEmail" => "chelsea@example.com"))
        .to_return(status: 302)

      expect(
        described_class.new.create_volunteer!(first_name: "Chelsea", last_name: "Cattano",
                                                home_email: "chelsea@example.com")
      ).to be true
    end

    it "raises ArgumentError for an unknown optional field" do
      expect {
        described_class.new.create_volunteer!(first_name: "Chelsea", last_name: "Cattano", made_up_field: "x")
      }.to raise_error(ArgumentError, /Unknown volunteer field/)
    end
  end

  describe "#list_volunteers" do
    it "lists active volunteers via the _GridIndex endpoint" do
      stub_request(:post, "#{base_url}/Volunteers/_GridIndex?active=yes").to_return(
        status: 200,
        body: { "Data" => [ { "FirstName" => "Chelsea", "LastName" => "Cattano" } ], "Total" => 1 }.to_json
      )

      records = described_class.new.list_volunteers
      expect(records).to eq([ { "first_name" => "Chelsea", "last_name" => "Cattano" } ])
    end
  end

  describe "#list_lookup" do
    it "lists a known lookup type" do
      stub_request(:post, "#{base_url}/County/_Index").to_return(
        status: 200,
        body: { "Data" => [ { "CountyID" => 22_967, "CountyName" => "Passaic" } ], "Total" => 1 }.to_json
      )

      expect(described_class.new.list_lookup("County"))
        .to eq([ { "county_id" => 22_967, "county_name" => "Passaic" } ])
    end

    it "raises ArgumentError for an unknown lookup type" do
      expect { described_class.new.list_lookup("NotARealType") }.to raise_error(ArgumentError, /Unknown VMS lookup/)
    end
  end

  describe "#sync!" do
    it "pulls active inquiries and upserts them as volunteers" do
      stub_request(:post, "#{base_url}/Inquiry/_Index?active=active").to_return(
        status: 200,
        body: {
          "Data" => [ { "FirstName" => "Jane", "LastName" => "Smith", "Email" => "jane@example.com",
                       "EncryptedID" => "abc", "Inquired" => "9/1/2026" } ],
          "Total" => 1
        }.to_json
      )

      expect { described_class.new.sync! }.to change(Volunteer, :count).by(1)
      expect(Volunteer.find_by(email: "jane@example.com")).to be_present
    end
  end
end
