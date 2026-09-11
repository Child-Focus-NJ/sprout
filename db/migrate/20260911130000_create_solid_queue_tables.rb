# Solid Queue's own tables. Applied to whatever `primary` is configured as (see
# config/database.yml) — in development/test that's the single app database (the
# "single database configuration" documented in the solid_queue gem's README);
# in production it's the genuinely separate `queue` database
# (config.solid_queue.connects_to in config/environments/production.rb), so
# these table definitions also end up unused-but-harmless in production's primary
# database. Table/column/index definitions are copied verbatim from the gem's
# generated db/queue_schema.rb (solid_queue 1.3.1), not hand-derived.
class CreateSolidQueueTables < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_queue_jobs do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :active_job_id
      t.index :class_name
      t.index :finished_at
      t.index [ :queue_name, :finished_at ], name: "index_solid_queue_jobs_for_filtering"
      t.index [ :scheduled_at, :finished_at ], name: "index_solid_queue_jobs_for_alerting"
    end

    create_table :solid_queue_blocked_executions do |t|
      t.references :job, null: false, index: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false

      t.index [ :concurrency_key, :priority, :job_id ], name: "index_solid_queue_blocked_executions_for_release"
      t.index [ :expires_at, :concurrency_key ], name: "index_solid_queue_blocked_executions_for_maintenance"
      t.index :job_id, unique: true, name: "index_solid_queue_blocked_executions_on_job_id"
    end

    create_table :solid_queue_claimed_executions do |t|
      t.references :job, null: false, index: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.bigint :process_id
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, name: "index_solid_queue_claimed_executions_on_job_id"
      t.index [ :process_id, :job_id ], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
    end

    create_table :solid_queue_failed_executions do |t|
      t.references :job, null: false, index: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.text :error
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, name: "index_solid_queue_failed_executions_on_job_id"
    end

    create_table :solid_queue_pauses do |t|
      t.string :queue_name, null: false
      t.datetime :created_at, null: false

      t.index :queue_name, unique: true, name: "index_solid_queue_pauses_on_queue_name"
    end

    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.datetime :created_at, null: false
      t.string :name, null: false

      t.index :last_heartbeat_at
      t.index [ :name, :supervisor_id ], unique: true, name: "index_solid_queue_processes_on_name_and_supervisor_id"
      t.index :supervisor_id
    end

    create_table :solid_queue_ready_executions do |t|
      t.references :job, null: false, index: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, name: "index_solid_queue_ready_executions_on_job_id"
      t.index [ :priority, :job_id ], name: "index_solid_queue_poll_all"
      t.index [ :queue_name, :priority, :job_id ], name: "index_solid_queue_poll_by_queue"
    end

    create_table :solid_queue_recurring_executions do |t|
      t.references :job, null: false, index: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :task_key, null: false
      t.datetime :run_at, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, name: "index_solid_queue_recurring_executions_on_job_id"
      t.index [ :task_key, :run_at ], unique: true, name: "index_solid_queue_recurring_executions_on_task_key_and_run_at"
    end

    create_table :solid_queue_recurring_tasks do |t|
      t.string :key, null: false
      t.string :schedule, null: false
      t.string :command, limit: 2048
      t.string :class_name
      t.text :arguments
      t.string :queue_name
      t.integer :priority, default: 0
      t.boolean :static, default: true, null: false
      t.text :description
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :key, unique: true, name: "index_solid_queue_recurring_tasks_on_key"
      t.index :static, name: "index_solid_queue_recurring_tasks_on_static"
    end

    create_table :solid_queue_scheduled_executions do |t|
      t.references :job, null: false, index: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, name: "index_solid_queue_scheduled_executions_on_job_id"
      t.index [ :scheduled_at, :priority, :job_id ], name: "index_solid_queue_dispatch_all"
    end

    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :expires_at, name: "index_solid_queue_semaphores_on_expires_at"
      t.index [ :key, :value ], name: "index_solid_queue_semaphores_on_key_and_value"
      t.index :key, unique: true, name: "index_solid_queue_semaphores_on_key"
    end
  end
end
