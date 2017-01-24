require 'rubygems'

begin
    require 'bundler'
    Bundler.require
rescue LoadError
    puts 'No Bundler available'
end

require './tracker.rb'

# Application configuration
config = {
    translation: 'ru',
    repository_type: 'mongo',
    repository_config: {
        host: '127.0.0.1',
        port: 27017,
        db_name: 'tracker'
    }
}
run TrackerApp.new(config)
