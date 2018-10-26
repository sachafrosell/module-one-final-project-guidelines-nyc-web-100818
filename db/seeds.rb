require_relative '../config/environment'
require_relative '../lib/seed_communicator.rb'
require_relative '../lib/api_communicator'

User.destroy_all
Event.destroy_all
Venue.destroy_all

 # 10.times do
   # puts "working"
  new_user = User.create(:name => Faker::Name.name, :zip_code => Faker::Address.zip)
  configure_2
  puts "working"

  welcome_2(new_user.name, new_user.zip_code)
 # end

# def restart_2
#   new_user = User.create(:name => Faker::Name.name, :zip_code => Faker::Address.zip)
#   configure_2
#   welcome_2(new_user.name, new_user.zip_code)
# end
