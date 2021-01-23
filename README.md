SmoothLife in Swift
===============

Implementation of _"[Generalization of Conway's "Game of Life" to a continuous domain - SmoothLife](https://arxiv.org/abs/1111.1567)"_ written in Swift for the iPhone. The current implementation uses [vDSP](https://developer.apple.com/documentation/accelerate/vdsp) for optimized matrix arithmetic and [FFT](https://en.wikipedia.org/wiki/Fast_Fourier_transform). I plan to look at a full implementation in Metal shading language.

I started this project to learn a bit about numeric computation on the GPU and other specialized hardware in a fun way. And also, I think [looking at SmoothLife](https://www.youtube.com/watch?v=KJe9H6qS82I) is just mesmerizing.

My implementation took inspiration from the original [C++ implementation](https://sourceforge.net/projects/smoothlife/) by the paper's author Stephan Rafler, a [Python implementation](https://github.com/duckythescientist/SmoothLife) by [Sean Murphy](https://github.com/duckythescientist), and a Dart/WebGL implementation by [Robert Muth](https://github.com/robertmuth) ([live version](http://art.muth.org/smoothlife.html), [blog article](http://robertmuth.blogspot.com/2016/01/smoothlife-in-webgl.html)). [This blogpost](https://0fps.net/2012/11/19/conways-game-of-life-for-curved-surfaces-part-1/) by [Mikola Lysenko](https://github.com/mikolalysenko/) was a great help as well.

The codebase also includes [a simple implementation](Source/GameOfLife) of the orignal [Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) written in Metal shading language. 

Written in Swift 5.3.2 using Xcode 12.3 for iOS 14.3.

Fast Fourier transform
--------------------

An important part of the implementation is the quick application of convolutions by multiplying in the frequency domain. This requires to transform a representation to the frequency domain and back again using the [fast Fourier transform](https://en.wikipedia.org/wiki/Fast_Fourier_transform). An important aspect of the fast Fourier transform is that it can apply the convolution in `O(n log(n))` if and only if `n` is a power of 2, e.g. `2^8 = 256`. This is why our field's dimenstions are a power of two.

In anticipation of a full implementation in Metal, I've written a [FFT in Metal shading language](Source/MetalFFT). This will allow running the full SmoothLife algorithm on the GPU without going back for the CPU to call vDSP. My hope is this increases performance. You can find the [Metal FFT implementation here](Source/MetalFFT).

