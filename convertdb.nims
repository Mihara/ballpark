
#[

This started out as a Python script, but I rewrote it in NimScript to
reduce dependencies and pave the way for native compilation on Windows
with fewer headaches.

Potentially, this could be done during compilation, however, the NimScript
implementation is a lot slower than Python (surprisingly) so it stays where
it is.

]#

import os
import streams
import json
import parsecsv
import parseutils
import strutils
import algorithm

const
  srcPath = "vendor"
  dbPath = "db"

# Slightly different from the types used in the actual program.
type
  Geo = tuple[lat: float, lon: float]
  CityRecord = tuple[
    name: string,
    region: int,
    country: int,
    radius: float,
    loc: Geo
  ]

var
  cities: seq[CityRecord]
  countries: seq[string]
  regions: seq[string]

var
  csv: CsvParser
  # A bit silly that this is how you have to do it in nimscript, but whatever.
  db = newStringStream(readFile(os.joinpath(srcPath, "worldcities.csv")))

csv.open(db, "worldcities.csv", ',', '\"')

csv.readHeaderRow()

while csv.readRow():
  var
    population = 0

  # Clean up the population value: some entries in the database
  # have a decimal point in there for some silly reason.
  try:
    population = parseInt(csv.rowEntry("population").replace(".", ""))
  except ValueError:
    continue

  # We skip cities with population < 20000
  # unless they're also marked as region capitals.
  if len(csv.rowEntry("capital")) == 0 and population <= 20000:
    continue

  # Now take a guess at a city's effective radius, which
  # we are using to solve the agglomeration problem.
  # I am only guessing here, but I know Moscow's
  # radius is about 15.3km,
  # and the population is listed as 17125000.
  let radius = float(population) / (17125000 / 15.3)

  var
    city: CityRecord

    # Here we also clean up some bogus entries in regions:
    # I'm not going to believe any country uses slashes to *start*
    # their region names.
    regionString = csv.rowEntry("admin_name").replace("//", "")

    countryString = csv.rowEntry("country")
    countryIndex = countries.find(countryString)
    regionIndex = regions.find(regionString)

  city.name = csv.rowEntry("city")
  city.radius = radius

  city.loc.lat = parseFloat(csv.rowEntry("lat"))
  city.loc.lon = parseFloat(csv.rowEntry("lng"))

  # Cities with an empty region name get the region name equal to the city itself.
  if len(regionString) == 0:
    regionString = csv.rowEntry("city")

  if regionIndex > -1:
    city.region = regionIndex
  else:
    regions.add(regionString)
    city.region = len(regions)-1

  if countryIndex > -1:
    city.country = countryIndex
  else:
    countries.add(countryString)
    city.country = len(countries)-1

  cities.add(city)

csv.close()

# Sort the cities by population, highest first,
# so that if the search lands inside the radius of two cities,
# the bigger one wins.
func compareCities(a: CityRecord, b: CityRecord): int =
  if a.radius < b.radius: 1
  elif a.radius == b.radius: 0
  else: -1

cities.sort(compareCities)

# Now write our json files.
# Simple with regions and countries, a bit more complicated for cities,
# since they're not a simple structure.

var
  citiesJson = newJArray()

for city in cities:
  citiesJson.add( %* {
    "Field0": city.name,
    "Field1": city.region,
    "Field2": city.country,
    "Field3": city.radius,
    "Field4": {
      "Field0": city.loc.lat,
      "Field1": city.loc.lon
    }
  })


writeFile(os.joinpath(dbPath, "cities.json"), pretty(citiesJson))
writeFile(os.joinpath(dbPath, "regions.json"), pretty(%regions))
writeFile(os.joinpath(dbPath, "countries.json"), pretty(%countries))

echo("Database preparation complete.")
