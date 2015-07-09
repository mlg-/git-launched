class Launcher
  attr_accessor :name, :username, :avatar, :starred_repos, :personal_repos, :followers

  def initialize(username, name)
    @username = username
    @name = name
    @avatar = avatar
    @starred_repos = starred_repos
    @personal_repos = personal_repos
    @followers = followers
  end

end
