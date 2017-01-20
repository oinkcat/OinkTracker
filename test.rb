# Тестирование вывода списка задач трекера
#  

require './model.rb'
require './file_repository.rb'

include TrackerModel

# Request all projects
puts 'I. Projects dump:'
all_projects = Repository.get_projects
p all_projects

# Request project with id #1
proj_1 = Repository.get_project 1
p proj_1

# Request all active tickets in category #1
puts 'II. Active tickets dump:'
active_tickets = Repository.get_tickets(1, 0)
p active_tickets

# Request all confirmed done tickets in category #1
puts 'III. Confirmed done tickets dump:'
confirmed_tickets = Repository.get_tickets(1, Ticket::Confirmed)
p confirmed_tickets

# Get user
puts 'IV. Get user by login'
softcat = Repository.get_user_by_login('softcat')
p softcat
