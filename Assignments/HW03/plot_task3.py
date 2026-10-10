#!/usr/bin/env python3
"""Plot Euler merge-sort measurements; print the best threshold for the job."""

import argparse
import csv
import math

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def read_timings(filename, mode):
    key = "threshold" if mode == "threshold" else "threads"
    expected = {2**exponent for exponent in range(1, 11)} if mode == "threshold" else set(range(1, 21))
    timings = {}
    with open(filename, encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source, delimiter="\t")
        if reader.fieldnames != [key, "time_ms"]:
            raise ValueError(f"Expected columns {key} and time_ms.")
        for row in reader:
            value = int(row[key])
            elapsed = float(row["time_ms"])
            if value not in expected or value in timings:
                raise ValueError(f"Unexpected or duplicate {key}: {value}")
            if not math.isfinite(elapsed) or elapsed < 0:
                raise ValueError("Times must be finite and nonnegative.")
            timings[value] = elapsed
    if set(timings) != expected:
        raise ValueError("The timing file must contain the complete sweep.")
    return sorted(timings.items())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["threshold", "threads"])
    parser.add_argument("timings")
    parser.add_argument("output")
    parser.add_argument("best_threshold", nargs="?", type=int)
    args = parser.parse_args()
    if args.mode == "threads" and args.best_threshold is None:
        parser.error("The threads plot requires the selected threshold.")

    timings = read_timings(args.timings, args.mode)
    values, times = zip(*timings)
    fig, ax = plt.subplots(figsize=(8, 5), layout="constrained")
    ax.plot(values, times, marker="o")
    ax.set_ylabel("msort time (ms)")
    ax.set_ylim(bottom=0)
    ax.grid(True, alpha=0.3)
    if args.mode == "threshold":
        best, best_time = min(timings, key=lambda item: (item[1], item[0]))
        # Time is linear; threshold is logarithmic, with powers-of-two ticks.
        ax.set_xscale("log", base=2)
        ax.set_xticks(values, [str(value) for value in values])
        ax.set_xlabel("Threshold (ts, logarithmic scale)")
        ax.set_title("Merge sort: n = 1,000,000, t = 8")
        ax.scatter([best], [best_time], color="tab:red", zorder=3,
                   label=f"Best ts = {best} ({best_time:.3g} ms)")
        ax.legend()
    else:
        ax.set_xticks(values)
        ax.set_xlabel("OpenMP threads (t)")
        ax.set_title(f"Merge sort: n = 1,000,000, ts = {args.best_threshold}")
    fig.savefig(args.output)
    plt.close(fig)
    if args.mode == "threshold":
        print(best)


if __name__ == "__main__":
    main()
