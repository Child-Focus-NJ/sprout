class ReorderScheduledRemindersStatusIndex < ActiveRecord::Migration[8.1]
  def change
    # The original [scheduled_for, status] index doesn't help ScheduledReminder.due /
    # .upcoming (both filter status by equality, scheduled_for by range/order): once the
    # table has real history, most rows — sent or cancelled — also have a past
    # scheduled_for, so the leading range column barely narrows anything and Postgres
    # falls back to a sequential scan. Leading with the equality column (status) instead
    # lets it narrow to just pending rows before touching scheduled_for at all. Verified
    # against 50k synthetic rows: before this, .due was still a Seq Scan; after, it's an
    # Index Scan.
    remove_index :scheduled_reminders, [ :scheduled_for, :status ]
    add_index :scheduled_reminders, [ :status, :scheduled_for ]
  end
end
