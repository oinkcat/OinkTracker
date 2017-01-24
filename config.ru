require 'rubygems'

begin
	require 'bundler'
	Bundler.require
rescue LoadError
	puts 'No Bundler available'
end

require './tracker.rb'
run TrackerApp.new
