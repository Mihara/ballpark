import marshal
import maidenhead
import math

type
  CityRecord = tuple[
    name: cstring,
    region: int,
    country: int,
    radius: float,
    loc: Geo
  ]
  City = tuple[
    name: cstring,
    region: cstring,
    country: cstring,
    loc: Geo
  ]

# At compile time, load and unmarshal our city table.
proc loadCities(): seq[CityRecord] =
  let
    citydata = staticRead "../db/cities.json"
  return to[seq[CityRecord]](citydata)

proc loadRegions(): seq[cstring] =
  let
    regiondata = staticRead "../db/regions.json"
  return to[seq[cstring]](regiondata)

proc loadCountries(): seq[cstring] =
  let
    countrydata = staticRead "../db/countries.json"
  return to[seq[cstring]](countrydata)

const cityDB = loadCities()
const countryCode = loadCountries()
const regionCode = loadRegions()


func distance*(a: Geo, b: Geo): float =
  ## Computes distance in kilometers along the great circle.
  const rEarth = 6371 # Radius of Earth in km.
  let
    aLat = degToRad(a.lat)
    bLat = degToRad(b.lat)
    aLon = degToRad(a.lon)
    bLon = degToRad(b.lon)
    dLat = bLat - aLat
    dLon = bLon - aLon
    a = (sin(dLat/2))^2 + cos(aLat) * cos(bLat) * (sin(dLon/2))^2
    c = 2 * arcsin(sqrt(a))
  result = c * rEarth

func closestCity*(coords: Geo): City =
  ## Goes through the city database to find the closest one.
  var closest = cityDB[0]
  for city in cityDB:
    let d = distance(coords, city.loc)
    if d < distance(coords, closest.loc):
      closest = city
      # If we landed inside the radius of a big city, stop.
      if d <= city.radius:
         break

  result.name = closest.name
  result.loc = closest.loc
  result.region = regionCode[closest.region]
  result.country = countryCode[closest.country]
