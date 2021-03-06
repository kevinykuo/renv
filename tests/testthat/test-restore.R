
context("Restore")

test_that("library permissions are validated before restore", {
  skip_on_os("windows")
  inaccessible <- renv_tempfile()
  dir.create(inaccessible, mode = "0100")
  renv_scope_options(renv.verbose = FALSE)
  expect_false(renv_restore_preflight_permissions(inaccessible))
})

test_that("we can restore packages after init", {

  renv_tests_scope("breakfast")

  renv::init()

  libpath <- renv_paths_library()
  before <- list.files(libpath)

  unlink(renv_paths_library(), recursive = TRUE)
  renv::restore()

  after <- list.files(libpath)
  expect_setequal(before, after)

})

test_that("restore can recover when required packages are missing", {

  renv_tests_scope("breakfast")
  renv::init()

  local({
    renv_scope_sink()
    renv::remove("oatmeal")
    renv::snapshot()
    unlink(renv_paths_library(), recursive = TRUE)
    renv::restore()
  })

  expect_true(renv_package_installed("oatmeal"))

})

test_that("restore(clean = TRUE) removes packages not in the lockfile", {

  renv_tests_scope("oatmeal")
  renv::init()

  renv_scope_options(renv.config.auto.snapshot = FALSE)
  renv::install("bread")
  expect_true(renv_package_installed("bread"))

  renv::restore(clean = TRUE)
  expect_false(renv_package_installed("bread"))

})

test_that("renv.records can be used to override records during restore", {

  renv_tests_scope("bread")
  renv::init()

  renv::install("bread@0.1.0")
  renv::snapshot()
  expect_equal(renv_package_version("bread"), "0.1.0")

  bread <- list(Package = "bread", Version = "1.0.0", Source = "CRAN")
  overrides <- list(bread = bread)
  renv_scope_options(renv.records = overrides)

  renv::restore()
  expect_equal(renv_package_version("bread"), "1.0.0")

})
