#!/usr/bin/env python3
"""Plot Euler merge-sort measurements; print the best threshold for the job."""

import argparse
import csv
import math

from plot_task1 import (
    PAGE_WIDTH, PLOT_LEFT, PLOT_RIGHT, PLOT_BOTTOM, PLOT_TOP,
    nice_step, pdf_text, text_width, write_pdf,
)


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
    threshold_mode = args.mode == "threshold"
    best, best_time = min(timings, key=lambda item: (item[1], item[0]))
    title = ("Merge sort: n = 1,000,000, t = 8" if threshold_mode else
             f"Merge sort: n = 1,000,000, ts = {args.best_threshold}")
    x_label = ("Threshold (ts, logarithmic scale)" if threshold_mode else
               "OpenMP threads (t)")
    y_max = max(time for _, time in timings)
    step = nice_step(1.05 * y_max if y_max else 1.0)
    y_max = math.ceil((1.05 * y_max if y_max else 1.0) / step) * step

    def x_coordinate(value):
        fraction = (math.log2(value) - 1) / 9 if threshold_mode else (value - 1) / 19
        return PLOT_LEFT + fraction * (PLOT_RIGHT - PLOT_LEFT)

    def y_coordinate(value):
        return PLOT_BOTTOM + value / y_max * (PLOT_TOP - PLOT_BOTTOM)

    commands = ["0 0 0 rg", "0.5 w"]
    for tick in range(int(round(y_max / step)) + 1):
        value = tick * step
        y = y_coordinate(value)
        label = f"{value:.3g}"
        commands.extend([
            "0.85 0.85 0.85 RG",
            f"{PLOT_LEFT} {y:.2f} m {PLOT_RIGHT} {y:.2f} l S",
            pdf_text(PLOT_LEFT - 12 - text_width(label, 8), y - 3, label, 8),
        ])
    for value, _ in timings:
        x = x_coordinate(value)
        label = str(value)
        commands.extend([
            "0.9 0.9 0.9 RG",
            f"{x:.2f} {PLOT_BOTTOM} m {x:.2f} {PLOT_TOP} l S",
            pdf_text(x - text_width(label, 8) / 2, PLOT_BOTTOM - 17, label, 8),
        ])
    commands.extend([
        "0 0 0 RG", "1 w",
        f"{PLOT_LEFT} {PLOT_TOP} m {PLOT_LEFT} {PLOT_BOTTOM} l {PLOT_RIGHT} {PLOT_BOTTOM} l S",
        pdf_text((PAGE_WIDTH - text_width(title, 16)) / 2, 567, title, 16),
        pdf_text((PAGE_WIDTH - text_width(x_label, 11)) / 2, 35, x_label, 11),
        pdf_text(28, 250, "msort time (ms)", 11, 90),
        "0.12 0.47 0.71 RG", "1.5 w",
    ])
    points = [(x_coordinate(value), y_coordinate(time)) for value, time in timings]
    commands.append(f"{points[0][0]:.2f} {points[0][1]:.2f} m")
    commands.extend(f"{x:.2f} {y:.2f} l" for x, y in points[1:])
    commands.extend(["S", "0.12 0.47 0.71 rg"])
    commands.extend(f"{x-2:.2f} {y-2:.2f} 4 4 re f" for x, y in points)
    if threshold_mode:
        x, y = x_coordinate(best), y_coordinate(best_time)
        commands.extend([
            "0.8 0.15 0.1 rg",
            f"{x-3:.2f} {y-3:.2f} 6 6 re f",
            pdf_text(PLOT_LEFT, 540, f"Best ts = {best} ({best_time:.3g} ms)", 10),
        ])
    write_pdf(args.output, commands)
    if args.mode == "threshold":
        print(best)


if __name__ == "__main__":
    main()
