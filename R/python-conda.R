
renv_python_conda_select <- function(name) {

  # handle paths (as opposed to environment names)
  if (grepl("[/\\\\]", name)) {
    if (!file.exists(name))
      return(reticulate::conda_create(envname = name))
    return(renv_python_exe(name))
  }

  # check for an existing conda environment
  envs <- reticulate::conda_list()
  idx <- which(name == envs$name)
  if (length(idx))
    return(envs$python[[idx]])

  # no environment exists; create it
  reticulate::conda_create(envname = name)

}

renv_python_conda_snapshot <- function(project, python) {

  owd <- setwd(project)
  on.exit(setwd(owd), add = TRUE)

  path <- file.path(project, "environment.yml")

  # find the root of the associated conda environment
  lockfile <- renv_lockfile_load(project = project)
  name <- lockfile$Python$Name %||% renv_python_envpath(project, "conda", version)
  python <- renv_python_conda_select(name)
  info <- renv_python_info(python)
  prefix <- info$root

  conda <- reticulate::conda_binary()
  args <- c("env", "export", "--prefix", shQuote(prefix))
  system2(conda, args, stdout = path)

  vwritef("* Wrote Python packages to '%s'.", aliased_path(path))
  return(TRUE)
}

renv_python_conda_restore <- function(project, python) {

  owd <- setwd(project)
  on.exit(setwd(owd), add = TRUE)

  path <- file.path(project, "requirements.txt")

  # find the root of the associated conda environment
  lockfile <- renv_lockfile_load(project = project)
  name <- lockfile$Python$Name %||% renv_python_envpath(project, "conda", version)
  python <- renv_python_conda_select(name)
  info <- renv_python_info(python)
  prefix <- info$root

  conda <- reticulate::conda_binary()
  cmd <- if (file.exists(prefix)) "create" else "update"
  args <- c(cmd, "--yes", "--prefix", shQuote(prefix), "--file", shQuote(path))
  system2(conda, args)

  return(TRUE)

}
