LATEX = pdflatex
TECHDOCS = ast.pdf steadystate.pdf

all: slides.pdf $(TECHDOCS) clean push

slides.pdf: slides.tex ../models/rbc12.mod ../models/rbc12b.mod
	@latexmk -pdf slides
	@latexmk -c

# Technical notes (standalone): AST engine and steady-state algorithms.
ast.pdf: ast.tex
	@latexmk -pdf -shell-escape ast
	@latexmk -c ast

steadystate.pdf: steadystate.tex
	@latexmk -pdf -shell-escape steadystate
	@latexmk -c steadystate

clean:
	rm -f *.aux *.log *.out *.nav *.rel *.toc *.snm *.synctex.gz *.vrb *.rubbercache *.fls *.fdb_latexmk
	rm -rf auto

clean-all:
	rm -f *.pdf

push: slides.pdf $(TECHDOCS)
	cp slides.pdf $(TECHDOCS) ../

.PHONY: push
