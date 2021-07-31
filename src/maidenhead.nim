
import strutils
import strformat

# Never forget: Latitude is +north -south,
# longitude is +east -west.

type
  Geo* = tuple[lat: float, lon: float]

func charToValue(c: char): float =
  const
    a = ord('A')
    o = ord('0')
  let c = ord(c)
  if c >= a:
    return float(c - a)
  return float(c - o)

func fromMaidenhead*(grid: string): Geo =
  ## Convert a maidenhead grid to coordinates of the center of the grid square.

  let
    grid = grid.toUpperAscii()
    pair = len(grid) div 2
  var
    lon = -90.0
    lat = -90.0
    i = 0
    res = 10.0

  while i < pair:
    lon += res * charToValue(grid[2 * i])
    lat += res * charToValue(grid[2 * i + 1])
    # Skip the last increment, because I want that res value to
    # shift the coordinates to the center later.
    if i < pair - 1:
      if (i mod 2) > 0:
        res /= 24.0
      else:
        res /= 10.0
    i += 1

  lon *= 2

  # This gives us the coordinates of the southwest corner of the square
  # but I want the center, so we add half the square resolution.
  return (lat: lat + res/2, lon: lon + res)

func gridFormat*(grid: string): string =
  ## Formats a maidenhead grid properly for printing
  ## and does sanity checking on it.
  var
    grid = grid.strip().toLowerAscii()
    i = 0
  let
    pair = len(grid) div 2

  # First, sanity checks
  # if it doesn't have an even number of characters, raise.
  if len(grid) mod 2 > 0:
    raise newException(ValueError,
                       fmt"Looks like you missed a character in '{grid}'")
  # If it contains any characters other than A-X0-9, raise.

  const
    validChars = {'a'..'x', '0'..'9'}
    validFirst = {'a'..'r'}

  for c in grid:
    if not (c in validChars):
      raise newException(ValueError,
                         fmt"Grid '{grid}' contains invalid characters.")

  # If one of the first two characters is higher than R, raise.
  if not (grid[0] in validFirst) or not (grid[1] in validFirst):
    raise newException(ValueError,
                       fmt"Grid '{grid}' fell off the Earth.")

  # Now, every first pair in a sequence of three should be uppercase...
  while i < pair:
    if i mod 3 == 0:
      grid[i*2] = grid[i*2].toUpperAscii()
      grid[i*2+1] = grid[i*2+1].toUpperAscii()
    i += 1
  return grid
