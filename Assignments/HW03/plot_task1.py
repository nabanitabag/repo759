#!/usr/bin/env python3
"""Plot HW03 task 1 timings as a linear-linear PDF without dependencies."""

import math
import sys


PAGE_WIDTH = 792
PAGE_HEIGHT = 612
PLOT_LEFT = 90
PLOT_BOTTOM = 85
PLOT_RIGHT = 755
PLOT_TOP = 520


def read_timings(filename):
    timings = {}
    with open(filename, encoding="utf-8") as timing_file:
        next(timing_file, None)
        for line in timing_file:
            thread_count, elapsed_ms = line.split()
            thread_count = int(thread_count)
            elapsed_ms = float(elapsed_ms)
            if not 1 <= thread_count <= 20 or elapsed_ms < 0.0:
                raise ValueError("Expected thread counts 1-20 and nonnegative times.")
            if thread_count in timings:
                raise ValueError(f"Duplicate timing for {thread_count} threads.")
            timings[thread_count] = elapsed_ms

    if set(timings) != set(range(1, 21)):
        raise ValueError("Expected one measurement for every thread count from 1 to 20.")
    return sorted(timings.items())


def pdf_text(x, y, text, size, rotation=0):
    escaped = text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    if rotation == 90:
        return f"BT /F1 {size} Tf 0 1 -1 0 {x} {y} Tm ({escaped}) Tj ET"
    return f"BT /F1 {size} Tf {x} {y} Td ({escaped}) Tj ET"


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
    if len(sys.argv) not in (3, 5):
        raise SystemExit(
            f"Usage: {sys.argv[0]} <timings.tsv> <output.pdf> [title y-axis-label]"
        )

    title = sys.argv[3] if len(sys.argv) == 5 else "HW03 Matrix Multiplication (n = 1024)"
    y_label = sys.argv[4] if len(sys.argv) == 5 else "mmul time (ms)"

    timings = read_timings(sys.argv[1])
    times_ms = [elapsed for _, elapsed in timings]
    y_max = max(times_ms)
    y_max = 1.0 if y_max == 0.0 else 1.05 * y_max
    y_step = nice_step(y_max)
    y_axis_max = math.ceil(y_max / y_step) * y_step
    plot_width = PLOT_RIGHT - PLOT_LEFT
    plot_height = PLOT_TOP - PLOT_BOTTOM

    def x_coordinate(threads):
        return PLOT_LEFT + (threads - 1) * plot_width / 19

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

    for threads in range(1, 21):
        x = x_coordinate(threads)
        commands.extend(
            [
                "0.9 0.9 0.9 RG",
                "0.5 w",
                f"{x:.2f} {PLOT_BOTTOM} m {x:.2f} {PLOT_TOP} l S",
                "0 0 0 RG",
                f"{x:.2f} {PLOT_BOTTOM} m {x:.2f} {PLOT_BOTTOM - 4} l S",
                pdf_text(x - text_width(str(threads), 8) / 2, PLOT_BOTTOM - 17, str(threads), 8),
            ]
        )

    x_label = "OpenMP threads (t)"
    commands.extend(
        [
            "0 0 0 RG",
            "1 w",
            f"{PLOT_LEFT} {PLOT_BOTTOM} m {PLOT_RIGHT} {PLOT_BOTTOM} l S",
            f"{PLOT_LEFT} {PLOT_BOTTOM} m {PLOT_LEFT} {PLOT_TOP} l S",
            pdf_text((PAGE_WIDTH - text_width(title, 16)) / 2, PAGE_HEIGHT - 45, title, 16),
            pdf_text((PAGE_WIDTH - text_width(x_label, 11)) / 2, 35, x_label, 11),
            pdf_text(28, (PAGE_HEIGHT - text_width(y_label, 11)) / 2, y_label, 11, 90),
            "0.12 0.47 0.71 RG",
            "1.5 w",
        ]
    )

    points = [(x_coordinate(threads), y_coordinate(time)) for threads, time in timings]
    commands.append(f"{points[0][0]:.2f} {points[0][1]:.2f} m")
    for x, y in points[1:]:
        commands.append(f"{x:.2f} {y:.2f} l")
    commands.append("S")
    commands.extend(["0.12 0.47 0.71 rg", "0.12 0.47 0.71 RG"])
    for x, y in points:
        commands.append(f"{x - 2:.2f} {y - 2:.2f} 4 4 re f")

    write_pdf(sys.argv[2], commands)


if __name__ == "__main__":
    main()
