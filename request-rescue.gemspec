require_relative "lib/request_rescue/version"

Gem::Specification.new do |spec|
  spec.name = "request-rescue"
  spec.version = RequestRescue::VERSION
  spec.authors = ["FeedMob"]
  spec.summary = "Handle malformed requests and render error responses in Rails applications."
  spec.homepage = "https://github.com/feed-mob/request-rescue"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.3"
  spec.files = Dir["lib/**/*.rb", "config/routes.rb", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "allowed_push_host" => "https://rubygems.org"
  }
  spec.add_dependency "railties", ">= 6.1.5", "< 7.2"
  spec.add_dependency "actionpack", ">= 6.1.5", "< 7.2"
  spec.add_dependency "rack", ">= 2.2.3", "< 4"
end
