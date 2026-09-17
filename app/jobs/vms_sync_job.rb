# Periodic pull from the external Volunteer Management System, keeping Sprout
# reconciled with it. Reuses ExternalVmsSync, this job just calls it on a
# schedule.
class VmsSyncJob < ApplicationJob
  queue_as :default

  def perform
    ExternalVmsSync.new.sync!
  end
end
