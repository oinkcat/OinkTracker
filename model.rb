# Tickets tracker data model

require 'time'
require './translation.rb'

module TrackerModel

    # Aux utilities
    module Utils
        DateFormat = '%d.%m.%Y'

        def self.generate_id(strong = false)
            rnd = Random.new
            (rnd.rand * 10000).to_i
        end
            
        def self.get_date(value)
            value != nil ? Date.strptime(value, DateFormat) : nil
        end
    
        # Format date as string
        def self.date_string(value)
            value != nil ? value.strftime(DateFormat) : nil
        end
    end

    # Project
    class Project
        attr_accessor :id, :name, :started_at
        attr_reader :categories
        
        # Fill project info from JSON data
        def self.from_json(json)
            new_proj = self.new
            
            new_proj.id = json['id']
            new_proj.name = json['name']
            new_proj.started_at = Utils.get_date(json['ts'])
            new_proj.fill_categories json['categories']
            
            new_proj
        end
        
        # Get JSON data output
        def to_json
            {
                'id' => @id, 'name' => @name, 'ts' => nil,
                'categories' => @categories.map { |c| c.to_json }
            }
        end
    
        def initialize
            @id = nil
            @name = nil
            @started_at = nil
            @categories = Array.new
        end
        
        # Fill categories info from JSON data
        def fill_categories json
            json.each do |cat_json|
                @categories << Category.from_json(cat_json)
            end
        end
        
        def inspect
            info = Array.new
            info << "#{@name} (#{@id})"
            info << 'Categories:'
            
            @categories.each do |cat|
                info << "* #{cat.name}"
            end
            
            info.join "\n"
        end
    end
    
    # Tickets category
    class Category
        Tasks = 0
        Bugs = 1
        
        attr_accessor :id, :name, :type
        attr_reader :active_count
        attr_reader :done_count
        
        # Fill from JSON data
        def self.from_json(json)
            new_cat = self.new
            
            new_cat.id = json['id']
            new_cat.name = json['name']
            new_cat.type = json['type']
            
            new_cat
        end
        
        # Get JSON data output
        def to_json
            {
                'id' => @id, 'name' => @name, 'type' => @type,
                'statuses' => [tr(:active), tr(:done)],
                'active_count' => @active_count,
                'done_count' => @done_count
            }
        end
    
        def tickets_count
            @active_count + @done_count
        end
    
        def initialize
            @id = nil
            @name = nil
            @type = Tasks
            
            # Ticket counts by status (TODO later)
            @active_count = 0
            @done_count = 0
        end
    end
    
    # Ticket or bug
    class Ticket
        Active = 0
        Done = 1
        Confirmed = 2
        
        TitleLength = 55
        
        attr_reader :text, :progress
        attr_accessor :id, :cat_id, :progress, :priority, :status
        attr_accessor :added_at, :completed_at, :expire_at, :tags
        
        # Fill from JSON data
        def self.from_json(json)
            new_ticket = self.new
            new_ticket.id = json['id']
            new_ticket.cat_id = json['category_id']
            new_ticket.text = json['text']
            new_ticket.priority = json['priority']
            new_ticket.progress = json['progress']
            new_ticket.status = json['status']
            new_ticket.added_at = Utils.get_date(json['ts'])
            new_ticket.completed_at = Utils.get_date(json['completed_ts'])
            new_ticket.expire_at = Utils.get_date(json['expire_ts'])
            new_ticket.tags = json['tags'] if json['tags'] != nil
            
            new_ticket.check_if_expired
            
            new_ticket
        end
        
        # Get JSON data output
        def to_json
            {
                'id' => @id, 'text' => @text, 'status' => @status,
                'category_id' => @cat_id,
                'title' => @title,
                'priority' => @priority,
                'progress' => @progress,
                'ts' => Utils.date_string(@added_at),
                'completed_ts' => Utils.date_string(@completed_at),
                'expire_ts' => Utils.date_string(@expire_at),
                'tags' => @tags
            }
        end
        
        # Set ticket text and title
        def text=(text)
            @text = text
            
            punct_idx = text.index %r{\.|,|;|$}
            title_len = [punct_idx, TitleLength].min
            @title = text[0, title_len].strip
            
            if punct_idx == nil || punct_idx > TitleLength then
                @title += '...'
            end
        end
        
        # Set ticket progress and check if it's done
        def progress=(new_progress)
            @progress = new_progress
            if @progress == 100 then
                self.complete
            else
                if @status == Active then
                    @expire_at = nil
                end
                @status = Active
            end
        end
        
        # Mark as completed
        def complete
            @status = Done
            @expire_at = Date.today + 3
        end
        
        # Mark as confirmed done
        def confirm
            if @status == Done then
                @status = Confirmed
                @completed_at = Date.today
            end
        end
    
        def initialize
            @id = nil
            @text = nil
            @added_at = Date.today
            @completed_at = nil
            @expire_at = nil
            @progress = 0
            @status = Active
            @tags = []
        end
        
        def inspect
            info = Array.new
            info << "#{@text} (#{@id})"
            info << case @status
                when Active then 'Active'
                when Done then 'Done'
                else 'Confirmed'
                end
                
            if @status != Active
                info << ", completed at #{@completed_at}"
            end
                
            info.join ' '
        end
        
        # Check if ticket is expired and set appropriate status
        def check_if_expired
            if @status != Confirmed && @expire_at != nil
                if Date.today >= @expire_at
                    self.confirm
                end
            end
        end
    end
    
    # Tracker user
    class User
        ROLE_DEV = 0
        ROLE_MGR = 1
    
        attr_reader :login, :role
        
        # Create user from JSON data
        def self.from_json(json)
            new_user = User.new(json['login'], json['role'])
            new_user
        end
        
        def initialize(login, role)
            @login = login
            @role = role
        end
        
        # Is user a developer?
        def is_developer?
            return @role == ROLE_DEV
        end
        
        def inspect
            puts "#{@login} - #{role}"
        end
    end
end
