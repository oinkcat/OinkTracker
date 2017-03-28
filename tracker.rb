#!/bin/env ruby

require 'sinatra/base'
require 'json'

require './model.rb'
require './file_repository.rb'
require './mongo_repository.rb'
require './translation.rb'
require './view_utils.rb'

# Simple tracker Sinatra class
class TrackerApp < Sinatra::Base

    include TrackerModel
    
    use Rack::Session::Cookie, :expire_after => 86400,
                               :secret => '28e2f1bc755ed3ca'
    
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
    
    # Get currently signed in user
    def current_user
        if session['login'] != nil then
            User.new(session['login'], session['role'])
        else
            nil
        end
    end
    
    # Log last user action
    def log_action(action)
        @repository.put_last_action action
    end
    
    # Authenticate user
    get '/enter/:token?' do |token|
        user = @repository.get_user_by_token(token)
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
        all_projects = @repository.get_projects
        proj_array = all_projects.map { |p| p.to_json }
        
        json_response proj_array
    end
    
    # Project by id
    get '/project/:id' do
        proj_id = params['id'].to_i
        proj_info = @repository.get_project proj_id
        
        json_response proj_info.to_json
    end
    
    # Tickets list
    get '/tickets/:cat_id/:status' do
        cat_id = params['cat_id'].to_i
        stat = params['status'].to_i
        tickets = @repository.get_tickets cat_id, stat
        tickets_info = tickets.map { |t| t.to_json }
        
        json_response tickets_info
    end
    
    # Last actions of users
    get '/last_actions' do
        actions = @repository.get_last_actions
        actions_array = actions.map { |a| a.to_json true }
        
        json_response actions_array
    end
    
    # Change ticket progress
    post '/ticket_progress' do
        data = json_data()
        ticket_id = data['id'].to_i
        new_progress = data['progress'].to_i
        
        ticket = @repository.get_ticket ticket_id
        ticket.progress = new_progress
        @repository.update_ticket ticket
        
        # Log action
        log_action Action::ProgressChanged(ticket, current_user)
        
        json_response :ok => true
    end
    
    # Confirm ticket as done by manager
    post '/confirm_ticket' do
        data = json_data()
        ticket_id = data['id'].to_i
        
        ticket = @repository.get_ticket ticket_id
        ticket.confirm!
        @repository.update_ticket ticket
        
        # Log action
        log_action Action::TicketConfirmed(ticket, current_user)
        
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
        new_ticket.tags = data['tags']
        @repository.add_ticket new_ticket
        
        # Log action
        log_action Action::TicketAdded(new_ticket, current_user)
        
        json_response :ok => true
    end
    
    # Update ticket
    put '/save_ticket' do
        data = json_data()
        ticket = @repository.get_ticket data['id']
        ticket.text = data['text']
        ticket.priority = data['priority']
        ticket.status = data['status']
        ticket.tags = data['tags']
        @repository.update_ticket ticket
        
        # Log action
        log_action Action::TicketModified(ticket, current_user)
        
        json_response :ok => true
    end
    
    # Remove ticket
    delete '/remove_ticket/:id' do
        id = params['id'].to_i
        ticket_to_remove = @repository.get_ticket id
        @repository.remove_ticket id
        
        # Log action
        log_action Action::TicketRemoved(ticket_to_remove, current_user)
        
        json_response :ok => true
    end
    
    # Post ticket comment
    post '/new_comment' do
        data = json_data()
        
        # Add new comment to the ticket
        ticket_to_comment = @repository.get_ticket data['ticket_id']
        comment_text = Rack::Utils.escape_html(data['text'])
        ticket_to_comment.add_comment current_user, comment_text
        @repository.update_ticket ticket_to_comment
        
        new_comment = ticket_to_comment.comments.last
        
        json_response new_comment.to_json
    end
    
    not_found do
        content_type 'text/plain'
        
        '404 - Not found'
    end
    
    # Application instance initialization
    def initialize(config)
        super()
        
        # Select and initialize data repository
        case config[:repository_type]
            when 'mongo'
                @repository = MongoRepository
            when 'file'
                @repository = FileRepository
            else
                raise StandardError, "Unknown repository type!"
        end
        @repository.Initialize config[:repository_config]
        
        # Load translated strings
        Translation.init_for_language config[:translation]
    end
    
end
