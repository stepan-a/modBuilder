LATEX = pdflatex

all: slides.pdf clean push

slides.pdf: slides.tex ../models/rbc12.mod ../models/rbc12b.mod
	@latexmk -pdf slides
	@latexmk -c

clean:
	rm -f *.aux *.log *.out *.nav *.rel *.toc *.snm *.synctex.gz *.vrb
	rm -rf auto

clean-all:
	rm -f *.pdf

push: slides.pdf
	cp slides.pdf ../

.PHONY: push
