require "rails_helper"

RSpec.describe VmsPushInquiryJob, type: :job do
  let(:volunteer) { create(:volunteer, first_name: "Pat", last_name: "Walker", phone: "5551234567") }
  let(:sync) { instance_double(ExternalVmsSync) }

  before { allow(ExternalVmsSync).to receive(:new).and_return(sync) }

  it "pushes the volunteer as a VMS inquiry and stores the returned encrypted_id" do
    allow(sync).to receive(:create_inquiry!).and_return("NjQxNjk5")

    described_class.perform_now(volunteer.id)

    expect(sync).to have_received(:create_inquiry!).with(
      hash_including(first_name: "Pat", last_name: "Walker", phone: "5551234567", email: volunteer.email)
    )
    expect(volunteer.reload).to have_attributes(external_id: "NjQxNjk5")
    expect(volunteer.external_synced_at).to be_present
  end

  it "does not touch the volunteer if the VMS never returns an encrypted_id" do
    allow(sync).to receive(:create_inquiry!).and_return(nil)

    described_class.perform_now(volunteer.id)

    expect(volunteer.reload.external_id).to be_nil
  end

  it "re-raises when the push fails" do
    allow(sync).to receive(:create_inquiry!).and_raise("VMS unreachable")

    expect { described_class.perform_now(volunteer.id) }.to raise_error("VMS unreachable")
  end
end
