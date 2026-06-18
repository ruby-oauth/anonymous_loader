# frozen_string_literal: true

RSpec.describe AnonymousLoader do
  it "has a version number" do
    expect(AnonymousLoader::VERSION).not_to be_nil
  end

  it "loads a file into an anonymous namespace without defining top-level constants" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "library.rb")
      File.write(path, <<-RUBY)
        module AnonymousLoaderSpecAuth
          module Sanitizer
            VALUE = "loaded"
          end
        end
      RUBY

      expect(Object.const_defined?(:AnonymousLoaderSpecAuth, false)).to be(false)
      namespace = described_class.load(files: path)

      expect(Object.const_defined?(:AnonymousLoaderSpecAuth, false)).to be(false)
      expect(namespace.const_get(:AnonymousLoaderSpecAuth).const_get(:Sanitizer).const_get(:VALUE)).to eq("loaded")
    end
  end

  it "loads multiple files in order" do
    Dir.mktmpdir do |dir|
      first = File.join(dir, "first.rb")
      second = File.join(dir, "second.rb")
      File.write(first, "module Example; VALUE = 1; end\n")
      File.write(second, "module Example; NEXT_VALUE = VALUE + 1; end\n")

      namespace = described_class.load(files: [first, second])

      expect(namespace.const_get(:Example).const_get(:NEXT_VALUE)).to eq(2)
    end
  end

  it "loads paths relative to a supplied root" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "relative.rb"), "module RelativeExample; VALUE = 7; end\n")

      namespace = described_class.load(files: "relative.rb", root: dir)

      expect(namespace.const_get(:RelativeExample).const_get(:VALUE)).to eq(7)
    end
  end

  it "raises when an explicit file is missing" do
    Dir.mktmpdir do |dir|
      expect do
        described_class.load(files: "missing.rb", root: dir)
      end.to raise_error(AnonymousLoader::FileNotFoundError)
    end
  end

  it "resolves an explicit file path" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "explicit.rb")
      File.write(path, "module ExplicitExample; end\n")

      expect(described_class.resolve_path(path: path)).to eq(path)
    end
  end

  it "resolves a file from loaded gem metadata" do
    path = described_class.resolve_path(
      gem_name: "anonymous_loader",
      require_path: "anonymous_loader.rb",
      version_requirement: ">= 0"
    )

    expect(path).to end_with("lib/anonymous_loader.rb")
  end

  it "resolves a load path file without a version requirement" do
    Dir.mktmpdir do |dir|
      lib = File.join(dir, "lib")
      FileUtils.mkdir_p(File.join(lib, "plain"))
      File.write(File.join(lib, "plain", "loader.rb"), "module PlainLoader; VALUE = true; end\n")

      $LOAD_PATH.unshift(lib)
      begin
        namespace = described_class.load_path(require_path: "plain/loader.rb")
      ensure
        $LOAD_PATH.delete(lib)
      end

      expect(namespace.const_get(:PlainLoader).const_get(:VALUE)).to be(true)
    end
  end

  it "resolves a load path file and validates an adjacent version file" do
    Dir.mktmpdir do |dir|
      lib = File.join(dir, "lib")
      FileUtils.mkdir_p(File.join(lib, "example"))
      FileUtils.mkdir_p(File.join(lib, "example_loader"))
      File.write(File.join(lib, "example", "version.rb"), "module Example; VERSION = \"1.2.3\"; end\n")
      File.write(File.join(lib, "example_loader", "loader.rb"), "module ExampleLoader; VALUE = true; end\n")

      $LOAD_PATH.unshift(lib)
      begin
        namespace = described_class.load_path(
          require_path: "example_loader/loader.rb",
          version_requirement: "~> 1.2",
          version_file: "example/version.rb"
        )
      ensure
        $LOAD_PATH.delete(lib)
      end

      expect(namespace.const_get(:ExampleLoader).const_get(:VALUE)).to be(true)
    end
  end

  it "validates a load path file when the require path and version file have different depths" do
    Dir.mktmpdir do |dir|
      lib = File.join(dir, "lib")
      FileUtils.mkdir_p(File.join(lib, "auth", "sanitizer"))
      FileUtils.mkdir_p(File.join(lib, "auth_sanitizer"))
      File.write(File.join(lib, "auth", "sanitizer", "version.rb"), "module Auth; module Sanitizer; VERSION = \"0.2.2\"; end; end\n")
      File.write(File.join(lib, "auth_sanitizer", "loader.rb"), "module AuthSanitizer; module Loader; VALUE = true; end; end\n")

      $LOAD_PATH.unshift(lib)
      begin
        namespace = described_class.load_path(
          require_path: "auth_sanitizer/loader.rb",
          version_requirement: "~> 0.2",
          version_file: "auth/sanitizer/version.rb"
        )
      ensure
        $LOAD_PATH.delete(lib)
      end

      expect(namespace.const_get(:AuthSanitizer).const_get(:Loader).const_get(:VALUE)).to be(true)
    end
  end

  it "does not use a versioned load path file when the adjacent version file is missing" do
    Dir.mktmpdir do |dir|
      lib = File.join(dir, "lib")
      FileUtils.mkdir_p(File.join(lib, "example_loader"))
      File.write(File.join(lib, "example_loader", "loader.rb"), "module ExampleLoader; end\n")

      $LOAD_PATH.unshift(lib)
      begin
        expect do
          described_class.load_path(
            require_path: "example_loader/loader.rb",
            version_requirement: "~> 1.2",
            version_file: "example/version.rb"
          )
        end.to raise_error(AnonymousLoader::FileNotFoundError)
      ensure
        $LOAD_PATH.delete(lib)
      end
    end
  end

  it "does not use a versioned load path file when the adjacent version is invalid" do
    Dir.mktmpdir do |dir|
      lib = File.join(dir, "lib")
      FileUtils.mkdir_p(File.join(lib, "example"))
      FileUtils.mkdir_p(File.join(lib, "example_loader"))
      File.write(File.join(lib, "example", "version.rb"), "module Example; VERSION = \"bad version\"; end\n")
      File.write(File.join(lib, "example_loader", "loader.rb"), "module ExampleLoader; end\n")

      $LOAD_PATH.unshift(lib)
      begin
        expect do
          described_class.load_path(
            require_path: "example_loader/loader.rb",
            version_requirement: "~> 1.2",
            version_file: "example/version.rb"
          )
        end.to raise_error(AnonymousLoader::FileNotFoundError)
      ensure
        $LOAD_PATH.delete(lib)
      end
    end
  end

  it "rejects a load path file when the adjacent version is outside the requirement" do
    Dir.mktmpdir do |dir|
      lib = File.join(dir, "lib")
      FileUtils.mkdir_p(File.join(lib, "example"))
      FileUtils.mkdir_p(File.join(lib, "example_loader"))
      File.write(File.join(lib, "example", "version.rb"), "module Example; VERSION = \"2.0.0\"; end\n")
      File.write(File.join(lib, "example_loader", "loader.rb"), "module ExampleLoader; end\n")

      $LOAD_PATH.unshift(lib)
      begin
        expect do
          described_class.load_path(
            require_path: "example_loader/loader.rb",
            version_requirement: "~> 1.2",
            version_file: "example/version.rb"
          )
        end.to raise_error(AnonymousLoader::VersionMismatchError)
      ensure
        $LOAD_PATH.delete(lib)
      end
    end
  end

  it "raises when a require path cannot be resolved" do
    expect do
      described_class.resolve_path(require_path: "anonymous_loader/not_here.rb")
    end.to raise_error(AnonymousLoader::FileNotFoundError)
  end
end
