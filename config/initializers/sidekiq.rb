require 'sidekiq'
require 'sidekiq-scheduler'

# Build Redis URL from environment variables dynamically (standard 12-factor pattern)
redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1').to_s.strip.gsub(/\A["']|["']\z/, '')

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  
  # Load schedule from sidekiq.yml
  schedule_file = 'config/sidekiq.yml'
  if File.exist?(schedule_file)
    SidekiqScheduler::Scheduler.instance.load_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

