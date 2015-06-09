require 'sinatra'
require 'dotenv'
require 'pg'
require 'httparty'
require 'pry'

require_relative 'models/launcher.rb'


Dotenv.load

configure :development do
  set :db_config, { dbname: "gitlaunched"}
end

configure :production do
  uri = URI.parse(ENV["DATABASE_URL"])
  set :db_config, {
    host: uri.host,
    port: uri.port,
    dbname: uri.path.delete('/'),
    user: uri.user,
    password: uri.password
  }
end

def db_connection
  begin
    connection = PG.connect(settings.db_config)
    yield(connection)
  rescue PG::UniqueViolation
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
  team_members = get_launch_team

  team_members.each do |user|
    full_name = github_get("https://api.github.com/users/#{user[0]}")
    launcher = Launcher.new(user[0], full_name["name"])
    values = [launcher.username, launcher.name]
    sql = "INSERT INTO launchers(username, name) VALUES($1, $2)"
    db_connection { |conn| conn.exec_params(sql, values) }
  end

end

def get_users
  sql = "SELECT launchers.username,
         launchers.name,
         starred_repos.name AS starred_repo,
         starred_repos.url AS starred_repo_url,
         starred_repos.description AS starred_repo_description
         FROM launchers
         JOIN starred_repos ON launchers.id = starred_repos.launcher
         ORDER BY launchers.name"
  launchers = db_connection { |conn| conn.exec_params(sql) }
end

def load_starred_repos
  sql = "SELECT * FROM launchers"
  launcher_list = db_connection { |conn| conn.exec_params(sql) }
  launchers = launcher_list.map {|launcher| launcher["username"]}
  launchers.each do |launcher|
     starred_repos = github_get("https://api.github.com/users/#{launcher}/starred")
     unless starred_repos.empty?
       starred_repos.each do |repo|
         get_foreign_key = "SELECT id FROM launchers WHERE username = '#{launcher}'"
         foreign_keys = db_connection { |conn| conn.exec_params(get_foreign_key) }
         launcher_id = foreign_keys[0]["id"].to_i
         repo_info = [repo["id"], repo["name"], repo["html_url"],
                      repo["description"], launcher_id]
         sql = "INSERT INTO starred_repos(github_id, name, url, description, launcher)
                VALUES($1, $2, $3, $4, $5)"
         db_connection { |conn| conn.exec_params(sql, repo_info) }
       end
     end
  end
end

# def load_personal_repos

# scrape data from the source html of the summer-2015 team page, since we
# can't access it via the github api.
def get_launch_team
 summer = File.open('summer.txt', "r")
 contents = summer.read
 matches = contents.scan(/member-username">\s*<a href="\/(.+)">/)
 matches
end


get '/' do
  # load_users
  # load_starred_repos
  launcher_data = get_users
#  launcher = @launcher.all
  erb :index, locals: { launchers: launcher_data }
end
