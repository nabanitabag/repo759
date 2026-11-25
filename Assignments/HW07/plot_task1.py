#!/usr/bin/env python3
"""Plot tiled matmul time vs. n for int, float, and double on log-log axes, as a PDF without dependencies."""

import csv
import math
import sys


PAGE_WIDTH = 792
PAGE_HEIGHT = 612
PLOT_LEFT = 90
PLOT_BOTTOM = 85
PLOT_RIGHT = 755
PLOT_TOP = 520
TYPES = ("int", "float", "double")
COLORS = {"int": (0.12, 0.47, 0.71), "float": (0.8, 0.15, 0.1), "double": (0.2, 0.6, 0.2)}


def read_timings(filename):
    timings = {data_type: {} for data_type in TYPES}
    with open(filename, encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source, delimiter="\t")
        if reader.fieldnames != ["type", "n", "time_ms"]:
            raise ValueError("Expected columns type, n, time_ms.")
        for row in reader:
            data_type = row["type"]
            n = int(row["n"])
            elapsed = float(row["time_ms"])
            if data_type not in timings:
                raise ValueError(f"Unexpected type {data_type}.")
            if n <= 0 or n & (n - 1):
                raise ValueError(f"n must be a power of two, got {n}.")
            if not math.isfinite(elapsed) or elapsed <= 0.0:
                raise ValueError("Times must be finite and positive for a log axis.")
            if n in timings[data_type]:
                raise ValueError(f"Duplicate timing for {data_type}, n={n}.")
            timings[data_type][n] = elapsed

    sizes = set(timings["int"])
    if not sizes or any(set(series) != sizes for series in timings.values()):
        raise ValueError("Every type needs a timing for the same set of n values.")
    return {data_type: sorted(series.items()) for data_type, series in timings.items()}


def pdf_text(x, y, text, size, rotation=0):
    escaped = text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    if rotation == 90:
        return f"BT /F1 {size} Tf 0 1 -1 0 {x:.2f} {y:.2f} Tm ({escaped}) Tj ET"
    return f"BT /F1 {size} Tf {x:.2f} {y:.2f} Td ({escaped}) Tj ET"


def text_width(text, size):
    return len(text) * size * 0.5


def write_pdf(filename, commands):
    stream = "\n".join(commands).encode("ascii")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        (
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 792 612] "
            b"/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>"
        ),
        b"<< /Length " + str(len(stream)).encode("ascii") + b" >>\nstream\n" + stream + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]

    with open(filename, "wb") as pdf_file:
        pdf_file.write(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
        offsets = []
        for number, contents in enumerate(objects, start=1):
            offsets.append(pdf_file.tell())
            pdf_file.write(f"{number} 0 obj\n".encode("ascii"))
            pdf_file.write(contents + b"\nendobj\n")

        xref_offset = pdf_file.tell()
        pdf_file.write(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
        pdf_file.write(b"0000000000 65535 f \n")
        for offset in offsets:
            pdf_file.write(f"{offset:010d} 00000 n \n".encode("ascii"))
        pdf_file.write(
            (
                f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
                f"startxref\n{xref_offset}\n%%EOF\n"
            ).encode("ascii")
        )


def main():
    if len(sys.argv) != 4:
        raise SystemExit(f"Usage: {sys.argv[0]} <timings.tsv> <output.pdf> <block_dim>")

    timings = read_timings(sys.argv[1])
    title = f"HW07 task1: tiled matmul time vs. n (block_dim = {sys.argv[3]})"
    sizes = [n for n, _ in timings["int"]]
    exponent_min = int(math.log2(sizes[0]))
    exponent_max = int(math.log2(sizes[-1]))
    all_times = [elapsed for series in timings.values() for _, elapsed in series]
    decade_min = math.floor(math.log10(min(all_times)))
    decade_max = math.ceil(math.log10(max(all_times)))
    if decade_max == decade_min:
        decade_max += 1
    plot_width = PLOT_RIGHT - PLOT_LEFT
    plot_height = PLOT_TOP - PLOT_BOTTOM

    def x_coordinate(n):
        span = max(exponent_max - exponent_min, 1)
        return PLOT_LEFT + (math.log2(n) - exponent_min) * plot_width / span

    def y_coordinate(time_ms):
        return PLOT_BOTTOM + (math.log10(time_ms) - decade_min) * plot_height / (decade_max - decade_min)

    commands = ["0 0 0 RG", "0 0 0 rg"]
    for decade in range(decade_min, decade_max + 1):
        y = y_coordinate(10.0**decade)
        label = f"{10.0**decade:g}"
        commands.extend(
            [
                "0.85 0.85 0.85 RG",
                "0.5 w",
                f"{PLOT_LEFT} {y:.2f} m {PLOT_RIGHT} {y:.2f} l S",
                "0 0 0 RG",
                f"{PLOT_LEFT - 4} {y:.2f} m {PLOT_LEFT} {y:.2f} l S",
                pdf_text(PLOT_LEFT - 12 - text_width(label, 8), y - 3, label, 8),
            ]
        )

    for exponent in range(exponent_min, exponent_max + 1):
        x = x_coordinate(2**exponent)
        label = f"2^{exponent}"
        commands.extend(
            [
                "0.9 0.9 0.9 RG",
                "0.5 w",
                f"{x:.2f} {PLOT_BOTTOM} m {x:.2f} {PLOT_TOP} l S",
                "0 0 0 RG",
                f"{x:.2f} {PLOT_BOTTOM} m {x:.2f} {PLOT_BOTTOM - 4} l S",
                pdf_text(x - text_width(label, 8) / 2, PLOT_BOTTOM - 17, label, 8),
            ]
        )

    x_label = "n (log scale, base 2)"
    y_label = "time (ms, log scale)"
    commands.extend(
        [
            "0 0 0 RG",
            "1 w",
            f"{PLOT_LEFT} {PLOT_BOTTOM} m {PLOT_RIGHT} {PLOT_BOTTOM} l S",
            f"{PLOT_LEFT} {PLOT_BOTTOM} m {PLOT_LEFT} {PLOT_TOP} l S",
            pdf_text((PAGE_WIDTH - text_width(title, 16)) / 2, PAGE_HEIGHT - 45, title, 16),
            pdf_text((PAGE_WIDTH - text_width(x_label, 11)) / 2, 35, x_label, 11),
            pdf_text(28, (PAGE_HEIGHT - text_width(y_label, 11)) / 2, y_label, 11, 90),
        ]
    )

    for index, data_type in enumerate(TYPES):
        r, g, b = COLORS[data_type]
        points = [(x_coordinate(n), y_coordinate(elapsed)) for n, elapsed in timings[data_type]]
        commands.extend([f"{r} {g} {b} RG", "1.5 w", f"{points[0][0]:.2f} {points[0][1]:.2f} m"])
        commands.extend(f"{x:.2f} {y:.2f} l" for x, y in points[1:])
        commands.extend(["S", f"{r} {g} {b} rg"])
        commands.extend(f"{x - 2:.2f} {y - 2:.2f} 4 4 re f" for x, y in points)

        legend_y = PLOT_TOP - 20 - index * 18
        commands.extend(
            [
                f"{PLOT_LEFT + 20:.2f} {legend_y - 4:.2f} 10 10 re f",
                "0 0 0 rg",
                pdf_text(PLOT_LEFT + 36, legend_y, f"{data_type} (matmul_{index + 1})", 10),
            ]
        )

    write_pdf(sys.argv[2], commands)


if __name__ == "__main__":
    main()
