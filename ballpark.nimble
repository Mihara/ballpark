# Package

version = "1.0.2"
author = "Eugene Medvedev (R2AZE)"
description = "An amateur radio tool to get you a ballpark estimate of where a given Maidenhead grid square is."
license = "MIT"
srcDir = "src"
bin = @["ballpark"]
binDir = "build"

# Dependencies

requires "nim >= 1.4.8"
requires "fsnotify >= 0.1.4"

# Tasks

# We're already requiring nim >= 1.4.8, so we can assume that 'distros' is available.
import os
import distros
from macros import error

task db, "Prepare city database.":

  if not fileExists("db/countries.json") or
     not fileExists("db/cities.json") or
     not fileExists("db/regions.json"):

    echo("=== Preparing city database for embedding.")
    selfExec "--maxLoopIterationsVM:50000000 convertdb.nims"

# Before building, ensure the database was converted.
before build:
  dbTask()

# It's silly, but I have to reconstruct the compiler command line
# that nimble does in the build stage here to do multiple release builds.
# See https://github.com/nim-lang/nimble/issues/764
#
# This is kinda brittle.
#

task clean, "Clean the build directory.":
  rmDir(binDir)

task release, "Produce a release build for all platforms.":

  # External dependencies for Ubuntu required
  # to cross-compile release builds.

  if detectOs(Ubuntu):
    # MUSL libc for static compilation
    foreignDep "musl-dev"
    foreignDep "musl-tools"
    # ARM compiler
    foreignDep "gcc-arm-linux-gnueabihf"
    # Windows compiler
    foreignDep "mingw-w64"
    # Executable packer.
    foreignDep "upx"
  else:
    echo("Warning: Dependencies might be missing, you're on your own. ",
         "Check ballpark.nimble for details.")

    # I don't know the right invocation for foreignDep for anything
    # except Ubuntu, but at least I can tell if the executables
    # are there.
    for requiredExe in [
      "musl-gcc",
      "arm-linux-gnueabihf-gcc",
      "x86_64-w64-mingw32-gcc",
      "upx"
    ]:
       if findExe(requiredExe) == "":
         error(requiredExe & " binary was not found in PATH.")

  let
    compile = join(["c -d:release -d:strip --opt:size",
                    "--passL:-static",
                    "-d:NimblePkgVersion=" & version]," ")
    linux_x64_exe = projectName() & "_amd64"
    linux_x64 = join(["--cpu:amd64 --os:linux",
                      "--gcc.exe:musl-gcc --gcc.linkerexe:musl-gcc",
                      "--out:build/" & linux_x64_exe]," ")
    windows_x64_exe = projectName() & "_win64.exe"
    windows_x64 = "--cpu:amd64 -d:mingw --out:build/" & windows_x64_exe

    # Unfortunately, there's no quick and easy way to build with
    # musl for arm in Ubuntu unless you download the source.
    # So the binary size suffers a bit.
    raspberry_x32_exe = projectName() & "_armhf"
    raspberry_x32 = "--cpu:arm --os:linux --passL:-static --out:build/" &
                    raspberry_x32_exe

    rootFile = os.joinpath(srcDir, projectName() & ".nim")

    upx = "upx --best"

  dbTask()
  cleanTask()

  echo "=== Building Windows x64..."
  selfExec join([compile, windows_x64, rootFile]," ")
  exec join([upx, os.joinpath(bindir, windows_x64_exe)]," ")

  echo "=== Building Linux amd64..."
  selfExec join([compile, linux_x64, rootFile], " ")
  exec join([upx, os.joinpath(bindir, linux_x64_exe)]," ")

  echo "=== Building Raspberry..."
  selfExec join([compile, raspberry_x32, rootFile], " ")
  exec join([upx, os.joinpath(bindir, raspberry_x32_exe)]," ")

  echo "Done."
