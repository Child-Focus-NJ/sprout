require "rails_helper"

RSpec.describe VmsSyncJob, type: :job do
  it "calls ExternalVmsSync#sync!" do
    sync = instance_double(ExternalVmsSync)
    allow(ExternalVmsSync).to receive(:new).and_return(sync)
    allow(sync).to receive(:sync!).and_return([])

    described_class.perform_now

    expect(sync).to have_received(:sync!)
  end

  it "re-raises when the sync fails, so the failure shows up as a failed job execution" do
    sync = instance_double(ExternalVmsSync)
    allow(ExternalVmsSync).to receive(:new).and_return(sync)
    allow(sync).to receive(:sync!).and_raise("VMS unreachable")

    expect { described_class.perform_now }.to raise_error("VMS unreachable")
  end
end
