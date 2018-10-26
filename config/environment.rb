require 'bundler/setup'

Bundler.require

require_all 'app'

Dotenv.load

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'db/development.db')
CLIENT = EventfulApi::Client.new(:oauth_token => 'token', :oauth_secret => 'token secret')
connection_details = YAML::load(File.open('config/database.yml'))

DB = ActiveRecord::Base.establish_connection(connection_details)

ActiveRecord::Base.logger = nil

@radius = 10

SIZE = TTY::Screen.size
CURSOR = TTY::Cursor
