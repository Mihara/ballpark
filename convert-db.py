#!/usr/bin/env python3
"""
This script converts the city database from csv into the json files that Nim
compiler picks up and embeds into the executable during compilation.

It's a bit messy.
"""

import os
import csv
import json

DB_PATH = "db"
SRC_PATH = "vendor"

cities = []
countries = set()
regions = set()

with open(os.path.join(SRC_PATH, "worldcities.csv"), "r") as f:
    reader = csv.DictReader(f)
    for row in reader:
        # Marshaled structure is like this:
        # {"Field0": "foo",
        #  "Field1": 100,
        #  "Field2": 200,
        #  "Field3": 123.456
        #  "Field4": {"Field0": 55.6875, "Field1": 37.45833333333333}
        # }
        #
        # This is meant to be
        # type
        #   Geo = tuple[lat: float, lon: float]
        #   CityRecord = tuple[
        #                  name: string,
        #                  region: int,
        #                  country: int,
        #                  radius: float,
        #                  loc: Geo]
        #
        # where region and country are indexes in the
        # lists of regions and countries, and radius is an approximation
        # of a city's size.

        # Some of the original data needs correction
        # (decimal dot in population? Really?)
        # and we skip cities which are smaller than 20k population
        # to cut down on the file size.

        try:
            population = int(row['population'].replace('.', ''))
        except ValueError:
            continue

        # Never skip regional capitals.
        if not row['capital'] and population <= 20000:
            continue

        # Now take a guess at a city's effective radius, which
        # we will be using to solve the agglomeration problem.
        # I am only guessing here, but I know Moscow's
        # radius is about 15.3km,
        # and the population is listed as 17125000.
        radius = population / (17125000 / 15.3)

        cities.append({
            'Field0': row['city'],
            'Field1': row['admin_name'],
            'Field2': row['country'],
            'Field3': radius,
            'Field4': {
                'Field0': float(row['lat']),
                'Field1': float(row['lng']),
            }
        })

        countries.add(row['country'])
        regions.add(row['admin_name'])

# Sort the database by city radius top down: That cuts down on search time.
cities = sorted(cities, key=lambda k: -k['Field3'])

# These, we can sort alphabetically.
countries = sorted(list(countries))
regions = sorted(list(regions))


def squish(city):
    # Replace the strings in regions and countries fields with
    # their indexes in the respective list.
    city['Field1'] = regions.index(city['Field1'])
    city['Field2'] = countries.index(city['Field2'])
    return city


cities = [squish(x) for x in cities]

# Do some cleanup on the region list now -- some of them are odd:

regions = [x.strip('//') for x in regions]

# Then we can write out our json files.

for fn, v in [
    ("cities.json", cities),
    ("countries.json", countries),
    ("regions.json", regions),
]:
    with open(os.path.join(DB_PATH, fn), "w") as f:
        json.dump(v, f, indent=4)

print("Database preparation complete.")
