begin
  require 'progressbar'
rescue LoadError
end
namespace :trackzor_merge do
  MERGE_TABLE_SUFFIX = "_for_merge"

  task :dump do
    raise ArgumentError, "must provide TABLE to dump" unless ENV['TABLE']
    config = YAML::load(File.open("#{RAILS_ROOT}/config/database.yml"))
    sub_file = "#{RAILS_ROOT}/tmp/#{ENV['TABLE']}#{MERGE_TABLE_SUFFIX}.sql"
    system "mysqldump --user=#{config[RAILS_ENV]['username']} --password=#{config[RAILS_ENV]['password']} #{config[RAILS_ENV]['database']} #{ENV['TABLE']} > #{sub_file}_1"
    system "sed 's/`#{ENV['TABLE']}`/`#{ENV['TABLE']}#{MERGE_TABLE_SUFFIX}`/g' #{sub_file}_1 > #{sub_file}_2"
    system "sed 's/AUTO_INCREMENT,/,/g' #{sub_file}_2 > #{sub_file}_3"
    system "sed 's/AUTO_INCREMENT=[0-9]*//g' #{sub_file}_3 > #{sub_file}_4"
    system "sed 's/KEY `/KEY `merge_/g' #{sub_file}_4 > #{sub_file}"
    system "rm #{sub_file}_*"
    puts sub_file
  end

  task :load => :environment do
    raise ArgumentError, "must provide target CLASS to merge into, FILE for sql dump, unique identifying columns (comma-separated) assumed to be id unless COLUMN is set" unless ENV['CLASS'] && ENV['FILE']

    cols = (ENV['COLUMN'] || 'id').split(',')
    model = ENV['CLASS'].camelize.constantize
    merge_model = model.clone
    merge_model.table_name = model.table_name + MERGE_TABLE_SUFFIX

    unless ENV['SKIP_SQL_LOAD'].to_s == "1"
      print "Loading merge tables... "
      config = YAML::load(File.open("#{RAILS_ROOT}/config/database.yml"))
      system "mysql --user=#{config[RAILS_ENV]['username']} --password=#{config[RAILS_ENV]['password']} #{config[RAILS_ENV]['database']} < #{ENV['FILE']}"
      puts "done."
    end

    if !model.respond_to?('merge_with')
      # include trackzor without tracked columns
      model.trackzored :only => ['']
    end

    find_method = "find_by_#{cols.join('_and_')}".to_sym

    pbar = ProgressBar.new(ENV['CLASS'], merge_model.count)

    records_merged = 0
    records_created = 0

    merge_model.find(:all).each do |record_to_merge|
      find_params = cols.collect{|c| record_to_merge.send(c.to_sym) }

      if record = model.send(find_method, *find_params)
        record.merge_with(record_to_merge)
        records_merged += 1
      else
        for_log = []
        new_record = model.new(record_to_merge.attributes)
        # set unique id expliciting in case it's the PK
        cols.each do |c|
          new_record.send("#{c}=".to_sym, record_to_merge.send(c.to_sym))
          for_log << c
        end
        new_record.send(:create_without_callbacks)
        records_created += 1
      end

      pbar.inc
    end
    pbar.finish

    puts "Records merged: #{records_merged}"
    puts "Records created: #{records_created}"
  end
end
