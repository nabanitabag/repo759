#include <cstdio>
#include <iostream>

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " N\n";
        return 1;
    }

    const int n = std::stoi(argv[1]);

    for (int i = 0; i <= n; ++i) {
        std::printf("%d%s", i, i == n ? "\n" : " ");
    }

    for (int i = n; i >= 0; --i) {
        std::cout << i << (i == 0 ? '\n' : ' ');
    }

    return 0;
}
