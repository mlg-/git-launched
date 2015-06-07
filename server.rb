require 'sinatra'
require 'dotenv'
require 'pg'
require 'httparty'

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
  response = github_get("https://api.github.com/orgs/LaunchAcademy/members")

  response.each do |user|
    launcher = Launcher.new(user["login"])
    new_launcher = []
    new_launcher << launcher.name
    sql = "INSERT INTO launchers(name) VALUES($1)"
    db_connection { |conn| conn.exec_params(sql, new_launcher) }
  end

end

def get_users
  sql = "SELECT launchers.name AS launcher, starred_repos.name AS repo, starred_repos.url, starred_repos.description
         FROM launchers
         JOIN starred_repos ON launchers.id = starred_repos.launcher_name"
  launchers = db_connection { |conn| conn.exec_params(sql) }
end

def load_starred_repos
  sql = "SELECT * FROM launchers"
  launcher_list = db_connection { |conn| conn.exec_params(sql) }
  launchers = launcher_list.map {|launcher| launcher["name"]}
  launchers.each do |launcher|
     starred_repos = github_get("https://api.github.com/users/#{launcher}/starred")
     unless starred_repos.empty?
       starred_repos.each do |repo|
         get_foreign_key = "SELECT id FROM launchers WHERE name = '#{launcher}'"
         foreign_keys = db_connection { |conn| conn.exec_params(get_foreign_key) }
         launcher_id = foreign_keys[0]["id"].to_i
         repo_info = [repo["id"], repo["name"], repo["html_url"],
                      repo["description"], launcher_id]
         sql = "INSERT INTO starred_repos(github_id, name, url, description, launcher_name)
                VALUES($1, $2, $3, $4, $5)"
         db_connection { |conn| conn.exec_params(sql, repo_info) }
       end
     end
  end
end


get '/' do
  # load_users
  # load_starred_repos
  launcher_data = get_users
#  launcher = @launcher.all
  erb :index, locals: { launchers: launcher_data }
end
