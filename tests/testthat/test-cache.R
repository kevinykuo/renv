
context("Cache")

test_that("issues within the cache are reported", {

  # use a temporary cache for this test as we're going
  # to mutate and invalidate it
  tempcache <- tempfile("renv-tempcache-")
  ensure_directory(tempcache)
  on.exit(unlink(tempcache, recursive = TRUE), add = TRUE)
  renv_scope_envvars(RENV_PATHS_CACHE = tempcache)

  # initialize project
  renv_tests_scope("breakfast")
  renv::init()

  # find packages in the cache
  cache <- renv_cache_list()

  # diagnostics for missing DESCRIPTION
  bread <- renv_cache_list(packages = "bread")
  descpath <- file.path(bread, "DESCRIPTION")
  unlink(descpath)

  # diagnostics for bad hash
  breakfast <- renv_cache_list(packages = "breakfast")
  descpath <- file.path(breakfast, "DESCRIPTION")
  desc <- renv_description_read(descpath)
  desc$Version <- "2.0.0"
  renv_dcf_write(desc, file = descpath)

  # check problems explicitly
  problems <- renv_cache_diagnose(verbose = FALSE)
  expect_true(nrow(problems) == 2)

})

test_that("use.cache project setting is honored", {
  skip_on_os("windows")

  renv_tests_scope("breakfast")

  renv::init()

  packages <- list.files(renv_paths_library(), full.names = TRUE)
  types <- renv_file_type(packages)
  expect_true(all(types == "symlink"))

  renv::settings$use.cache(FALSE)

  packages <- list.files(renv_paths_library(), full.names = TRUE)
  types <- renv_file_type(packages)
  expect_true(all(types == "directory"))

  renv::settings$use.cache(TRUE)

  packages <- list.files(renv_paths_library(), full.names = TRUE)
  types <- renv_file_type(packages)
  expect_true(all(types == "symlink"))

})
