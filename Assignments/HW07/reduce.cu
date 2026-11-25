#include "reduce.cuh"

#include <utility>

__global__ void reduce_kernel(float *g_idata, float *g_odata, unsigned int n) {
    extern __shared__ float sdata[];
    const unsigned int tid = threadIdx.x;
    const unsigned int i = blockIdx.x * (blockDim.x * 2) + tid;

    // First add during global load: each thread sums two elements one block apart.
    float sum = 0.0f;
    if (i < n) {
        sum = g_idata[i];
    }
    if (i + blockDim.x < n) {
        sum += g_idata[i + blockDim.x];
    }
    sdata[tid] = sum;
    __syncthreads();

    // Sequential addressing; rounding the half up keeps it correct when blockDim.x isn't a power of 2.
    for (unsigned int active = blockDim.x; active > 1;) {
        const unsigned int half = (active + 1) / 2;
        if (tid < active - half) {
            sdata[tid] += sdata[tid + half];
        }
        __syncthreads();
        active = half;
    }

    if (tid == 0) {
        g_odata[blockIdx.x] = sdata[0];
    }
}

__host__ void reduce(float **input, float **output, unsigned int N, unsigned int threads_per_block) {
    const size_t shared_bytes = threads_per_block * sizeof(float);
    const unsigned int elements_per_block = 2 * threads_per_block;
    for (unsigned int n = N; n > 1;) {
        const unsigned int blocks = (n + elements_per_block - 1) / elements_per_block;
        reduce_kernel<<<blocks, threads_per_block, shared_bytes>>>(*input, *output, n);
        // The partial sums become the next pass's input, so the final sum lands in (*input)[0].
        std::swap(*input, *output);
        n = blocks;
    }
    cudaDeviceSynchronize();
}
