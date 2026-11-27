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
  label = "#{method} #{path} -> #{status}"
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
if Rails.env.development? || Rails.env.test?
  expect_error.call("/script", ActionController::InvalidCrossOriginRequest)
  if Rails.env.development?
    expect_error.call("/format.xml", ActionController::UnknownFormat)
    expect_error.call("/template", ActionView::MissingTemplate)
    expect_error.call("/params", Apipie::ParamMissing) if defined?(Apipie)
  end
elsif legacy
  check.call("GET", "/script", 200) { |r| r.body.empty? }
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
  if baseline || ENV["EXCEPTION_ROUTES"] == "yes"
    check.call("GET", "/absent", 200) { |r| r.body.include?("404") }
    check.call("GET", "/fault", 200) { |r| r.body.include?("500") }
  end
else
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
