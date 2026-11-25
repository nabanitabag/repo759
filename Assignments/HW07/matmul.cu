#include "matmul.cuh"

template <typename T>
__global__ void matmul_kernel(const T *A, const T *B, T *C, unsigned int n) {
    // Raw byte buffer because each template instantiation needs a different element type.
    extern __shared__ __align__(sizeof(double)) unsigned char shared_raw[];
    const unsigned int block_dim = blockDim.x;
    T *As = reinterpret_cast<T *>(shared_raw);
    T *Bs = As + block_dim * block_dim;

    const unsigned int tx = threadIdx.x;
    const unsigned int ty = threadIdx.y;
    const unsigned int row = blockIdx.y * block_dim + ty;
    const unsigned int col = blockIdx.x * block_dim + tx;

    T sum = 0;
    const unsigned int tiles = (n + block_dim - 1) / block_dim;
    for (unsigned int tile = 0; tile < tiles; ++tile) {
        const unsigned int a_col = tile * block_dim + tx;
        const unsigned int b_row = tile * block_dim + ty;
        As[ty * block_dim + tx] =
            (row < n && a_col < n) ? A[static_cast<size_t>(row) * n + a_col] : T(0);
        Bs[ty * block_dim + tx] =
            (b_row < n && col < n) ? B[static_cast<size_t>(b_row) * n + col] : T(0);
        __syncthreads();

        for (unsigned int k = 0; k < block_dim; ++k) {
            sum += As[ty * block_dim + k] * Bs[k * block_dim + tx];
        }
        __syncthreads();
    }

    if (row < n && col < n) {
        C[static_cast<size_t>(row) * n + col] = sum;
    }
}

template <typename T>
static void matmul(const T *A, const T *B, T *C, unsigned int n, unsigned int block_dim) {
    const unsigned int blocks_per_side = (n + block_dim - 1) / block_dim;
    const dim3 grid(blocks_per_side, blocks_per_side);
    const dim3 block(block_dim, block_dim);
    const size_t shared_bytes = 2 * static_cast<size_t>(block_dim) * block_dim * sizeof(T);
    matmul_kernel<T><<<grid, block, shared_bytes>>>(A, B, C, n);
    cudaDeviceSynchronize();
}

__host__ void matmul_1(const int *A, const int *B, int *C, unsigned int n, unsigned int block_dim) {
    matmul(A, B, C, n, block_dim);
}

__host__ void matmul_2(const float *A, const float *B, float *C, unsigned int n,
                       unsigned int block_dim) {
    matmul(A, B, C, n, block_dim);
}

__host__ void matmul_3(const double *A, const double *B, double *C, unsigned int n,
                       unsigned int block_dim) {
    matmul(A, B, C, n, block_dim);
}
