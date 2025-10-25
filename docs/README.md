# modBuilder Documentation

This directory contains the Sphinx documentation for modBuilder.

## Building the Documentation

### Prerequisites

Install Python dependencies:

```bash
pip install -r docs/requirements.txt
```

### Build HTML Documentation

#### Using Meson (Recommended)

From the project root:

```bash
# Build documentation
meson compile -C build docs

# Or using ninja directly
ninja -C build docs

# Clean documentation
ninja -C build docs-clean
```

#### Using Make

From the `docs` directory:

```bash
cd docs
make html
```

The built documentation will be in `docs/build/html/`. Open `docs/build/html/index.html` in your browser.

### Build PDF Documentation

```bash
make latexpdf
```

Requires LaTeX installation. The PDF will be in `build/latex/`.

### Other Formats

```bash
make epub    # EPUB ebook format
make man     # Unix manual pages
make text    # Plain text
```

### Clean Build Artifacts

```bash
make clean
```

## Documentation Structure

- `source/conf.py` - Sphinx configuration
- `source/index.rst` - Main documentation page
- `source/installation.rst` - Installation guide
- `source/quickstart.rst` - Quick start guide
- `source/user_guide.rst` - Comprehensive user guide
- `source/api.rst` - Complete API reference
- `source/examples.rst` - Examples and use cases
- `source/architecture.rst` - Internal architecture documentation

## Viewing Online

Once built, the documentation can be hosted on:
- GitHub Pages
- Read the Docs
- GitLab Pages
- Any static site hosting service

## Contributing to Documentation

When adding new features to modBuilder:

1. Update relevant sections in `api.rst`
2. Add examples to `examples.rst`
3. Update `user_guide.rst` if it affects usage patterns
4. Rebuild and verify the documentation

## Sphinx Resources

- [Sphinx Documentation](https://www.sphinx-doc.org/)
- [reStructuredText Primer](https://www.sphinx-doc.org/en/master/usage/restructuredtext/basics.html)
- [Read the Docs Theme](https://sphinx-rtd-theme.readthedocs.io/)
