# frozen_string_literal: true

require "anonymous_loader"
RSpec.describe AnonymousLoader::Version do
  it_behaves_like "a Version module", described_class

  it "executes the version file for coverage without redefining constants" do
    dir = File.expand_path("../../lib/anonymous_loader", __dir__)
    paths = %w[version.rb version_gem.rb].map { |file| File.join(dir, file) }.select { |path| File.file?(path) }
    anonymous_namespace = AnonymousLoader.load(files: paths)

    expect(anonymous_namespace::AnonymousLoader::Version::VERSION).to eq(described_class::VERSION)
  end
end
