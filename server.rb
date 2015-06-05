require 'sinatra'
require 'sinatra/json'
require 'httparty'
require 'pry'
require 'dotenv'

Dotenv.load

def github_get(url)
  HTTParty.get(
      "#{url}",
      :headers => {
          "Authorization" => "token #{ENV["API_KEY"]}",
          "User-Agent" => "mlg-",
          })
end

get '/' do
  response = github_get("https://api.github.com/orgs/LaunchAcademy/members")
  users = {}
  response.each do |user|
    name = user["login"]
    users[name] = ""
  end

  users.each do |user|
    starred_repos = github_get("https://api.github.com/users/#{user[0]}/starred")
    unless starred_repos.empty?
      current_user = user[0]
      user_repo_array = []
      starred_repos.each do |repo|
        user_repo_array << repo
      end
      users["#{current_user}"] = starred_repos
    end
  end

#  launcher = @launcher.all

  erb :index, locals: { users: users }
end
