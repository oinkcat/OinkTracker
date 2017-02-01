# file_repository.rb
# Data repository based on plain JSON files
#  

require 'json'

module TrackerModel

    module FileRepository
    
        ProjectsData = './test_data/projects.json'
        TicketsData = './test_data/tickets.json'
        UsersData = './test_data/users.json'
        ActionsData = './test_data/actions.json'
        
        NumOfActions = 20
    
        # Get all projects info
        def self.get_projects
            proj_records = read_json_file(ProjectsData)
            
            proj_records.map { |r| Project.from_json r }
        end
        
        # Get project info by id
        def self.get_project(id)
            proj_records = read_json_file(ProjectsData)
            matched_proj = proj_records.select { |r| r['id'] == id }
            
            if matched_proj.length > 0
                Project.from_json matched_proj.first
            else
                nil
            end
        end
        
        # Get tickets in given category with certain status
        def self.get_tickets(category_id, status)
            ticket_records = read_json_file(TicketsData)
            get_confirmed = status == Ticket::Confirmed
            
            requested_records = ticket_records.select do |r|
                r['category_id'] == category_id &&
                get_confirmed ^ (r['status'] < Ticket::Confirmed)
            end
            
            tickets = requested_records.map { |r| Ticket.from_json r }
            
            # Check for expired tickets
            if !get_confirmed then
                expired_tickets = tickets.select { |t| t.expired? }
                expired_tickets.each do |t|
                    update_ticket t
                end
                # Remove expired tickets from query result
                tickets.reject! { |t| t.expired? }
            end
            
            return tickets
        end
        
        # Get ticket by id
        def self.get_ticket(id)
            ticket_records = read_json_file(TicketsData)
            matched_ticket = ticket_records.select { |r| r['id'] == id }
            
            if matched_ticket.length > 0
                Ticket.from_json matched_ticket.first
            else
                nil
            end
        end
        
        # Add new ticket
        def self.add_ticket(ticket)
            ticket_records = read_json_file(TicketsData)
            
            # Set new item's id
            max_record = ticket_records.max_by { |r| r['id'].to_i }
            ticket.id = max_record.nil? ? 1 : max_record['id'] + 1
            ticket_records << ticket.to_json
            
            # Dump tickets to file
            save_json_file TicketsData, ticket_records
        end
        
        # Update ticket data
        def self.update_ticket(ticket)
            ticket_records = read_json_file(TicketsData)        
            
            # Update json record
            item_idx = ticket_records.find_index do |r|
                r['id'] == ticket.id
            end
            ticket_records[item_idx] = ticket.to_json
            
            # Dump tickets to file
            save_json_file TicketsData, ticket_records
        end
        
        # Remove ticket by id
        def self.remove_ticket(id)
            ticket_records = read_json_file(TicketsData)
            ticket_records.delete_if { |r| r['id'] == id }
            
            # Dump tickets to file
            save_json_file TicketsData, ticket_records
        end
        
        # Get user by identifier
        def self.get_user_by_login(login)
            get_user_by { |r| r['login'] == login }
        end
        
        # Get user by access token
        def self.get_user_by_token(token)
            get_user_by { |r| r['token'] == token }
        end
        
        # Get list of N last user actions
        def self.get_last_actions
            action_records = read_json_file(ActionsData)
            
            action_records.map { |r| Action::from_json r }
        end
        
        # Put new last action
        def self.put_last_action(action)            
            action_records = read_json_file(ActionsData)
            
            # Determine if we can overwrite last action
            recent_record = action_records[0]
            if !recent_record.nil? then
                most_recent = Action::from_json(recent_record)
                if most_recent == action then
                    action_records.delete_at 0
                end
            end
            
            # Prepend new action to list
            action_records.unshift action.to_json
            n_records = action_records[0, NumOfActions]
            
            # Dump records to file
            save_json_file ActionsData, n_records
        end
        
        # Initialization
        def self.Initialize(config)
        end
        
        private
        
        # Get user info by predicate
        def self.get_user_by(&pred)
            user_records = read_json_file(UsersData)
            matched = user_records.select { |r| pred.call(r) }
            
            if matched.length > 0 then
                User.from_json matched.first
            else
                nil
            end
        end
        
        # Read file and parse contents to JSON
        def self.read_json_file(filepath)
            File.open(filepath) do |f|
                contents = f.read()
                return JSON.parse(contents)
            end
        end
        
        # Save tickets
        def self.save_json_file(filepath, records)
            File.open(filepath, 'w') do |f|
                f.write(JSON.pretty_generate(records))
            end
        end
    end
    
end
