# file_repository.rb
# MongoDB based data repository
#  

require 'mongo'

module TrackerModel

    module MongoRepository
        
        # Get all projects info
        def self.get_projects
            projects_bson = get_context()[:projects].find
            projects_bson.map { |doc| Project.from_json doc }
        end
        
        # Get project info by id
        def self.get_project(id)
            proj_bson = get_context()[:projects].find(:id => id).first
            Project.from_json proj_bson
        end
        
        # Get tickets in given category with certain status
        def self.get_tickets(category_id, status)
            # Array of statuses to query
            statuses_match = Array.new()
            if status == Ticket::Confirmed then
                statuses_match << Ticket::Confirmed
            else
                statuses_match << Ticket::Active
                statuses_match << Ticket::Done
            end
            
            tickets_bson = get_context()[:tickets].find('$and' => [
                { :category_id => category_id },
                { :status => { '$in' => statuses_match } }
            ])
            tickets = tickets_bson.map { |doc| Ticket.from_json doc }
            
            # Check for expired tickets
            if status != Ticket::Confirmed then
                expired_tickets = tickets.select { |t| t.expired? }
                expired_tickets.each { |t| update_ticket t }
                # Remove expired tickets from query result
                tickets.reject! { |t| t.expired? }
            end
            
            return tickets
        end
        
        # Get ticket by id
        def self.get_ticket(id)
            ticket_bson = query_ticket(id).first
            Ticket.from_json ticket_bson
        end
        
        # Add new ticket
        def self.add_ticket(ticket)
            # Get the ticket id
            collection = get_context()[:tickets]
            group_result = collection.aggregate([{'$group' => {
                '_id' => 'id', 'max' => { '$max' => '$id' }
            }}]).first
            next_id = group_result.nil? ? 1 : group_result['max'] + 1
            ticket.id = next_id
            collection.insert_one(ticket.to_json)
        end
        
        # Update ticket data
        def self.update_ticket(ticket)
            query_ticket(ticket.id).update_one(ticket.to_json)
        end
        
        # Remove ticket by id
        def self.remove_ticket(id)
            query_ticket(id).delete_one
        end
        
        # Get user by identifier
        def self.get_user_by_login(login)
            query_user_by_field 'login', login
        end
        
        # Get user by access token
        def self.get_user_by_token(token)
            query_user_by_field 'token', token
        end
        
        # Initialization
        def self.Initialize(config)
            @@mongo_uri = "mongodb://#{config[:host]}:#{config[:port]}"
            @@options = {
                :database => config[:db_name],
                :user => config[:user],
                :password => config[:password]
            }
        end
        
        private
        
        # Query ticket BSON by id
        def self.query_ticket(id)
            get_context()[:tickets].find(:id => id)
        end
        
        # Query user data by specified field
        def self.query_user_by_field(field, value)
            found_users = get_context()[:users].find(field => value).to_a
            if found_users.length > 0 then
                User.from_json found_users.first
            else
                nil
            end
        end
        
        # Get new connection to MongoDb
        def self.get_context
            connection = Mongo::Client.new(@@mongo_uri, @@options)
            return connection.database
        end
        
        # Disable debug logs output
        Mongo::Logger.logger.level = Logger::WARN
    end
    
end
