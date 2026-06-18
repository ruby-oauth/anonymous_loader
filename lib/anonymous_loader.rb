# frozen_string_literal: true

require "version_gem"

require_relative "anonymous_loader/version"

# Loads Ruby source under anonymous modules to avoid top-level namespace collisions.
module AnonymousLoader
  # Raised for anonymous loader failures.
  class Error < StandardError; end
  # Raised when a requested Ruby source file cannot be resolved.
  class FileNotFoundError < Error; end
  # Raised when a resolved load-path candidate does not match the requested version.
  class VersionMismatchError < Error; end

  # Internal normalized resolver request.
  # @api private
  PathRequest = Struct.new(:path, :gem_name, :require_path, :requirement, :version_file)
  # Internal load-path version lookup request.
  # @api private
  VersionRequest = Struct.new(:candidate, :require_path, :version_file)

  class << self
    # Evaluate one or more Ruby files inside a fresh anonymous module.
    #
    # The source's natural constant nesting is preserved inside the anonymous
    # module. For example, a file declaring `module Auth; module Sanitizer; end`
    # becomes `anonymous_namespace::Auth::Sanitizer`, not `Object::Auth`.
    #
    # @param files [String, Array<String>] absolute paths, or paths relative to root
    # @param root [String, nil] optional root for relative paths
    # @return [Module] anonymous namespace containing the evaluated source
    def load(files:, root: nil, **_options)
      namespace = Module.new
      Array(files).each do |file|
        path = expand_file(file, root)
        namespace.module_eval(File.read(path), path, 1)
      end
      namespace
    end

    # Resolve and anonymously load a single file.
    #
    # @param options [Hash] resolver options
    # @option options [String, nil] :path explicit file path
    # @option options [String, nil] :gem_name gem name used for RubyGems lookup
    # @option options [String, nil] :require_path path under lib, also used for $LOAD_PATH lookup
    # @option options [String, Gem::Requirement, nil] :version_requirement accepted gem version
    # @option options [String, nil] :version_file file next to require_path's load root that declares VERSION
    # @return [Module] anonymous namespace containing the evaluated source
    def load_path(**options)
      load(files: resolve_path(**options))
    end

    # Resolve a file from an explicit path, RubyGems metadata, or $LOAD_PATH.
    #
    # RubyGems metadata is preferred when available. The $LOAD_PATH fallback
    # supports Bundler standalone setups where files are loadable but the
    # dependency is absent from Gem.loaded_specs and GEM_PATH.
    #
    # @param options [Hash] resolver options
    # @option options [String, nil] :path explicit file path
    # @option options [String, nil] :gem_name gem name used for RubyGems lookup
    # @option options [String, nil] :require_path path under lib, also used for $LOAD_PATH lookup
    # @option options [String, Gem::Requirement, nil] :version_requirement accepted gem version
    # @option options [String, nil] :version_file file next to require_path's load root that declares VERSION
    # @return [String] absolute path to the resolved file
    def resolve_path(**options)
      request = path_request(options)
      resolved = explicit_path_for(request) || resolve_from_gemspec(request) || resolve_from_load_path(request)
      return resolved if resolved

      raise FileNotFoundError, unresolved_message(request)
    end

    private

    def path_request(options)
      version_requirement = options[:version_requirement]
      PathRequest.new(
        options[:path],
        options[:gem_name],
        options[:require_path],
        version_requirement && Gem::Requirement.create(version_requirement),
        options[:version_file]
      )
    end

    def explicit_path_for(request)
      path = request.path
      expand_file(path, nil) if path
    end

    def unresolved_message(request)
      "could not resolve #{request.require_path.inspect} from #{request.gem_name || "load path"}"
    end

    def expand_file(file, root)
      path = (root && !absolute_path?(file)) ? File.expand_path(file, root) : File.expand_path(file)
      raise FileNotFoundError, "file not found: #{path}" unless File.file?(path)

      path
    end

    def absolute_path?(path)
      path.start_with?(File::SEPARATOR) || !!(File::ALT_SEPARATOR && path.start_with?(File::ALT_SEPARATOR))
    end

    def resolve_from_gemspec(request)
      candidate = gemspec_candidate(request)
      candidate if candidate && File.file?(candidate)
    end

    def gemspec_candidate(request)
      return nil unless gemspec_request_complete?(request)

      spec = matching_spec(request.gem_name, request.requirement)
      spec && File.join(spec.full_gem_path, "lib", request.require_path)
    end

    def gemspec_request_complete?(request)
      request.gem_name && request.require_path
    end

    def matching_spec(gem_name, requirement)
      spec = Gem.loaded_specs[gem_name]
      spec = find_spec(gem_name, requirement) if !spec || spec_version_mismatch?(spec, requirement)
      spec
    end

    def spec_version_mismatch?(spec, requirement)
      requirement && !requirement.satisfied_by?(spec.version)
    end

    def find_spec(gem_name, requirement)
      if requirement
        Gem::Specification.find_by_name(gem_name, requirement)
      else
        Gem::Specification.find_by_name(gem_name)
      end
    rescue Gem::MissingSpecError
      nil
    end

    def resolve_from_load_path(request)
      resolve_load_path_candidates(load_path_candidates_for(request), request)
    end

    def load_path_candidates_for(request)
      require_path = request.require_path
      return [] unless require_path

      load_path_candidates(require_path)
    end

    def resolve_load_path_candidates(candidates, request)
      return nil if candidates.empty?
      return candidates.first unless request.requirement

      resolve_versioned_load_path(candidates, request)
    end

    def load_path_candidates(require_path)
      Gem.find_files(require_path).select { |candidate| File.file?(candidate) }
    end

    def resolve_versioned_load_path(candidates, request)
      versions = load_path_versions(candidates, request)
      match = versions.find { |pair| request.requirement.satisfied_by?(pair.last) }
      return match.first if match

      raise_load_path_version_mismatch(request, versions.map(&:last))
    end

    def load_path_versions(candidates, request)
      candidates.each_with_object([]) do |candidate, versions|
        version = version_for_load_path_candidate(VersionRequest.new(candidate, request.require_path, request.version_file))
        versions << [candidate, version] if version
      end
    end

    def raise_load_path_version_mismatch(request, mismatched_versions)
      return nil if mismatched_versions.empty?

      raise VersionMismatchError,
        "#{request.require_path.inspect} did not satisfy #{request.requirement}; found #{mismatched_versions.uniq.join(", ")}"
    end

    def version_for_load_path_candidate(request)
      version_path = existing_version_file(request)
      gem_version_for(version_path) if version_path
    rescue ArgumentError
      nil
    end

    def existing_version_file(request)
      return nil unless request.version_file

      version_path = load_path_version_file(request)
      version_path if File.file?(version_path)
    end

    def load_path_version_file(request)
      File.expand_path(request.version_file, load_path_root(request))
    end

    def gem_version_for(version_path)
      version_string = version_string_for(version_path)
      Gem::Version.new(version_string) if version_string
    end

    def version_string_for(version_path)
      source = File.read(version_path)
      # This fallback only runs when RubyGems metadata is unavailable; the
      # supported version file contract is a simple string VERSION assignment.
      match = source.match(/VERSION\s*=\s*(["'])([^"']+)\1/)
      match[2] if match
    end

    def load_path_root(request)
      candidate_dir = File.dirname(request.candidate)
      require_depth = request.require_path.split("/").length - 1
      require_depth.times { candidate_dir = File.dirname(candidate_dir) }
      candidate_dir
    end
  end
end

AnonymousLoader::Version.class_eval do
  extend VersionGem::Basic
end
