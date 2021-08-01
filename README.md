# Ballpark

This is a commandline utility to quickly give you the sense of where exactly a given Maidenhead grid square is.

[Maidenhead Locator System](https://en.wikipedia.org/wiki/Maidenhead_Locator_System) is a geographical grid system commonly used in amateur radio, particularly when operating digital modes, giving you a quick way to transmit a rough location for the purposes of determining distance to your correspondent.

However, it's pretty opaque, and a quick `KO85` doesn't tell you much, until you look at the actual map, when you will see it is one of the four grid squares overlapping Moscow, Russia.

So just look at the map, right?

But sometimes, you're operating in the field, and don't have a map handy, or internet access, or a browser. Or the resources to run one in addition to your digital mode software. But you know your basic geography and still want a quick ballpark estimate of just where your correspondent is, beyond the information contained in their callsign.

That's where this utility comes in -- it will give you the geographical coordinates of the center of the grid square, as well as locate the closest city, the region and country it belongs to, and tell you how far that is from the coordinates you got.

## Installation

Just get the executable suitable for your system from the Releases page, name it what you like and put it somewhere in your PATH. You're done.

Or you could compile from source yourself, see below.

## Usage

There are two operating modes. The first is simply to invoke it with the grid square as an argument:

```
$ ./ballpark KO85rq
KO85rq: 55.687500, 37.458333
Region: Russia, Moskva
City: Moscow (12.547 km, 7.796 mi)
```

Arbitrary levels of precision are supported, i.e. you can use `KO85`, `KO85rq`, etc.

The second operating mode is to give it the full path to ALL.TXT file of your WSJT-X or JTDX installation:

```
$ ./ballpark ~/.local/share/WSJT-X/ALL.TXT
Tracking log file /home/mihara/.local/share/WSJT-X/ALL.TXT
```

The program will track writes to this file, and check every grid square it finds and print it to the standard output, so you'll have a window listing every grid square of the correspondents you hear as they come in. Be aware that writes don't come instantly, but rather, in spurts -- potentially, I might add an option to listen to UDP broadcasts in the future instead.

## Compilation

Ballpark is written in [Nim](https://nim-lang.org/). You shouldn't need anything else to compile it, though cross-platform building and producing static binaries is a different matter -- see comments in [ballpark.nimble](ballpark.nimble) for details.

It builds for all flavors of Linux, including Raspbian, as well as Windows command line. There is currently no OSX build and I don't know how to do one properly without building on OSX itself, though there's no reason it shouldn't be possible.

A simple `nimble build` will build an executable for your system, though it will not be the smallest possible, nor the most portable. To produce portable executables for all platforms, use `nimble release`. This is only designed to work on Ubuntu at the moment, if you feel up to helping, pull requests are welcome.

Released binaries are statically compiled and suitable for any Linux on the same CPU. Care was taken to produce small standalone executables with no dependencies.

## Limitations

The city database treats cities as point masses, i.e. they have no area, just coordinates of a point in the center. For many large agglomerations, a grid square that is fully inside of a large city may still result in the name of a *different* city in the surrounding region, when the center of the grid square is actually closer to that smaller city than to the center of the big city itself.

I included some guessing logic based on a city's population given in the database, but it may easily give incorrect results when looking up a four-character grid. There's currently no reasonable way to fix this.

## License

The code herein is licensed under the term of [MIT license](LICENSE).

This project also uses the city database from [SimpleMaps](https://simplemaps.com/data/world-cities), available under the terms of CC-BY 4.0 license. See the [original license documentation](vendor/license.txt).

