class Launcher
  attr_reader :name, :username, :starred_repos, :personal_repos

  def initialize(username, name)
    @username = username
    @name = name
    @starred_repos = starred_repos
    @personal_repos = personal_repos
  end

end
