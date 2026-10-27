#!/usr/bin/env python3
"""Plot HW04 task 4 timings (one panel per OpenMP schedule) as a PDF without dependencies."""

import csv
import math
import sys


PAGE_WIDTH = 792
PAGE_HEIGHT = 612
POLICIES = ("static", "dynamic", "guided")
THREADS = range(1, 9)
PANEL_BOTTOM = 95
PANEL_TOP = 500
PANEL_GAP = 70
MARGIN_LEFT = 70
MARGIN_RIGHT = 30


def read_timings(filename):
    timings = {policy: {} for policy in POLICIES}
    with open(filename, encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source, delimiter="\t")
        if reader.fieldnames != ["policy", "threads", "time_ms"]:
            raise ValueError("Expected columns policy, threads, time_ms.")
        for row in reader:
            policy = row["policy"]
            threads = int(row["threads"])
            elapsed = float(row["time_ms"])
            if policy not in timings or threads not in THREADS:
                raise ValueError(f"Unexpected row: {policy}, {threads} threads")
            if threads in timings[policy]:
                raise ValueError(f"Duplicate timing for {policy}, {threads} threads.")
            if not math.isfinite(elapsed) or elapsed < 0.0:
                raise ValueError("Times must be finite and nonnegative.")
            timings[policy][threads] = elapsed

    for policy in POLICIES:
        if set(timings[policy]) != set(THREADS):
            raise ValueError(f"Missing thread counts for the {policy} schedule.")
    return {policy: sorted(values.items()) for policy, values in timings.items()}


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


def draw_panel(commands, left, right, policy, timings):
    times_ms = [elapsed for _, elapsed in timings]
    y_max = max(times_ms)
    y_max = 1.0 if y_max == 0.0 else 1.05 * y_max
    y_step = nice_step(y_max)
    y_axis_max = math.ceil(y_max / y_step) * y_step
    width = right - left
    height = PANEL_TOP - PANEL_BOTTOM

    def x_coordinate(threads):
        return left + (threads - 1) * width / (len(THREADS) - 1)

    def y_coordinate(time_ms):
        return PANEL_BOTTOM + time_ms * height / y_axis_max

    for tick in range(int(round(y_axis_max / y_step)) + 1):
        value = tick * y_step
        y = y_coordinate(value)
        label = f"{value:,.0f}" if value >= 10 else f"{value:.3g}"
        commands.extend(
            [
                "0.85 0.85 0.85 RG",
                "0.5 w",
                f"{left:.2f} {y:.2f} m {right:.2f} {y:.2f} l S",
                "0 0 0 RG",
                f"{left - 4:.2f} {y:.2f} m {left:.2f} {y:.2f} l S",
                pdf_text(left - 8 - text_width(label, 8), y - 3, label, 8),
            ]
        )

    for threads in THREADS:
        x = x_coordinate(threads)
        commands.extend(
            [
                "0.9 0.9 0.9 RG",
                "0.5 w",
                f"{x:.2f} {PANEL_BOTTOM} m {x:.2f} {PANEL_TOP} l S",
                "0 0 0 RG",
                f"{x:.2f} {PANEL_BOTTOM} m {x:.2f} {PANEL_BOTTOM - 4} l S",
                pdf_text(x - text_width(str(threads), 8) / 2, PANEL_BOTTOM - 16, str(threads), 8),
            ]
        )

    title = f"schedule({policy})"
    x_label = "OpenMP threads"
    y_label = "time (ms)"
    commands.extend(
        [
            "0 0 0 RG",
            "1 w",
            f"{left:.2f} {PANEL_BOTTOM} m {right:.2f} {PANEL_BOTTOM} l S",
            f"{left:.2f} {PANEL_BOTTOM} m {left:.2f} {PANEL_TOP} l S",
            pdf_text((left + right - text_width(title, 12)) / 2, PANEL_TOP + 14, title, 12),
            pdf_text((left + right - text_width(x_label, 10)) / 2, PANEL_BOTTOM - 36, x_label, 10),
            pdf_text(left - 46, (PANEL_BOTTOM + PANEL_TOP - text_width(y_label, 10)) / 2, y_label, 10, 90),
            "0.12 0.47 0.71 RG",
            "1.5 w",
        ]
    )

    points = [(x_coordinate(threads), y_coordinate(elapsed)) for threads, elapsed in timings]
    commands.append(f"{points[0][0]:.2f} {points[0][1]:.2f} m")
    for x, y in points[1:]:
        commands.append(f"{x:.2f} {y:.2f} l")
    commands.append("S")
    commands.append("0.12 0.47 0.71 rg")
    for x, y in points:
        commands.append(f"{x - 2:.2f} {y - 2:.2f} 4 4 re f")
    commands.append("0 0 0 rg")


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
    if len(sys.argv) != 5:
        raise SystemExit(
            f"Usage: {sys.argv[0]} <timings.tsv> <output.pdf> <number_of_particles> <simulation_end_time>"
        )

    timings = read_timings(sys.argv[1])
    title = f"HW04 N-body: time vs. threads (N = {sys.argv[3]}, end time = {sys.argv[4]})"
    commands = ["0 0 0 RG", "0 0 0 rg"]
    commands.append(pdf_text((PAGE_WIDTH - text_width(title, 15)) / 2, PAGE_HEIGHT - 50, title, 15))

    panel_width = (PAGE_WIDTH - MARGIN_LEFT - MARGIN_RIGHT - 2 * PANEL_GAP) / len(POLICIES)
    for index, policy in enumerate(POLICIES):
        left = MARGIN_LEFT + index * (panel_width + PANEL_GAP)
        draw_panel(commands, left, left + panel_width, policy, timings[policy])

    write_pdf(sys.argv[2], commands)


if __name__ == "__main__":
    main()
