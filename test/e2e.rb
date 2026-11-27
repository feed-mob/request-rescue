require "logger"
require "json"
require "rails"
require "action_controller/railtie"
require "rack/mock"
require "apipie-rails" if ENV["APIPIE_VERSION"]

baseline = ENV.fetch("TEST_GEM") == "feedmob-rescue"
if baseline
  require "feedmob/rescue"
  TEST_ENGINE = Feedmob::Rescue::Engine
  TEST_CONCERN = Feedmob::Rescue
else
  require "request-rescue"
  TEST_ENGINE = RequestRescue::Engine
  TEST_CONCERN = RequestRescue::Controller
end

expected = { "railties" => ENV.fetch("RAILS_VERSION"), "rack" => ENV.fetch("RACK_VERSION") }
expected["apipie-rails"] = ENV["APIPIE_VERSION"] if ENV["APIPIE_VERSION"]
expected.each do |name, version|
  raise "Expected #{name} #{version}" unless Gem.loaded_specs.fetch(name).version.to_s == version
end
target = Gem.loaded_specs.fetch(ENV.fetch("TEST_GEM"))
raise "Unexpected gem source" unless File.realpath(target.full_gem_path) == File.realpath(ENV.fetch("TEST_GEM_PATH"))

class ProbeApp < Rails::Application
  config.root = File.expand_path("host", __dir__)
  config.secret_key_base = "request-rescue-local-test-" * 4
  config.eager_load = false
  config.api_only = ENV["HOST_API"] == "yes"
  config.consider_all_requests_local = false
  config.logger = Logger.new(File::NULL)
  config.hosts.clear
  config.active_support.deprecation = :stderr
  config.active_support.cache_format_version = 7.1 if Rails.gem_version >= Gem::Version.new("7.1")
  config.action_dispatch.show_exceptions = if Rails.gem_version >= Gem::Version.new("7.1")
    Rails.env.development? || Rails.env.test? ? :none : :all
  else
    Rails.env.production?
  end
  if ENV["TEST_GEM"] == "feedmob-rescue"
    config.exceptions_app = routes
  else
    config.request_rescue.legacy_responses = ENV["LEGACY"] == "yes"
    config.exceptions_app = ENV["EXCEPTION_ROUTES"] == "yes" ? routes : RequestRescue::ExceptionsApp
  end
end

