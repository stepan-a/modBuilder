LATEX = pdflatex
TECHDOCS = ast.pdf steadystate.pdf

all: introduction.pdf $(TECHDOCS) clean push

introduction.pdf: introduction.tex ../models/rbc12.mod ../models/rbc12b.mod
	@latexmk -pdf introduction
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

push: introduction.pdf $(TECHDOCS)
	cp introduction.pdf $(TECHDOCS) ../

.PHONY: push
