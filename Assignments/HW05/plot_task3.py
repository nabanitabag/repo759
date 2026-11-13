#!/usr/bin/env python3
"""Plot HW05 task3 vscale timings (512 vs. 16 threads/block) as a PDF without dependencies."""

import csv
import math
import sys


PAGE_WIDTH = 792
PAGE_HEIGHT = 612
PLOT_LEFT = 90
PLOT_BOTTOM = 85
PLOT_RIGHT = 755
PLOT_TOP = 520
EXPONENTS = range(10, 30)
CONFIGS = (512, 16)
COLORS = {512: (0.12, 0.47, 0.71), 16: (0.8, 0.15, 0.1)}


def read_timings(filename):
    timings = {config: {} for config in CONFIGS}
    with open(filename, encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source, delimiter="\t")
        if reader.fieldnames != ["threads_per_block", "n", "time_ms"]:
            raise ValueError("Expected columns threads_per_block, n, time_ms.")
        for row in reader:
            config = int(row["threads_per_block"])
            n = int(row["n"])
            elapsed = float(row["time_ms"])
            if config not in timings or n not in {2**exponent for exponent in EXPONENTS}:
                raise ValueError(f"Unexpected row: {config} threads/block, n={n}")
            if n in timings[config]:
                raise ValueError(f"Duplicate timing for {config} threads/block, n={n}.")
            if not math.isfinite(elapsed) or elapsed < 0.0:
                raise ValueError("Times must be finite and nonnegative.")
            timings[config][n] = elapsed

    expected = {2**exponent for exponent in EXPONENTS}
    for config in CONFIGS:
        if set(timings[config]) != expected:
            raise ValueError(f"Missing n values for {config} threads/block.")
    return {config: sorted(values.items()) for config, values in timings.items()}


def pdf_text(x, y, text, size, rotation=0):
    escaped = text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    if rotation == 90:
        return f"BT /F1 {size} Tf 0 1 -1 0 {x:.2f} {y:.2f} Tm ({escaped}) Tj ET"
    return f"BT /F1 {size} Tf {x:.2f} {y:.2f} Td ({escaped}) Tj ET"


def text_width(text, size):
    return len(text) * size * 0.5


def nice_step(value):
    rough_step = value / 5.0
    magnitude = 10.0 ** math.floor(math.log10(rough_step))
    normalized = rough_step / magnitude
    for candidate in (1.0, 2.0, 2.5, 5.0, 10.0):
        if normalized <= candidate:
            return candidate * magnitude
    return 10.0 * magnitude


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
    if len(sys.argv) != 3:
        raise SystemExit(f"Usage: {sys.argv[0]} <timings.tsv> <output.pdf>")

    timings = read_timings(sys.argv[1])
    y_max = max(elapsed for series in timings.values() for _, elapsed in series)
    y_max = 1.0 if y_max == 0.0 else 1.05 * y_max
    y_step = nice_step(y_max)
    y_axis_max = math.ceil(y_max / y_step) * y_step
    plot_width = PLOT_RIGHT - PLOT_LEFT
    plot_height = PLOT_TOP - PLOT_BOTTOM
    exponent_span = EXPONENTS[-1] - EXPONENTS[0]

    def x_coordinate(n):
        return PLOT_LEFT + (math.log2(n) - EXPONENTS[0]) * plot_width / exponent_span

    def y_coordinate(time_ms):
        return PLOT_BOTTOM + time_ms * plot_height / y_axis_max

    commands = ["0 0 0 RG", "0 0 0 rg"]
    tick_count = int(round(y_axis_max / y_step))
    for tick in range(tick_count + 1):
        value = tick * y_step
        y = y_coordinate(value)
        label = f"{value:.3g}"
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

    for exponent in EXPONENTS:
        x = x_coordinate(2**exponent)
        label = f"2^{exponent}"
        commands.extend(
            [
                "0.9 0.9 0.9 RG",
                "0.5 w",
                f"{x:.2f} {PLOT_BOTTOM} m {x:.2f} {PLOT_TOP} l S",
                "0 0 0 RG",
                f"{x:.2f} {PLOT_BOTTOM} m {x:.2f} {PLOT_BOTTOM - 4} l S",
                pdf_text(x - text_width(label, 7) / 2, PLOT_BOTTOM - 17, label, 7),
            ]
        )

    title = "HW05 task3: vscale time vs. n"
    x_label = "n (logarithmic scale, base 2)"
    y_label = "vscale time (ms)"
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

    for config in CONFIGS:
        r, g, b = COLORS[config]
        points = [(x_coordinate(n), y_coordinate(elapsed)) for n, elapsed in timings[config]]
        commands.extend([f"{r} {g} {b} RG", "1.5 w"])
        commands.append(f"{points[0][0]:.2f} {points[0][1]:.2f} m")
        for x, y in points[1:]:
            commands.append(f"{x:.2f} {y:.2f} l")
        commands.append("S")
        commands.append(f"{r} {g} {b} rg")
        for x, y in points:
            commands.append(f"{x - 2:.2f} {y - 2:.2f} 4 4 re f")

    legend_x = PLOT_LEFT + 20
    legend_y = PLOT_TOP - 20
    commands.append("0 0 0 rg")
    for index, config in enumerate(CONFIGS):
        r, g, b = COLORS[config]
        y = legend_y - index * 18
        label = f"{config} threads/block"
        commands.extend(
            [
                f"{r} {g} {b} rg",
                f"{legend_x:.2f} {y - 4:.2f} 10 10 re f",
                "0 0 0 rg",
                pdf_text(legend_x + 16, y, label, 10),
            ]
        )

    write_pdf(sys.argv[2], commands)


if __name__ == "__main__":
    main()
