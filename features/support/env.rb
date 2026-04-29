require 'cucumber/rails'
require 'capybara/rails'
require 'rspec/expectations'
require 'selenium-webdriver'
require 'warden/test/helpers'
require 'factory_bot_rails'
require 'fileutils'
require 'database_cleaner/active_record'
require 'rubyXL'
require 'rubyXL/convenience_methods'
require 'capybara/cucumber'

DatabaseCleaner.allow_remote_database_url = true
DatabaseCleaner.strategy = :truncation

Capybara.server = :puma, { Silent: true }

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true


ENV['RAILS_ENV'] = 'test'
ENV['DATABASE_URL'] = ENV['DATABASE_URL']&.sub('_development', '_test')

World(RSpec::Matchers)
World(FactoryBot::Syntax::Methods)
World(Warden::Test::Helpers)

OmniAuth.config.test_mode = true

Before do
  Warden.test_mode!
  ActionMailer::Base.deliveries.clear
  DatabaseCleaner.start
end

Before("@sign_in_attendance") do
  SessionRegistration.delete_all
  InquiryFormSubmission.delete_all
  InformationSession.delete_all
  Volunteer.destroy_all
end

module DownloadHelpers
  DOWNLOAD_PATH = Rails.root.join('tmp', 'test_downloads').freeze

  def self.downloaded_file_path(filename)
    File.join(DOWNLOAD_PATH, filename)
  end

  def self.clear_downloads
    FileUtils.rm_rf(Dir[File.join(DOWNLOAD_PATH, '*')])
  end
end

FileUtils.mkdir_p(DownloadHelpers::DOWNLOAD_PATH)

Capybara.register_driver :chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = '/usr/bin/chromium'
  options.add_argument('--headless')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Before('@javascript') do
  DownloadHelpers.clear_downloads
  page.driver.browser.execute_cdp(
    'Browser.setDownloadBehavior',
    behavior: 'allow',
    downloadPath: DownloadHelpers::DOWNLOAD_PATH.to_s,
    eventsEnabled: true
  )
end

Capybara.default_driver = :chrome_headless
Capybara.javascript_driver = :chrome_headless  
Capybara.server = :puma, { Silent: true }


ActionMailer::Base.deliveries = []

module ClickWithWait
  def click_on(*)
    super
    sleep 0.3
  end

  def click_button(*)
    super
    sleep 0.3
  end

  def click_link(*)
    super
    sleep 0.3
  end
end

World(ClickWithWait)

After do |scenario|
  Capybara.reset_sessions!
  Warden.test_reset!
  OmniAuth.config.mock_auth[:google_oauth2] = nil
  ActionMailer::Base.deliveries.clear
  DatabaseCleaner.clean
end
