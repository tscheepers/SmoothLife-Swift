#include <metal_stdlib>
using namespace metal;

kernel void gol_compute_shader(texture2d<float, access::read> current [[texture(0)]],
                               texture2d<float, access::write> next [[texture(1)]],
                               uint2 index [[ thread_position_in_grid ]])
{
    short neighbours = 0;

    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            if (i == 0 && j == 0) {
                continue;
            }
            uint2 neighbour = index + uint2(i, j);
            if (current.read(neighbour).r == 1) {
                neighbours++;
            }
        }
    }

    if (current.read(index).r == 1) {
        if (neighbours < 2 || neighbours > 3) {
          next.write(0, index);
        } else {
          next.write(1, index);
        }
    } else {
        if (neighbours == 3) {
          next.write(1, index);
        } else {
          next.write(0, index);
        }
    }
}
