context("Install")

test_that("installation failure is well-reported", {

  owd <- setwd(tempdir())
  on.exit(setwd(owd), add = TRUE)

  # init dummy library
  library <- renv_tempfile("renv-library-")
  ensure_directory(library)

  # dummy environment
  envir <- new.env(parent = emptyenv())
  envir[["hello"]] <- function() {}

  # prepare dummy package
  package <- "renv.dummy.package"
  unlink(package, recursive = TRUE)
  utils::package.skeleton(package, environment = envir)

  # remove broken man files
  unlink("renv.dummy.package/Read-and-delete-me")
  unlink("renv.dummy.package/man", recursive = TRUE)

  # give the package a build-time error
  writeLines("parse error", con = file.path(package, "R/error.R"))

  # try to build it and confirm error
  renv_scope_options(renv.verbose = FALSE)
  expect_error(renv_install_package_local_impl(package, package, library))

})

test_that("install forces update of dependencies as needed", {

  renv_tests_scope("breakfast")

  # install the breakfast package
  renv::install("breakfast")

  # ensure its dependencies were installed
  packages <- c("bread", "oatmeal", "toast")
  for (package in packages)
    expect_true(file.exists(renv_package_find(package)))

  # remove breakfast
  renv::remove("breakfast")

  # modify 'toast' so that it's now too old
  path <- renv_package_find("toast")
  descpath <- file.path(path, "DESCRIPTION")
  desc <- renv_description_read(descpath)
  desc$Version <- "0.1.0"
  renv_dcf_write(desc, file = descpath)

  # try to install 'breakfast' again
  renv::install("breakfast")

  # validate that 'toast' was updated to 1.0.0
  desc <- renv_description_read(package = "toast")
  expect_equal(desc$Version, "1.0.0")

})

test_that("packages can be installed from local sources", {

  renv_tests_scope()
  renv::init()

  # get path to package sources in local repos
  repos <- getOption("renv.tests.repos")
  tarball <- file.path(repos, "src/contrib/bread/bread_1.0.0.tar.gz")

  # try to install it
  renv::install(tarball)
  expect_true(renv_package_version("bread") == "1.0.0")

})

test_that("various remote styles can be used during install", {
  skip_on_cran()

  renv_tests_scope()
  renv::init()

  # install CRAN latest
  renv::install("bread")
  expect_true(renv_package_installed("bread"))
  expect_true(renv_package_version("bread") == "1.0.0")

  # install from archive
  renv::install("bread@0.1.0")
  expect_true(renv_package_installed("bread"))
  expect_true(renv_package_version("bread") == "0.1.0")

  # install from github
  renv::install("kevinushey/skeleton")
  expect_true(renv_package_installed("skeleton"))
  expect_true(renv_package_version("skeleton") == "1.0.1")

  # install from github PR
  renv::install("kevinushey/skeleton#1")
  expect_true(renv_package_installed("skeleton"))
  expect_true(renv_package_version("skeleton") == "1.0.2")

  # install from branch
  renv::install("kevinushey/skeleton@feature/version-bump")
  expect_true(renv_package_installed("skeleton"))
  expect_true(renv_package_version("skeleton") == "1.0.2")

  # install from subdir
  renv::install("kevinushey/subdir:subdir")
  expect_true(renv_package_installed("subdir"))
  expect_true(renv_package_version("subdir") == "0.0.0.9000")

})
