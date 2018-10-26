require_relative '../config/environment'

@cursor = TTY::Cursor
@size = TTY::Screen.size
@font = TTY::Font.new(:straight)
@prompt = TTY::Prompt.new

def zip_code_to_city_name(zip)
  string = RestClient.get("https://maps.googleapis.com/maps/api/geocode/json?address=#{zip}&key=#{ENV['GOOGLE_API']}")
  hash = JSON.parse(string)
  hash["results"][0]["address_components"][1]["long_name"]
end

def driving_time(current_location, coordinates)
  string = RestClient.get("https://maps.googleapis.com/maps/api/directions/json?origin=#{current_location}&destination=#{coordinates}&key=#{ENV['GOOGLE_API']}")
  hash = JSON.parse(string)
  if hash["routes"].empty?
    "No route found"
  else
    hash["routes"][0]["legs"][0]["duration"]["text"]
  end
end

def public_transport_time(current_location, coordinates)
  string = RestClient.get("https://maps.googleapis.com/maps/api/directions/json?origin=#{current_location}&destination=#{coordinates}&mode=transit&key=#{ENV['GOOGLE_API']}")
  hash = JSON.parse(string)
  if hash["routes"].empty?
    "No route found"
  else
    hash["routes"][0]["legs"][0]["duration"]["text"]
  end
end

def walking_time(current_location, coordinates)
  string = RestClient.get("https://maps.googleapis.com/maps/api/directions/json?origin=#{current_location}&destination=#{coordinates}&mode=walking&key=#{ENV['GOOGLE_API']}")
  hash = JSON.parse(string)
  if hash["routes"].empty?
    "No route found"
  else
    hash["routes"][0]["legs"][0]["duration"]["text"]
  end
end

def show_directions_in_browser(origin, destination, travel_mode)
  `open "https://www.google.com/maps/dir/?api=1&origin=#{origin}&destination=#{destination}&travelmode=#{travel_mode}"`
end

def yes_or_no
  @prompt.select("", ["Yes", "No"])
end

def choose_event(titles)
  @prompt.select("Choose event", ["#{titles[0]}", "#{titles[1]}", "#{titles[2]}"])
end

def configure
  EventfulApi.configure do |config|
     config.app_key = ENV['EVENTFUL_KEY']
     config.consumer_key = ENV['CONSUMER_KEY']
     config.consumer_secret = ENV['CONSUMER_SECRET']
   end
   clear_screen
 end

 def welcome(user_name="", user_id=0)
   if user_name == ""
     puts "Please enter your name"
     user_name = gets.chomp
     new_user = User.create(:name => user_name)
     user_id = new_user.id
     new_user.save
     clear_screen
   end
   this_user = User.all.find do |user|
     user.id == user_id
   end
   puts "Welcome #{user_name.titleize}! Please enter your current zip code"
   user_input = gets.chomp
   clear_screen
   if user_input.length != 5
     puts "Invalid zip code. please try again."
     sleep(1)
     clear_screen
     welcome(user_name, user_id)
   else
     this_user.zip_code = user_input
     this_user.save
     @origin = user_input
     puts "Would you like to see the most popular events in your current area?"
     user_input_2 = yes_or_no
     user_input_to_string = user_input.to_s
   end
   if user_input_2.downcase == "yes"
     clear_screen
     find_most_popular_event_in_area_given(user_input_to_string, user_name, 10, 0)
   else
     clear_screen
     welcome
   end
   clear_screen
   sleep(3)
   repeat
 end

 def repeat
   welcome
 end

def client_hash(location, character_limit, user_name, radius)
  CLIENT.get('/events/search', {:location => location, :within => @radius, :page_size => 3, :sort_order => 'popularity', :sort_direction => 'descending'})
end

def find_most_popular_event_in_area_given(location, character_limit=400, user_name, radius, counter)
  @all_urls = []
  @all_titles = []
  @all_coordinates = []
  # counter = 0
  events_hash = client_hash(location, character_limit, user_name, radius)
  # binding.pry
  if events_hash["events"] == nil
    counter += 1
    if counter > 10
      puts "No events found. Please start again and enter another zip code."
      sleep(4)
      clear_screen
      welcome
    end
    # puts "loading"
    radius += 10
    find_most_popular_event_in_area_given(location, character_limit=400, user_name, radius, counter)
  end
  # binding.pry
  @array_of_events = events_hash["events"]["event"]
  # binding.pry
  name_of_location = zip_code_to_city_name(location)
  center_word_blue(name_of_location)
  loop_for_top_three(@array_of_events, location, character_limit, @all_titles, @all_urls)
  delimiter
  show_full_event_details(@all_titles, @all_urls, location, character_limit, user_name)
end

