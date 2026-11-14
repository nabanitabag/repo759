#include "stencil.cuh"

__global__ void stencil_kernel(const float *image, const float *mask, float *output, unsigned int n,
                               unsigned int R) {
    extern __shared__ float shared[];
    const unsigned int mask_size = 2 * R + 1;
    const unsigned int tile_size = blockDim.x + 2 * R;
    float *s_mask = shared;
    float *s_image = s_mask + mask_size;
    float *s_output = s_image + tile_size;

    const unsigned int tid = threadIdx.x;
    const long long block_start = static_cast<long long>(blockIdx.x) * blockDim.x;
    const long long i = block_start + tid;

    // blockDim.x >= 2R + 1, so one pass loads the whole mask.
    if (tid < mask_size) {
        s_mask[tid] = mask[tid];
    }

    // The tile covers image[block_start - R, block_start + blockDim.x + R); out-of-range entries are 1.
    for (unsigned int j = tid; j < tile_size; j += blockDim.x) {
        const long long g = block_start - static_cast<long long>(R) + j;
        s_image[j] = (g >= 0 && g < n) ? image[g] : 1.0f;
    }
    __syncthreads();

    if (i < n) {
        float sum = 0.0f;
        for (unsigned int j = 0; j < mask_size; ++j) {
            sum += s_image[tid + j] * s_mask[j];
        }
        s_output[tid] = sum;
        output[i] = s_output[tid];
    }
}

__host__ void stencil(const float *image,
                      const float *mask,
                      float *output,
                      unsigned int n,
                      unsigned int R,
                      unsigned int threads_per_block) {
    const unsigned int blocks = (n + threads_per_block - 1) / threads_per_block;
    const size_t shared_bytes = (2 * static_cast<size_t>(threads_per_block) + 4 * R + 1) * sizeof(float);
    stencil_kernel<<<blocks, threads_per_block, shared_bytes>>>(image, mask, output, n, R);
}
