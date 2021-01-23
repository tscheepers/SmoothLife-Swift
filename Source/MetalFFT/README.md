FFT (Fast Fourier transform) in Metal shading language
======================

In this folder you will find an implementation of a 2D fast Fourier transform written in Metal shading language and Swift. This is merely simple and unoptimized implementation. If you are not using the GPU for other computations you will probably be better off using [vDSP's FFT](https://developer.apple.com/documentation/accelerate/vdsp/fast_fourier_transforms) functions.

A great video explaining the idea and use cases of the FFT can be found [here](https://www.youtube.com/watch?v=g8RkArhtCc4). Another video explaining the algorithm can be found [here](https://www.youtube.com/watch?v=h7apO7q16V0).

The implementation applies a [GPU kernel](FFT.metal) first `log2(width)` times in the horizontal direction. And then continues to apply it  `log2(height)` times in the vertical direction.

### Comparison to a reference implementation in Python

How does a Metal kernel implementation compare to a more traditional implementation in Python? Well, you can compare the first kernel application to the bottom layer of all the recursive calls in the Python code below. If you concatenated all the resulting arrays at the bottom level of the recursive call stack this would be equal to the result texture after the first kernel application. Each subsequent kernel application corresponds with going up one layer in the recursive call stack. 

```python
from cmath import exp, pi

def fft(x):
    power = len(x)
    
    if power <= 1:
        return x
        
    even = fft(x[0::2])
    odd = fft(x[1::2])
    
    # 1j in python is the same as the complex number i
    oddMultiplied = [exp(-2j*pi*k/power)*odd[k] for k in range(power//2)]

    result = [even[k] + oddMultiplied[k] for k in range(power//2)] + \
           [even[k] - oddMultiplied[k] for k in range(power//2)]

    return result
```
