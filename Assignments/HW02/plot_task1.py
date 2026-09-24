#!/usr/bin/env python3
"""Create a labeled scaling plot from task1 timing data."""

import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def read_timings(filename):
    sizes = []
    times_ms = []

    with open(filename, encoding="utf-8") as timing_file:
        next(timing_file)  # Skip the "n time_ms" header.
        for line in timing_file:
            n, elapsed_ms = line.split()
            sizes.append(int(n))
            times_ms.append(float(elapsed_ms))

    if not sizes:
        raise ValueError("The timing file contains no measurements.")

    return sizes, times_ms


def main():
    if len(sys.argv) != 3:
        raise SystemExit(f"Usage: {sys.argv[0]} <timings.tsv> <output.pdf>")

    sizes, times_ms = read_timings(sys.argv[1])

    figure, axis = plt.subplots(figsize=(7, 4.5))
    axis.plot(sizes, times_ms, marker="o")
    axis.set_xscale("log", base=2)
    axis.set_xlabel("Array size n (elements)")
    axis.set_ylabel("Inclusive scan time (ms)")
    axis.set_title("Inclusive scan scaling")
    axis.grid(True, which="both", linestyle=":")

    figure.tight_layout()
    figure.savefig(sys.argv[2])


if __name__ == "__main__":
    main()