def loop_for_top_three(events_hash, location, character_limit, titles, urls)
  if events_hash.empty?
    puts "NO EVENTS"
    @radius += 5
  else
    i = 0
    while i < 3
      title = events_hash[i]["title"]
      titles << title
      start_time = events_hash[i]["start_time"]
      urls << events_hash[i]["url"]
      id = events_hash[i]["id"]
      this_venue = events_hash[i]["venue_name"]
      coordinates = [events_hash[i]["latitude"], events_hash[i]["longitude"]]
      string_coordinates = coordinates.join(",")
      array_of_venues = Venue.all.select do |venue|
        venue.venue_name == this_venue
      end
      if array_of_venues.size == 0
        new_venue = Venue.create(:venue_name => "#{this_venue}", :coordinates => "#{string_coordinates}")
        new_venue.save
      end
      venue_id = Venue.all.select do |venue|
        venue.venue_name == this_venue
      end
      new_event = Event.create(:event_title => title, :venue_id => venue_id[0]["id"], :event_id => id)
      new_event.save
      print_event_details(location, title, this_venue, start_time, coordinates.join(","))
      i += 1
    end
  end
end

def directions_or_event(titles, urls, event_title, performer)
  user_input = @prompt.select("What would you like to see?", ["Event Page", "Directions", "Youtube Results"])
  if user_input == "Directions"
    user_input_2 = @prompt.select("What mode of transit do you prefer?", ["Driving", "Transit", "Walking"])
    show_directions_in_browser(@origin, @venue, user_input_2.downcase)
  elsif user_input == "Event Page"
    open_url(titles, urls, event_title)
  else
    open_youtube_results(event_title, performer)
  end
end

def open_url(titles, urls, event_title)
    titles.each_with_index do |title, i|
      if title.downcase.include?(event_title.downcase)
        `open #{urls[i]}`
      end
    end
end

def open_youtube_results(event_title, performer)

  if performer.is_a?(Array)
    view_youtube_results(event_title)
  else
    view_youtube_results(performer["name"])
  end
end

def print_event_details(location, title, venue, start_time, coordinates)
  delimiter
  puts "TITLE: #{title}"
  puts "VENUE: #{venue}"
  puts "DATE: #{start_time}"
  puts "DRIVING TIME: #{driving_time(location, coordinates)}"
end

def print_event_details_for_individual_event(location, title, venue, start_time, coordinates, performer)
  delimiter
  puts "TITLE: #{title}"
  puts "VENUE: #{venue}"
  puts "DATE: #{start_time}"
  puts "DRIVING TIME: #{driving_time(location, coordinates)}"
  puts "PUBLIC TRANSPORT: #{public_transport_time(location, coordinates)}"
  puts "WALKING TIME: #{walking_time(location, coordinates)}"
  delimiter

  directions_or_event(@all_titles, @all_urls, title, performer)
end

def show_full_event_details(titles, urls, location, character_limit, user_name)
  puts "Would you like to view one of these events?"
  user_input = yes_or_no
  if user_input.downcase == "yes"
    user_input_2 = choose_event(titles)
    titles.each_with_index do |title, i|
      if title.downcase.include?(user_input_2.downcase)
        display_event_details(title, @array_of_events, location, character_limit, user_name)
      end
    end
  else
    clear_screen
    welcome
  end
end

def display_event_details(event_title, array_of_events, location, character_limit, user_name)
  array_of_events.each do |event|
    title = event["title"]
    if title.downcase.include?(event_title.downcase)
      id = event["id"]
      performer = event["performers"]["performer"]
      start_time = event["start_time"]
      venue = event["venue_name"]
      @venue = venue
      coordinates = [event["latitude"], event["longitude"]].join(",")
      Event.all.each do |event|
        User.all.each do |user|
          if event.event_id == id && user.name == user_name
            event.update(:user_id => user.id)
          end
        end
      end
      clear_screen
      print_event_details_for_individual_event(location, title, venue, start_time, coordinates, performer)
    end
  end
end


def delimiter
  `tput cols`.to_i.times do
    print "~"
  end
end

def center_word_blue(word)
    formatted_word = @font.write(word.upcase).split("\n")
    line_length = formatted_word[0].size
    if line_length < @size[1]
      x = (@size[1] - line_length) / 2
      if x <= 0
        puts @font.write(word.upcase)
      else
        formatted_word.each do |line|
          puts ((" " * x) + line).blue
        end
      end
    else
      x = (@size[1] - word.length) / 2
      puts ((" " * x) + word).blue
    end
end


def clear_screen
  print @cursor.move_to(0,0)
  @size[1].times do
    print @cursor.clear_line
    print @cursor.down(1)
  end
  print @cursor.move_to(0,0)
end


def view_youtube_results(performer)
  `open "https://www.youtube.com/results?search_query=#{performer}"`
end
