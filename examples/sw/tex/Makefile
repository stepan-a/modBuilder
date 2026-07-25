TEXFILES := $(wildcard *.tex)
PDFS     := $(TEXFILES:.tex=.pdf)

all: $(PDFS)

%.pdf: %.tex
	@latexmk -pdf $<
	@latexmk -c $<

clean-all:
	@rm -f *.pdf

.PHONY: all
