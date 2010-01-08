class TrackzorMigrationGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.migration_template 'migration.rb', 'db/migrate', {:migration_file_name => "trackzorify_#{table_name}"}
    end
  end
end
