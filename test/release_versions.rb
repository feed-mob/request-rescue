require "fileutils"
require "rbconfig"
require "rubygems/package"
require "tmpdir"

root = File.expand_path("..", __dir__)
Dir.mktmpdir("release-versions") do |dir|
  FileUtils.cp_r(%w[bin lib config request-rescue.gemspec README.md CHANGELOG.md LICENSE.txt].map { |path| File.join(root, path) }, dir)
  Dir.chdir(dir) do
    path = "lib/request_rescue/version.rb"
    baseline = File.read(path).sub(/VERSION = "[\d.]+"/, 'VERSION = "1.2.9"')
    File.write(path, baseline)
    options = IO.popen([RbConfig.ruby, "bin/prepare-release", "--options", "1.2.9"], &:read)
    %w[1.2.10 1.3.0 2.0.0].each { |v| abort "Missing preview #{v}" unless options.include?("`#{v}`") }
    abort "Preview changed the version" unless File.read(path) == baseline

    { ["patch", ""] => "1.2.10", ["minor"] => "1.3.0", ["major"] => "2.0.0",
      ["patch", "1.10.0"] => "1.10.0" }.each do |args, expected|
      File.write(path, baseline)
      version = IO.popen([RbConfig.ruby, "bin/prepare-release", *args], &:read).strip
      abort "Unexpected #{args.inspect} version: #{version}" unless $?.success? && version == expected
      system("gem", "build", "request-rescue.gemspec", "--strict", "--output", "candidate.gem", exception: true)
      abort "Incorrect gem version" unless Gem::Package.new("candidate.gem").spec.version.to_s == expected
    end
    File.write(path, baseline)
    [[], ["path"], ["patch", "1.2.9"], ["minor", "1.2.8"], ["major", "02.0.0"], ["patch", "v1.3.0"]].each do |args|
      abort "Expected invalid input to fail" if system(RbConfig.ruby, "bin/prepare-release", *args)
      abort "Invalid input changed the version" unless File.read(path) == baseline
    end
  end
end
