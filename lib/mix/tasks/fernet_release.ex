defmodule Mix.Tasks.Fernet.Release do
  @moduledoc """
  Release the latest version of FernetEx

      mix fernet.release
  """

  use Mix.Task

  alias Mix.Project

  @shortdoc "Update readme, tag, and release to hex"

  def run(_args) do
    version = Keyword.get(Project.config, :version)

    if Mix.shell.yes?("Release fernetex #{version}") do
      Mix.shell.info("Releasing #{version}")
      readme = EEx.eval_file("README.md.eex", [version: version])
      :ok = File.write!("README.md", readme)
      0 = Mix.shell.cmd("git commit -am 'Release #{version}'")
      0 = Mix.shell.cmd("git tag #{version}")
      0 = Mix.shell.cmd("git push --all")
      0 = Mix.shell.cmd("git push --tags")
      Mix.Task.run("hex.publish")
      Mix.Task.run("hex.docs")
    end
  end
end
