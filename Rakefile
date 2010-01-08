require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new('trackzor', '0.1.0') do |gem|
  gem.description = "Track ATTR_updated_at and ATTR_updated_by with ease."
  gem.url = "http://bitbucket.org/corneldm/trackzor"
  gem.author = "David Cornelius"
  gem.email  = "david.cornelius@bluefishwireless.net"
  gem.ignore_pattern = ["tmp/*", "script/*"]
  gem.development_dependencies = []
end

Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each { |ext| load ext }
