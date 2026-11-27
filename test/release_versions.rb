require "fileutils"
require "rbconfig"
require "rubygems/package"
require "tmpdir"
require "yaml"

root = File.expand_path("..", __dir__)
inputs = YAML.load_file(File.join(root, ".github/workflows/release.yml")).fetch("on").fetch("workflow_dispatch").fetch("inputs")
bump = inputs.fetch("bump")
abort "Expected plain increment choices" unless bump.fetch("options") == %w[patch minor major] && bump.fetch("default") == "patch"

Dir.mktmpdir("release-versions") do |dir|
  FileUtils.cp_r(%w[bin lib config request-rescue.gemspec README.md CHANGELOG.md LICENSE.txt].map { |path| File.join(root, path) }, dir)
  Dir.chdir(dir) do
    path = "lib/request_rescue/version.rb"
    baseline = File.read(path).sub(/VERSION = "[\d.]+"/, 'VERSION = "1.2.9"')
    { "patch" => "1.2.10", "minor" => "1.3.0", "major" => "2.0.0" }.each do |bump, expected|
      File.write(path, baseline)
      version = IO.popen([RbConfig.ruby, "bin/prepare-release", bump], &:read).strip
      abort "Unexpected #{bump} version: #{version}" unless $?.success? && version == expected
      system("gem", "build", "request-rescue.gemspec", "--strict", "--output", "candidate.gem", exception: true)
      abort "Incorrect gem version" unless Gem::Package.new("candidate.gem").spec.version.to_s == expected
    end
    File.write(path, baseline)
    [[], ["path"], ["patch → 1.2.10"], ["minor", "1.3.0"]].each do |args|
      abort "Expected invalid input to fail" if system(RbConfig.ruby, "bin/prepare-release", *args)
      abort "Invalid input changed the version" unless File.read(path) == baseline
    end
  end
end
