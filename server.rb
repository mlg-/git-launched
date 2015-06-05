require 'sinatra'
require 'sinatra/json'
require 'httparty'
require 'pry'
require 'dotenv'
require 'pg'
require_relative 'models/launcher.rb'

Dotenv.load

def db_connection
  begin
    connection = PG.connect(dbname: "gitlaunched")
    yield(connection)
  ensure
    connection.close
  end
end

def github_get(url)
  HTTParty.get(
      "#{url}",
      :headers => {
          "Authorization" => "token #{ENV["API_KEY"]}",
          "User-Agent" => "mlg-",
          })
end

def load_users
  response = github_get("https://api.github.com/orgs/LaunchAcademy/members")

  response.each do |user|
    @launcher = Launcher.new(user["login"])
    new_launcher = []
    new_launcher << @launcher.name
    sql = "INSERT INTO launchers(name) VALUES($1)"
    db_connection { |conn| conn.exec_params(sql, new_launcher) }
  end

end

# def get_users
#
# end

get '/' do
  load_users
  # users.each do |user|
  #   starred_repos = github_get("https://api.github.com/users/#{user[0]}/starred")
  #   unless starred_repos.empty?
  #     current_user = user[0]
  #     user_repo_array = []
  #     starred_repos.each do |repo|
  #       user_repo_array << repo
  #     end
  #     users["#{current_user}"] = starred_repos
  #   end
  # end

#  launcher = @launcher.all

  erb :index
end
