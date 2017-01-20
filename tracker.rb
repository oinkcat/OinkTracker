#!/bin/env ruby

require 'sinatra/base'
require 'json'

require './model.rb'
require './file_repository.rb'
require './translation.rb'

# Simple tracker Sinatra class
class TrackerApp < Sinatra::Base

    include TrackerModel

    LANGUAGE = 'ru'
    ID_FIELD = 'login'
    
    use Rack::Session::Pool, :expire_after => 86400
    
    # Check user authentiction
    before do
        for_guest = ['/enter/', '/auth_error', '/no_auth']
        if session['login'] == nil
            query = request.path_info
            if for_guest.none? { |path| query.start_with? path } then
                redirect '/no_auth'
            end
        end
    end
    
    # Get JSON output response
    def json_response(obj)
        content_type 'application/json'
        JSON.dump obj
    end
    
    # Get JSON POST data
    def json_data()
        JSON.load request.body
    end
    
    # Authenticate user
    get '/enter/:token?' do |token|
        user = Repository.get_user_by_token(token)
        if user != nil then
            session['login'] = user.login
            session['role'] = user.role
            redirect '/'
        else
            redirect '/auth_error'
        end
    end
    
    # Authentication required message
    get '/no_auth' do
        erb :auth_error, :locals => { :login_error => false }
    end
    
    # Authentication error
    get '/auth_error' do
        erb :auth_error, :locals => { :login_error => true }
    end
    
    # Get main page
    get '/' do
        user = User.from_json(session)
        erb :index, :locals => {
            :login => user.login,
            :is_dev => user.is_developer?
        }
    end
    
    # Project info
    get '/projects' do
        all_projects = Repository.get_projects
        proj_array = all_projects.map { |p| p.to_json }
        
        json_response proj_array
    end
    
    # Project by id
    get '/project/:id' do
        proj_id = params['id'].to_i
        proj_info = Repository.get_project proj_id
        
        json_response proj_info.to_json
    end
    
    # Tickets list
    get '/tickets/:cat_id/:status' do
        cat_id = params['cat_id'].to_i
        stat = params['status'].to_i
        tickets = Repository.get_tickets cat_id, stat
        tickets_info = tickets.map { |t| t.to_json }
        
        json_response tickets_info
    end
    
    # Change ticket progress
    post '/ticket_progress' do
        data = json_data()
        ticket_id = data['id'].to_i
        new_progress = data['progress'].to_i
        
        ticket = Repository.get_ticket ticket_id
        ticket.progress = new_progress
        Repository.update_ticket ticket
        
        json_response :ok => true
    end
    
    # Confirm ticket as done by manager
    post '/confirm_ticket' do
        data = json_data()
        ticket_id = data['id'].to_i
        
        ticket = Repository.get_ticket ticket_id
        ticket.confirm
        Repository.update_ticket ticket
        
        json_response :ok => true
    end
    
    # Add new ticket
    post '/save_ticket' do
        data = json_data()
        new_ticket = Ticket.new()
        new_ticket.text = data['text']
        new_ticket.priority = data['priority']
        new_ticket.status = data['status']
        new_ticket.progress = data['progress']
        new_ticket.cat_id = data['category_id'].to_i
        Repository.add_ticket new_ticket
        
        json_response :ok => true
    end
    
    # Update ticket
    put '/save_ticket' do
        data = json_data()
        ticket = Repository.get_ticket data['id']
        ticket.text = data['text']
        ticket.priority = data['priority']
        ticket.status = data['status']
        Repository.update_ticket ticket
        
        json_response :ok => true
    end
    
    # Remove ticket
    delete '/remove_ticket/:id' do
        id = params['id'].to_i
        Repository.remove_ticket id
        
        json_response :ok => true
    end
    
    # error 500 do
    #     'Error occured!'
    # end
    
    not_found do
        content_type 'text/plain'
        
        '404 - Not found'
    end
    
    Translation.init_for_language LANGUAGE
end

# Entry point
if ENV['OPENSHIFT_APP_NAME'] == nil then
    TrackerApp.run!
end
