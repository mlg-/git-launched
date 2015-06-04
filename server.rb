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
  users = {}
  response.each do |user|
    name = user["login"]
    users[name] = ""
  end

  users.each do |user|
    starred_repos = HTTParty.get(
              "https://api.github.com/users/#{user[0]}/starred",
              :headers => {
                  "Authorization" => "token #{ENV["API_KEY"]}",
                  "User-Agent" => "mlg-",
                  })
    unless starred_repos.empty?
      current_user = user[0]
      users[current_user] = starred_repos[0]["name"]
    end
  end

  erb :index, locals: { users: users }
end
