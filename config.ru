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
    :translation => 'en',
    :repository_type => 'file',
    # For MongoDB only
    :repository_config => {
        :host => '127.0.0.1',
        :port => 27017,
        :db_name => 'tracker',
        :user => nil,
        :password => nil
    }
}
run TrackerApp.new(config)
