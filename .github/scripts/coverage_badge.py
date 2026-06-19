#!/usr/bin/env python3
"""Generate a self-contained coverage badge SVG from a Cobertura XML report.

Reads the overall line-rate from coverage.xml and writes a flat-style
"coverage | NN%" badge (no external service: the SVG is rendered locally and
served as a static file). Also prints a one-line summary suitable for a
GitHub Actions job summary.

Usage: coverage_badge.py <coverage.xml> <badge.svg>
"""
import sys
import xml.etree.ElementTree as ET


def colour(pct):
    # Mirror the conventional coverage-badge palette.
    if pct >= 95:
        return '#4c1'      # brightgreen
    if pct >= 90:
        return '#97ca00'   # green
    if pct >= 75:
        return '#a4a61d'   # yellowgreen
    if pct >= 60:
        return '#dfb317'   # yellow
    if pct >= 40:
        return '#fe7d37'   # orange
    return '#e05d44'       # red


def make_svg(pct, fill):
    label, value = 'coverage', f'{pct:.0f}%'
    # 6 px per char + padding is enough for these short strings.
    lw = 6 * len(label) + 10
    vw = 6 * len(value) + 10
    w = lw + vw
    lx = lw * 10 // 2
    vx = (lw + vw // 2) * 10
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="20" role="img" aria-label="{label}: {value}">
  <title>{label}: {value}</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="r"><rect width="{w}" height="20" rx="3" fill="#fff"/></clipPath>
  <g clip-path="url(#r)">
    <rect width="{lw}" height="20" fill="#555"/>
    <rect x="{lw}" width="{vw}" height="20" fill="{fill}"/>
    <rect width="{w}" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="110" text-rendering="geometricPrecision">
    <text x="{lx}" y="150" transform="scale(.1)" fill="#010101" fill-opacity=".3" textLength="{(lw-10)*10}">{label}</text>
    <text x="{lx}" y="140" transform="scale(.1)" textLength="{(lw-10)*10}">{label}</text>
    <text x="{vx}" y="150" transform="scale(.1)" fill="#010101" fill-opacity=".3" textLength="{(vw-10)*10}">{value}</text>
    <text x="{vx}" y="140" transform="scale(.1)" textLength="{(vw-10)*10}">{value}</text>
  </g>
</svg>
'''


def main():
    src, out = sys.argv[1], sys.argv[2]
    root = ET.parse(src).getroot()
    pct = float(root.get('line-rate')) * 100
    with open(out, 'w') as f:
        f.write(make_svg(pct, colour(pct)))
    covered, valid = root.get('lines-covered'), root.get('lines-valid')
    print(f'{pct:.1f}% ({covered}/{valid} lines)')


if __name__ == '__main__':
    main()