app = ProbeApp.instance
app.initialize!
client = Rack::MockRequest.new(app)
checks = []
check = lambda do |method, path, status, headers = {}, &validate|
  response = client.request(method, path, headers)
  label = "#{method} #{path}#{" (Accept: #{headers['HTTP_ACCEPT']})" if headers["HTTP_ACCEPT"]} -> #{status}"
  unless response.status == status && (!validate || validate.call(response))
    raise "#{label}: got #{response.status}, #{response['location']}, #{response.body[0, 120]}"
  end
  checks << label
end
expect_error = lambda do |path, klass|
  begin
    client.get(path)
  rescue klass
    checks << "GET #{path} -> #{klass}"
  else
    raise "Expected #{klass} from #{path}"
  end
end

legacy = ENV["LEGACY"] == "yes" || baseline
prefix = ENV.fetch("MOUNT_AT").sub(%r{/\z}, "")
json = { "HTTP_ACCEPT" => "application/json" }
check.call("GET", "/ok?value=hello", 200) { |r| JSON.parse(r.body)["value"] == "hello" }
check.call("HEAD", "/ok", 200) { |r| r.body.empty? }
check.call("POST", "/echo", 200, "CONTENT_TYPE" => "application/json", :input => '{"value":"posted"}') do |r|
  JSON.parse(r.body) == { "value" => "posted" }
end
if Rails.env.development? || Rails.env.test?
  expect_error.call("/script", ActionController::InvalidCrossOriginRequest)
  expect_error.call("/javascript", ActionController::InvalidCrossOriginRequest)
  if Rails.env.development?
    expect_error.call("/format.xml", ActionController::UnknownFormat)
    expect_error.call("/template", ActionView::MissingTemplate)
    if defined?(Apipie)
      expect_error.call("/params", Apipie::ParamMissing)
      expect_error.call("/params?number=no", Apipie::ParamInvalid)
    end
  end
end
if legacy && !Rails.env.development?
  check.call("GET", "/script", 200) { |r| r.body.empty? } unless Rails.env.test?
  %w[/format.xml /template].each do |path|
    check.call("GET", path, 302) { |r| URI(r["location"]).path == "#{prefix}/not_found" }
  end
  if defined?(Apipie)
    ["/params", "/params?number=no"].each do |path|
      check.call("GET", path, 302) { |r| URI(r["location"]).path == "#{prefix}/invalid_params" }
    end
  end
  check.call("GET", "#{prefix}/not_found", 200) { |r| r.body.include?("404") }
  check.call("GET", "#{prefix}/invalid_params", 200) { |r| r.body.include?("422") }
  check.call("POST", "#{prefix}/404", 200) { |r| r.body.include?("404") }
  check.call("PUT", "#{prefix}/500", 200) { |r| r.body.include?("500") }
  check.call("HEAD", "#{prefix}/500", 200) { |r| r.body.empty? }
  check.call("GET", "#{prefix}/not_found?value=%FF", 400)
  check.call("GET", "#{prefix}/not_found?items[][name]=%FF", 400)
  check.call("GET", "#{prefix}/not_found?value=%E2%9C%93", 200)
  # Controllers still redirect JSON requests, but feedmob-rescue 0.1.7 also redirected
  # its own pages to not_found, so a client following redirects never got a response.
  check.call("GET", "/format", 302, json) { |r| URI(r["location"]).path == "#{prefix}/not_found" }
  page_for_json = lambda do |path, message, headers = json|
    if baseline
      check.call("GET", path, 302, headers) { |r| URI(r["location"]).path == "/not_found" }
    else
      check.call("GET", path, 200, headers) do |r|
        r["content-type"].start_with?("application/json") && JSON.parse(r.body) == { "errors" => [message] }
      end
    end
  end
  page_for_json.call("#{prefix}/not_found", "Page not found")
  page_for_json.call("#{prefix}/invalid_params", "Invalid parameters")
  if Rails.env.production?
    if baseline || ENV["EXCEPTION_ROUTES"] == "yes"
      # The routes only define /404 and /500. Other statuses get an empty body.
      check.call("GET", "/absent", 200) { |r| r.body.include?("404") }
      check.call("GET", "/fault", 200) { |r| r.body.include?("500") }
      check.call("GET", "/required", 400) { |r| r.body.empty? }
      page_for_json.call("/absent", "Page not found")
      page_for_json.call("/absent.json", "Page not found", {})
      page_for_json.call("/fault", "Internal server error")
    else
      # RequestRescue::ExceptionsApp keeps legacy redirects and returns real statuses.
      check.call("GET", "/absent", 404) { |r| r.body.include?("404") }
      check.call("GET", "/fault", 500) { |r| !r.body.include?("private fixture exception") }
      check.call("GET", "/required", 400) { |r| r.body.include?("400") }
    end
  end
elsif Rails.env.production?
  check.call("GET", "/script", 403, json) do |r|
    r["content-type"].start_with?("application/json") && JSON.parse(r.body)["errors"] == ["Forbidden"] &&
      r["vary"].split(/,\s*/).sort == %w[Accept Origin]
  end
  if ENV["HOST_API"] == "yes"
    check.call("GET", "/absent", 404) { |r| r["content-type"].include?("application/json") }
  else
    check.call("GET", "/format.xml", 404) { |r| r["content-type"].include?("text/html") && r.body.include?("404") }
    check.call("GET", "/template", 404)
  end
  if defined?(Apipie)
    check.call("GET", "/params", 422, json) { |r| JSON.parse(r.body).key?("errors") }
    check.call("GET", "/params?number=no", 422)
    check.call("GET", "/params?number=15", 200)
  end
  check.call("GET", "#{prefix}/not_found", 404)
  check.call("GET", "#{prefix}/invalid_params", 422)
  check.call("GET", "/absent", 404, json) { |r| JSON.parse(r.body).key?("errors") }
  check.call("GET", "/fault", 500) { |r| !r.body.include?("private fixture exception") }
  check.call("HEAD", "/absent", 404) { |r| r.body.empty? }
end
if Rails.env.production?
  unless app.config.api_only
    check.call("GET", "/javascript", legacy ? 200 : 403) { |r| legacy ? r.body.empty? : !r.body.include?("void(0)") }
    check.call("GET", "/javascript", 200, "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest") { |r| r.body.include?("void(0)") }
  end
  check.call("UNRECOGNIZED", "/ok", 405) { |r| JSON.parse(r.body) == { "errors" => ["Method not allowed"] } }
  unless baseline
    check.call("GET", "/ok?value=1&value[]=2", 400)
    check.call("GET", "/ok?value=%FF", 400)
    check.call("GET", "/ok?value[]=one&value[]=two", 200) { |r| JSON.parse(r.body)["value"] == %w[one two] }
    check.call("HEAD", "/ok?value=1&value[]=2", 400) { |r| r.body.empty? }
  end
end

puts JSON.generate(environment: Rails.env, legacy: legacy, mount: ENV["MOUNT_AT"],
                   api_only: app.config.api_only, checks: checks)
