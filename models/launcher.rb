class Launcher
  attr_reader :name, :starred_repos

  def initialize(name)
    @name = name
    @starred_repos = starred_repos
  end

end
