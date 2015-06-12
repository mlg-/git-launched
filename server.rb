require 'sinatra'
require 'sinatra/json'
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
    launcher.avatar = full_name["avatar_url"]
    launcher.followers = full_name["followers"]
    launcher.personal_repos = full_name["public_repos"]
    values = [launcher.username, launcher.name, launcher.avatar,
              launcher.followers, launcher.personal_repos]
    sql = "INSERT INTO launchers(username, name, avatar, followers, repos)
          VALUES($1, $2, $3, $4, $5)"
    db_connection { |conn| conn.exec_params(sql, values) }
  end

end

def get_users
  sql = "SELECT launchers.username,
         launchers.name,
         launchers.id AS launcher_id,
         starred_repos.github_id AS repo_id,
         starred_repos.id AS pg_repo_id,
         starred_repos.name AS starred_repo,
         starred_repos.url AS starred_repo_url,
         starred_repos.description AS starred_repo_description
         FROM launchers
         JOIN starred_repos ON launchers.id = starred_repos.launcher
         ORDER BY lower(starred_repos.name)"
  launchers = db_connection { |conn| conn.exec_params(sql) }
end

def parse_common_stars
  intermediate_array = []
  get_users.each do |repo|
    clean_hash = {}
    clean_hash["id"] = repo["repo_id"]
    clean_hash["pg_id"] = repo["pg_repo_id"]
    clean_hash["name"] = repo["starred_repo"]
    clean_hash["count"] = 0
    clean_hash["users"] = []
    clean_hash["users"] << repo["username"]
    clean_hash["url"] = repo["starred_repo_url"]
    clean_hash["description"] = repo["starred_repo_description"]
    intermediate_array << clean_hash
  end
  sub_array = intermediate_array.dup
  intermediate_array.each do |super_hash|
    sub_array.each do |sub_hash|
      if super_hash["id"] == sub_hash["id"]
        super_hash["count"] += 1
        super_hash["users"] << sub_hash["users"][0] if super_hash["users"] != sub_hash["users"]
      end
    end
  end
final = intermediate_array.uniq {|x| x["id"] }
final_sorted = final.sort_by {|x| x["count"] }
final_sorted.reverse.first(20)
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
   load_users
   load_starred_repos
  popular_repos = parse_common_stars
  erb :index, locals: { popular_repos: popular_repos }
end
