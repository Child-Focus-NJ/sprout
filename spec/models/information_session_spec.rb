require 'rails_helper'

RSpec.describe InformationSession, type: :model do
  describe 'associations' do
    it { should belong_to(:created_by_user).class_name('User').optional }
    it { should have_many(:session_registrations).dependent(:destroy) }
    it { should have_many(:volunteers).through(:session_registrations) }
  end

  describe 'validations' do
    subject { build(:information_session) }

    it 'validates presence of scheduled_at' do
        session = build(:information_session, scheduled_at: nil)
        expect(session).not_to be_valid
        expect(session.errors[:scheduled_at]).to include('Must include date.')
    end
    it { should validate_presence_of(:location) }
    it { should validate_inclusion_of(:location).in_array(InformationSession::LOCATION_CHOICES) }

    context 'zoom_link' do
      subject { build(:information_session, location: 'Zoom') }

      it { should validate_presence_of(:zoom_link) }

      it 'is invalid with a non-URL zoom link' do
        session = build(:information_session, location: 'Zoom', zoom_link: 'not-a-url')
        expect(session).not_to be_valid
        expect(session.errors[:zoom_link]).to include('must be a URL starting with http:// or https://')
      end

      it 'is valid with an https zoom link' do
        session = build(:information_session, location: 'Zoom', zoom_link: 'https://zoom.us/j/123456')
        expect(session).to be_valid
      end

      it 'is valid with an http zoom link' do
        session = build(:information_session, location: 'Zoom', zoom_link: 'http://zoom.us/j/123456')
        expect(session).to be_valid
      end
    end

    context 'zoom_link is not required for in-person' do
      subject { build(:information_session, location: '415 Hamburg Turnpike') }
      it { should_not validate_presence_of(:zoom_link) }
    end

    context 'scheduled_at in the past' do
      it 'is invalid' do
        session = build(:information_session, scheduled_at: 1.day.ago)
        expect(session).not_to be_valid
        expect(session.errors[:scheduled_at]).to include('Information session must be in the future')
      end
    end

    context 'scheduled_at in the future' do
      it 'is valid' do
        session = build(:information_session, scheduled_at: 1.day.from_now)
        expect(session).to be_valid
      end
    end
  end

  describe 'defaults' do
    it 'defaults capacity to 10' do
      session = InformationSession.new
      expect(session.capacity).to eq(10)
    end
  end

  describe 'callbacks' do
    context 'sync_from_location' do
      it 'sets session_type to virtual when location is Zoom' do
        session = build(:information_session, location: 'Zoom', zoom_link: 'https://zoom.us/j/123')
        session.valid?
        expect(session.session_type).to eq('virtual')
      end

      it 'sets session_type to in_person when location is not Zoom' do
        session = build(:information_session, location: '415 Hamburg Turnpike')
        session.valid?
        expect(session.session_type).to eq('in_person')
      end

      it 'clears zoom_link when location is not Zoom' do
        session = build(:information_session, location: '415 Hamburg Turnpike', zoom_link: 'https://zoom.us/j/123')
        session.valid?
        expect(session.zoom_link).to be_nil
      end

      it 'preserves zoom_link when location is Zoom' do
        session = build(:information_session, location: 'Zoom', zoom_link: 'https://zoom.us/j/123')
        session.valid?
        expect(session.zoom_link).to eq('https://zoom.us/j/123')
      end
    end
  end

  describe 'scopes' do
    let!(:past_session) do
    session = build(:information_session, scheduled_at: 1.day.ago)
    session.save!(validate: false)
    session
    end
    let!(:upcoming_session) { create(:information_session, scheduled_at: 1.day.from_now) }

    # past/upcoming sessions won't pass the future validation, so we skip it
    before do
      past_session.save(validate: false)
    end

    describe '.upcoming' do
      it 'includes sessions scheduled in the future' do
        expect(InformationSession.upcoming).to include(upcoming_session)
      end

      it 'excludes sessions scheduled in the past' do
        expect(InformationSession.upcoming).not_to include(past_session)
      end
    end

    describe '.past' do
      it 'includes sessions scheduled in the past' do
        expect(InformationSession.past).to include(past_session)
      end

      it 'excludes sessions scheduled in the future' do
        expect(InformationSession.past).not_to include(upcoming_session)
      end
    end
  end

  describe '#spots_remaining' do
    let(:session) { create(:information_session, capacity: 5) }
    let(:volunteers) { create_list(:volunteer, 3) }

    it 'returns capacity when no registrations exist' do
      expect(session.spots_remaining).to eq(5)
    end

    it 'decrements for registered volunteers' do
      volunteers.each do |v|
        create(:session_registration, information_session: session, volunteer: v, status: :registered)
      end
      expect(session.spots_remaining).to eq(2)
    end

    it 'decrements for attended volunteers' do
      create(:session_registration, information_session: session, volunteer: volunteers.first, status: :attended)
      expect(session.spots_remaining).to eq(4)
    end

    it 'does not decrement for cancelled registrations' do
      create(:session_registration, information_session: session, volunteer: volunteers.first, status: :cancelled)
      expect(session.spots_remaining).to eq(5)
    end

    it 'does not decrement for no_show registrations' do
      create(:session_registration, information_session: session, volunteer: volunteers.first, status: :no_show)
      expect(session.spots_remaining).to eq(5)
    end
  end

  describe '#label' do
    it 'returns a formatted string with name and date' do
      session = build(:information_session, name: 'Spring Session', scheduled_at: Time.zone.parse('2027-03-27 10:00 AM'))
      expect(session.label).to eq('Spring Session - Mar 27, 2027 10:00 AM')
    end
  end

  describe '#zoom_location?' do
    it 'returns true when location is Zoom' do
      session = build(:information_session, location: 'Zoom')
      expect(session.zoom_location?).to be true
    end

    it 'returns false when location is not Zoom' do
      session = build(:information_session, location: '415 Hamburg Turnpike')
      expect(session.zoom_location?).to be false
    end
  end
end
