require 'sinatra'
require 'sinatra/json'
require 'httparty'
require 'pry'
require 'dotenv'

Dotenv.load

get '/' do
  response = HTTParty.get(
            "https://api.github.com/orgs/LaunchAcademy/members",
            :headers => {
                "Authorization" => "token #{ENV["API_KEY"]}",
                "User-Agent" => "mlg-",
                })
  users = []
  response.each { |user| users << user }
  end
  erb :index, locals: { users: users }
end
