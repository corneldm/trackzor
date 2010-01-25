namespace :trackzor_merge do
  MERGE_TABLE_SUFFIX = "_for_merge"

  task :dump do
    raise ArgumentError, "must provide TABLE to dump, id is assumed PK unless TABLE_PK is set" unless ENV['TABLE']
    pk = ENV['TABLE_PK'] || 'id'
    config = YAML::load(File.open("#{RAILS_ROOT}/config/database.yml"))
    sub_file = "#{RAILS_ROOT}/tmp/#{ENV['TABLE']}#{MERGE_TABLE_SUFFIX}.sql"
    system "mysqldump --user=#{config[RAILS_ENV]['username']} --password=#{config[RAILS_ENV]['password']} #{config[RAILS_ENV]['database']} #{ENV['TABLE']} > #{sub_file}_1"
    system "sed 's/`#{ENV['TABLE']}`/`#{ENV['TABLE']}#{MERGE_TABLE_SUFFIX}`/g' #{sub_file}_1 > #{sub_file}_2"
    system "sed 's/PRIMARY KEY (`#{pk}`),/PRIMARY KEY (`#{pk}`)/g' #{sub_file}_2 > #{sub_file}_3"
    system "grep -Ev 'index_#{ENV['TABLE']}_on' #{sub_file}_3 > #{sub_file}"
    system "rm #{sub_file}_*"
    puts sub_file
  end

  task :load => :environment do
    raise ArgumentError, "must provide target CLASS to merge into, FILE for sql dump, unique identifying column assumed to be id unless COLUMN is set" unless ENV['CLASS'] && ENV['FILE']

    col = ENV['COLUMN'].downcase || 'id'
    model = ENV['CLASS'].camelize.constantize
    merge_model = model.clone
    merge_model.table_name += MERGE_TABLE_SUFFIX

    config = YAML::load(File.open("#{RAILS_ROOT}/config/database.yml"))
    system "mysql --user=#{config[RAILS_ENV]['username']} --password=#{config[RAILS_ENV]['password']} #{config[RAILS_ENV]['database']} < #{ENV['FILE']}"
    
    merge_model.find(:all).each do |record_to_merge|
      if record = model.send("find_by_#{col}".to_sym, record_to_merge.send(col.to_sym))
        record.merge_with(record_to_merge)
      else
        new_record = model.new(record_to_merge.attributes)
        # set unique id expliciting in case it's the PK
        new_record.send("#{col}=".to_sym, record_to_merge.send(col.to_sym))
        new_record.send(:create_without_callbacks)
        puts "Created #{new_record.send(col.to_sym)}"
      end
    end
  end
end
