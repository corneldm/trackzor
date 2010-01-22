# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{trackzor}
  s.version = "0.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["David Cornelius"]
  s.date = %q{2010-01-22}
  s.description = %q{Track ATTR_updated_at and ATTR_updated_by}
  s.email = %q{david.cornelius@bluefishwireless.net}
  s.extra_rdoc_files = ["CHANGELOG", "README.rdoc", "lib/trackzor.rb"]
  s.files = ["CHANGELOG", "Manifest", "README.rdoc", "Rakefile", "generators/trackzor_migration/templates/migration.rb", "generators/trackzor_migration/trackzor_migration_generator.rb", "init.rb", "lib/trackzor.rb", "trackzor.gemspec"]
  s.homepage = %q{http://github.com/corneldm/trackzor}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Trackzor", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{trackzor}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Track ATTR_updated_at and ATTR_updated_by}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
