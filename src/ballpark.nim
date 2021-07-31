
import os
import strutils
import strformat
import fsnotify

import maidenhead
import cities

# This is the open handle for a potentially tracked log.
var
  logfile: File = nil

proc doBallpark(grid: string): void =
  ## Actually prints out a given grid square.
  var
    grid = grid

  try:
    grid = gridFormat(grid)
  except ValueError:
    let
      msg = getCurrentExceptionMsg()
    echo(fmt"Error: {msg}")
    return

  let
    c = fromMaidenhead(grid)
    city = closestCity(c)
    d = distance(c, city.loc)
    dm = d * 0.62137119

  echo(fmt"{grid}: {c.lat:.6f}, {c.lon:.6f}")
  echo(fmt"Region: {city.country}, {city.region}")
  echo(fmt"City: {city.name} ({d:.3f} km, {dm:.3f} mi)")

proc processLog() =
  ## Go through a log file up until it ends and print out every grid
  ## and callsign found therein.

  #[

    Typical WSJT-X ALL.TXT:

    210705_181330    14.074 Rx FT8    -14  1.3 2692 CQ SO8DAN KO11
    210705_181330    14.074 Rx FT8    -18  0.3 2589 EC3CVD PE1NPS R-14
    210705_181330    14.074 Rx FT8     -4  0.3  694 AA4MY RL3AM -10
    210705_181330    14.074 Rx FT8     -6  0.2 1201 DH5BM AM1ASX RR73
    210705_181330    14.074 Rx FT8     -6 -1.0 1367 F2YT OZ5KAJ R-05
    210705_181330    14.074 Rx FT8    -19  0.2 2167 2D0PEY PD3PVH JO21

    Typical JDTX ALL.TXT:

    20210731_080315 -12  0.1  518 ~ CQ OZ1RH JO55
    20210731_080315 -20  0.0 1538 ~ CQ EA5ET IM99
    20210731_080315 -16 -0.0 2339 ~ CQ UX2MD KN98             *
    20210731_080332.390(0)  hisCall:mode: time:32 autoselect:  auto sequence is not started; status: NONE count: 0 prio: 0
    20210731_080332.391(0)  Decoding finished
    20210731_080344.695(0)  Decoder started SWL On, cycles: 3

    In all cases, we're interested in the last four letters,
    though the * and ^ JDTX can put there at the end complicate things
    a bit.

    Some cases of uncertain decodes might confuse the parsing logic,
    but that'll do for now.

  ]#

  var logline = ""

  while true:
    if readLine(logfile, logline):

      # Try to scrape out the grid and callsign from the line.
      # Notice newlines are not part of the string returned by readLine.
      logline = logline.strip(chars = {' ', '^', '*'},
                              leading = false, trailing = true)
      let
        tokens = rsplit(logline, " ", maxsplit = 2)

      # If the line doesn't contain enough spaces, we don't want it.
      if len(tokens) < 3:
        continue

      let
        callsign = tokens[1]
        grid = tokens[2].toUpperAscii

      # If the line looks like it isn't really a grid, skip it.
      if len(grid) != 4 or
         grid[0].isDigit() or
         grid[1].isDigit() or
         grid == "RR73" or
         grid.contains('-') or
         grid.contains('+'):
        continue

      # Otherwise do our thing.
      echo(fmt"=== {callsign}")
      doBallpark(grid)
      echo("===", "\n")

    else:
      break


proc newLogLine(event: seq[PathEvent]) =
  ## fswatcher watch procedure.
  var s: set[FileEventAction] = {}
  for e in event:
    s.incl e.action
  if FileEventAction.Modify in s:
    processLog()
  elif FileEventAction.Remove in s or FileEventAction.Rename in s:
    echo "File is gone, we're done."
    quit(QuitSuccess)

when isMainModule:

  # Grab the version number from nimble.
  const NimblePkgVersion {.strdefine.}: string = "0.0.0"

  let me = getAppFilename()

  if paramCount() != 1:
    echo("Ballpark v", NimblePkgVersion, " © 2021 by Eugene Medvedev (R2AZE)")
    echo("Released under the terms of MIT license.")
    echo("Includes the city coordinates database by Pareto Software LLC ",
         "under the terms of CC-BY 4.0 license.")
    echo("\nLocates a Maidenhead grid square on Earth down to ",
         "country, region and closest city, so you have a better ",
         "understanding of where it actually is.\n")
    echo("    '", me, " <grid>' to ballpark a single grid square.")
    echo("    '", me, " <path to ALL.TXT>' to track heard grids.\n")
    echo("Both JTDX and WSJT-X formats of ALL.TXT are supported. ",
         "You can use any grid precision you have.")
    quit(QuitFailure)

  let arg = paramStr(1)

  # Now, if this is a filename that exists...
  if fileExists(arg):
    var
      watcher = initWatcher(1)

    if not open(logfile, arg):
      echo("Error: Could not open the log file.")
      quit(QuitFailure)

    # Notice we never actually close the file.
    # That's because if I try to addExitproc,
    # cross-compilation for Raspberry fails.
    # Not sure why, and it's probably not a big deal.

    # Seek to the end so we don't suck the whole thing in when the first
    # new string turns up.
    setFilePos(logfile, 0, fspEnd)

    register(watcher, arg, newLogLine)
    echo("Tracking log file ", arg)

    while true:
      poll(watcher, 200)

  else:
    doBallpark(arg)
