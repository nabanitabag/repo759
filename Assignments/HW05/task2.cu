#include <cstdio>
#include <random>

__global__ void compute(int *dA, int a) {
    int x = threadIdx.x;
    int y = blockIdx.x;
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    dA[idx] = a * x + y;
}

int main() {
    const int n = 16;

    int *dA;
    cudaMalloc((void **)&dA, n * sizeof(int));

    std::random_device rd;
    std::mt19937 generator(rd());
    std::uniform_int_distribution<int> distribution(-10, 10);
    int a = distribution(generator);

    compute<<<2, 8>>>(dA, a);
    cudaDeviceSynchronize();

    int hA[n];
    cudaMemcpy(hA, dA, n * sizeof(int), cudaMemcpyDeviceToHost);

    for (int i = 0; i < n; ++i) {
        if (i > 0) {
            std::printf(" ");
        }
        std::printf("%d", hA[i]);
    }
    std::printf("\n");

    cudaFree(dA);
    return 0;
}
