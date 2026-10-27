#include <cmath>
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <random>
#include <string>
#include <omp.h>

using std::chrono::high_resolution_clock;
using std::chrono::duration;

const double G = 1.0;
const double softening = 0.1;
const double dt = 0.01;
const double board_size = 4.0;

void getAcc(const double pos[][3], const double mass[], double acc[][3], int N) {
    #pragma omp parallel for schedule(runtime)
    for (int i = 0; i < N; i++) {
        acc[i][0] = 0.0;
        acc[i][1] = 0.0;
        acc[i][2] = 0.0;

        for (int j = 0; j < N; j++) {
            if (i == j) {
                continue;
            }

            const double dx = pos[j][0] - pos[i][0];
            const double dy = pos[j][1] - pos[i][1];
            const double dz = pos[j][2] - pos[i][2];
            const double distance_squared = dx * dx + dy * dy + dz * dz + softening * softening;
            const double inverse_distance_cubed = 1.0 / (distance_squared * std::sqrt(distance_squared));

            acc[i][0] += G * dx * inverse_distance_cubed * mass[j];
            acc[i][1] += G * dy * inverse_distance_cubed * mass[j];
            acc[i][2] += G * dz * inverse_distance_cubed * mass[j];
        }
    }
}

void savePositionsToCSV(const double pos[][3], int N, int step, const std::string &filename) {
    std::ofstream file(filename, std::ios_base::app);
    if (!file.is_open()) {
        std::cerr << "Unable to open file!" << std::endl;
        return;
    }

    file << step << ",[";
    for (int i = 0; i < N; i++) {
        if (i != 0) {
            file << ",";
        }
        file << "[" << pos[i][0] << "," << pos[i][1] << "," << pos[i][2] << "]";
    }
    file << "]\n";
}

int main(int argc, char *argv[]) {
    const high_resolution_clock::time_point start = high_resolution_clock::now();

    if (argc != 4) {
        std::cerr << "Usage: " << argv[0]
                  << " <number_of_particles> <simulation_end_time> <num_threads>" << std::endl;
        return 1;
    }

    int N;
    double tEnd;
    int numThreads;
    try {
        N = std::stoi(argv[1]);
        tEnd = std::stod(argv[2]);
        numThreads = std::stoi(argv[3]);
    } catch (const std::exception &) {
        std::cerr << "Arguments must be a particle count, simulation end time, and thread count." << std::endl;
        return 1;
    }

    if (N <= 0 || !std::isfinite(tEnd) || tEnd < 0.0 || numThreads <= 0) {
        std::cerr << "Particle count and thread count must be positive; end time must be finite and non-negative."
                  << std::endl;
        return 1;
    }

    omp_set_dynamic(0);
    omp_set_num_threads(numThreads);

    // Loops use schedule(runtime): OMP_SCHEDULE picks the policy, static by default.
    if (std::getenv("OMP_SCHEDULE") == nullptr) {
        omp_set_schedule(omp_sched_static, 0);
    }

    double *mass = new double[N];
    double (*pos)[3] = new double[N][3];
    double (*vel)[3] = new double[N][3];
    double (*acc)[3] = new double[N][3];

    std::mt19937 generator(std::random_device{}());
    std::uniform_real_distribution<double> uniform_dist(0.0, 1.0);
    std::normal_distribution<double> normal_dist(0.0, 1.0);

    for (int i = 0; i < N; i++) {
        mass[i] = uniform_dist(generator);
        for (int axis = 0; axis < 3; axis++) {
            pos[i][axis] = normal_dist(generator);
            vel[i][axis] = normal_dist(generator);
        }
    }

    double velCM0 = 0.0;
    double velCM1 = 0.0;
    double velCM2 = 0.0;
    double totalMass = 0.0;
    #pragma omp parallel for reduction(+:velCM0,velCM1,velCM2,totalMass) schedule(runtime)
    for (int i = 0; i < N; i++) {
        velCM0 += vel[i][0] * mass[i];
        velCM1 += vel[i][1] * mass[i];
        velCM2 += vel[i][2] * mass[i];
        totalMass += mass[i];
    }

    if (totalMass == 0.0) {
        std::cerr << "Total particle mass is zero." << std::endl;
        delete[] mass;
        delete[] pos;
        delete[] vel;
        delete[] acc;
        return 1;
    }

    velCM0 /= totalMass;
    velCM1 /= totalMass;
    velCM2 /= totalMass;

    #pragma omp parallel for schedule(runtime)
    for (int i = 0; i < N; i++) {
        vel[i][0] -= velCM0;
        vel[i][1] -= velCM1;
        vel[i][2] -= velCM2;
    }

    getAcc(pos, mass, acc, N);

    const int numSteps = static_cast<int>(tEnd / dt);
    for (int step = 0; step < numSteps; step++) {
        #pragma omp parallel for schedule(runtime)
        for (int i = 0; i < N; i++) {
            for (int axis = 0; axis < 3; axis++) {
                vel[i][axis] += acc[i][axis] * dt / 2.0;
                pos[i][axis] += vel[i][axis] * dt;
                if (pos[i][axis] > board_size) {
                    pos[i][axis] = board_size;
                } else if (pos[i][axis] < -board_size) {
                    pos[i][axis] = -board_size;
                }
            }
        }

        getAcc(pos, mass, acc, N);

        #pragma omp parallel for schedule(runtime)
        for (int i = 0; i < N; i++) {
            for (int axis = 0; axis < 3; axis++) {
                vel[i][axis] += acc[i][axis] * dt / 2.0;
            }
        }

        // Enable this call only when position output is needed; it is I/O intensive.
        // savePositionsToCSV(pos, N, step, "positions.csv");
    }

    delete[] mass;
    delete[] pos;
    delete[] vel;
    delete[] acc;

    const high_resolution_clock::time_point end = high_resolution_clock::now();
    const duration<double, std::milli> elapsed = end - start;
    std::cout << "time: " << elapsed.count() << "ms\n";
    return 0;
}