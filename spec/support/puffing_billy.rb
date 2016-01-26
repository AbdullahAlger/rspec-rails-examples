# Installing Puffing Billy:

# 0. Check spec/support dir is auto-required in spec/rails_helper.rb.
#
# 1. Puffing Billy depends on Capybara. Install Capybara as explained
#    in spec/support/capybara.rb
#
# 2. Add puffing-billy to Gemfile:
#
# group :development, :test do
#   gem 'puffing-billy'
# end
#
# 3. Create a file like this one you're reading in spec/support/puffing_billy.rb:
require 'billy/rspec'

# 4. Configure cache to behave as required. See all available options at:
#    https://github.com/oesmith/puffing-billy#caching
Billy.configure do |c|
  stripe_urls_with_ignorable_query_string_params = [
    'https://q.stripe.com/',
    'https://api.stripe.com/v1/tokens'
  ]

  c.ignore_params += stripe_urls_with_ignorable_query_string_params
  
  stripe_html_url_pattern = %r{https://checkout\.stripe\.com(:443)?/v3/\w+\.html\?distinct_id=.+}
  firefox_url_pattern = %r{\.mozilla\.com}
  mixpanel_analytics_url_pattern = %r{api\.mixpanel\.com}
  
  # merge_cached_responses_whitelist are URI regex patterns for responses
  # that will be merged into a single cached response. Useful for analytics,
  # social buttons with minor URL variations. A response will be recorded
  # once and reused.
  c.merge_cached_responses_whitelist = [
    stripe_html_url_pattern,
    firefox_url_pattern,
    mixpanel_analytics_url_pattern
  ]
  
  c.cache = true
  c.cache_request_headers = false
  
  c.persist_cache = true
  c.non_successful_cache_disabled = false
  c.non_successful_error_level = :warn

  # cache_path is where responses from external URLs will be saved as YAML.
  c.cache_path = "spec/support/http_cache/browser/"

  # Avoid having tests dependent on external URLs.
  #
  # Only set non_whitelisted_requests_disabled **temporarily**
  # to false when first recording a 3rd party interaction. After
  # the recording has been stored to cache_path, then set
  # non_whitelisted_requests_disabled back to true.
  #
  # To enable recording new responses temporarily, run the individual spec
  # and prepend with BILLY_RECORDING set to true:
  # BILLY_RECORDING=true bin/rspec spec/features/user_upgrades_spec.rb
  prevent_recording = ('true' != ENV['BILLY_RECORDING'])
  c.non_whitelisted_requests_disabled = prevent_recording
end

# https://github.com/oesmith/puffing-billy#working-with-vcr-and-webmock
if defined?(VCR)
  VCR.configure do |config|
    config.ignore_request { |request| handled_by_billy?(request) }
  end

  def handled_by_billy?(request)
    # browser_referer?(request)
    browser_user_agent?(request) && puffing_billy_driver_active?
  end

  def browser_user_agent?(request)
    user_agent = !request.headers["User-Agent"].blank? && request.headers["User-Agent"].first
    user_agent != "Ruby"
  end

  def puffing_billy_driver_active?
    Capybara.current_driver =~ /_billy\z/
  end

  # def allowed_referers
  #   [
  #     %r{\Ahttp://#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}/},
  #     %r{\Ahttps://checkout\.stripe\.com},
  #     %r{\Ahttps://b\.stripecdn\.com}
  #   ]
  # end

  # def browser_referer?(request)
  #   referer = !request.headers["Referer"].blank? && request.headers["Referer"].first
  #   referer && allowed_referers.any? { |pattern| pattern =~ referer }
  # end
end

# 5. Uncomment the *_billy driver for your desired browser:
Capybara.javascript_driver = :selenium_billy # Uses Firefox
# Capybara.javascript_driver = :selenium_chrome_billy
# Capybara.javascript_driver = :webkit_billy
# Capybara.javascript_driver = :poltergeist_billy

# 6. Use an always-available server_port for Capybara so Puffing Billy
#    cached responses that store localhost URL with port (e.g. some
#    CORS Access-Control-Allow-Origin response headers) are consistent
#    between test runs.
Capybara.server_port = 54068

module BillyCache
  def with_browser_responses(scope, &block)
    proxy.cache.with_scope(scope, &block)
  end
end

RSpec.configure do |config|
  config.include BillyCache, type: :feature
end

# 7. Start using Puffing Billy. See spec/features/share_page_spec.rb for an example,
#    and find your cached responses in spec/support/http_cache/frontend

# Suggested docs
# --------------
# https://github.com/oesmith/puffing-billy
# https://github.com/oesmith/puffing-billy#rspec-usage
# https://github.com/oesmith/puffing-billy#caching
