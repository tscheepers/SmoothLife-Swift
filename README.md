SmoothLife in Swift
===============

Implementation of _"[Generalization of Conway's "Game of Life" to a continuous domain - SmoothLife](https://arxiv.org/abs/1111.1567)"_ written in Swift for the iPhone. The current implementation uses [vDSP](https://developer.apple.com/documentation/accelerate/vdsp) for optimized matrix arithmetic and [FFT](https://en.wikipedia.org/wiki/Fast_Fourier_transform). I plan to look at a full implementation in Metal shading language.

I took inspiration from the original [C++ implementation](https://sourceforge.net/projects/smoothlife/) by the paper's author Stephan Rafler, a [Python implementation](https://github.com/duckythescientist/SmoothLife) by [Sean Murphy](https://github.com/duckythescientist), and a Dart/WebGL implementation by [Robert Muth](https://github.com/robertmuth) ([live version](http://art.muth.org/smoothlife.html), [blog article](http://robertmuth.blogspot.com/2016/01/smoothlife-in-webgl.html)). [This blogpost](https://0fps.net/2012/11/19/conways-game-of-life-for-curved-surfaces-part-1/) by [Mikola Lysenko](https://github.com/mikolalysenko/) was a great help as well.

The codebase also includes [a simple implementation](Source/GameOfLife) of the orignal [Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) written in Metal shading language. 
