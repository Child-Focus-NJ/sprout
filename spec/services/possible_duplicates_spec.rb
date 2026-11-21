require "rails_helper"

RSpec.describe PossibleDuplicates do
  def volunteer(first_name, last_name, phone: nil, **attributes)
    create(:volunteer, first_name: first_name, last_name: last_name, phone: phone, **attributes)
  end

  def found
    described_class.pairs.map { |pair| [ pair.volunteer, pair.other_volunteer, pair.reasons ] }
  end

  it "matches the same phone number written differently, including a leading 1" do
    jordan = volunteer("Jordan", "Ellis", phone: "(201) 555-0147")
    other = volunteer("Jordan", "Ellis-Brown", phone: "+1 201 555 0147")
    volunteer("Sam", "Reed", phone: "201-555-0148")

    expect(found).to eq([ [ jordan, other, [ "Same phone" ] ] ])
  end

  it "matches the same first and last name regardless of capitalization and spacing" do
    maria = volunteer("Maria", "Lopez")
    other = volunteer(" maria", "LOPEZ ")
    volunteer("Maria", "Lopes")

    expect(found).to eq([ [ maria, other, [ "Same name" ] ] ])
  end

  it "lists a pair once with every reason it matched" do
    chris = volunteer("Chris", "Patel", phone: "973-555-0100")
    other = volunteer("Chris", "Patel", phone: "9735550100")

    expect(found).to eq([ [ chris, other, [ "Same name", "Same phone" ] ] ])
    expect(described_class.count).to eq(1)
  end

  it "doesn't match different people, missing phone numbers, or ones too short to compare" do
    volunteer("Ana", "Ruiz")
    volunteer("Ben", "Cole", phone: "")
    volunteer("Cara", "Diaz", phone: "555-01")
    volunteer("Dev", "Shah", phone: "555-01")

    expect(found).to be_empty
    expect(described_class.count).to eq(0)
    expect(described_class.any?).to be(false)
  end

  it "leaves out pairs marked not a duplicate but keeps the rest of the group" do
    first = volunteer("Lena", "Ortiz")
    second = volunteer("Lena", "Ortiz")
    third = volunteer("Lena", "Ortiz")
    DuplicateDismissal.dismiss!(third, first, user: nil)

    expect(found.map { |a, b, _| [ a, b ] }).to contain_exactly([ first, second ], [ second, third ])
    expect(described_class.count).to eq(2)
  end

  it "leaves out anyone made inactive as a duplicate, but not for other inactive reasons" do
    volunteer("Kim", "Nguyen")
    volunteer("Kim", "Nguyen", current_funnel_stage: :inactive, inactive_reason: :duplicate)
    expect(described_class.any?).to be(false)

    volunteer("Kim", "Nguyen", current_funnel_stage: :inactive, inactive_reason: :no_response)
    expect(described_class.any?).to be(true)
  end

  it "lists the newest pair first, with the older record first in each pair" do
    older_pair = [ volunteer("Ola", "Berg", created_at: 3.days.ago), volunteer("Ola", "Berg", created_at: 2.days.ago) ]
    newer = volunteer("Ray", "Cho", phone: "862-555-0110", created_at: 1.hour.ago)
    older = volunteer("Ray", "Choi", phone: "862-555-0110", created_at: 1.day.ago)

    expect(found.map { |a, b, _| [ a, b ] }).to eq([ [ older, newer ], older_pair ])
  end
end
