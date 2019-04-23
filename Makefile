OCR_CODES   := $(patsubst pdf/%.pdf, procedure-codes-ocr/%.txt, $(wildcard pdf/*.pdf))
CLEAN_CODES := $(patsubst procedure-codes-ocr/%.txt, procedure-codes-cleaned/%.txt, $(wildcard procedure-codes-ocr/*.txt))
SPLIT_CODES := $(patsubst procedure-codes-cleaned/%.txt, procedure-codes-sections/%-SPLIT.txt, $(wildcard procedure-codes-cleaned/*.txt))

CLEAN_CCODES := $(patsubst copyright-codes-ocr/%.txt, copyright-codes-cleaned/%.txt, $(wildcard copyright-codes-ocr/*.txt))
SPLIT_CCODES := $(patsubst copyright-codes-cleaned/%.txt, copyright-codes-sections/%.txt, $(wildcard copyright-codes-cleaned/*.txt))

all : cache/corpus-lsh.rda cache/network-graphs.rda article/Funk-Mullen.Spine-of-American-Law.pdf clusters

# Setup tasks
.PHONY : setup packrat dirs

setup : | packrat dirs

packrat :
	Rscript -e "packrat::restore()"

dirs :
	mkdir -p procedure-codes-cleaned proc
	mkdir -p procedure-codes-sections
	mkdir -p out
	mkdir -p out/clusters
	mkdir -p out/figures
	mkdir -p out/matches
	mkdir -p cache

cdirs :
	mkdir -p copyright-codes-cleaned proc
	mkdir -p copyright-codes-sections


# Clean up the codes in `procedure-codes-ocr/`
.PHONY : codes
codes : $(CLEAN_CODES)

procedure-codes-cleaned/%.txt : procedure-codes-ocr/%.txt
	Rscript --vanilla scripts/clean-text.R $^ $@

# Clean up the codes in `copyright-codes-ocr/`
.PHONY : ccodes
ccodes : $(CLEAN_CCODES)

copyright-codes-cleaned/%.txt : copyright-codes-ocr/%.txt
	Rscript --vanilla scripts/clean-text.R $^ $@


# Split the codes into sections
.PHONY : splits
splits : $(SPLIT_CODES)

procedure-codes-sections/%-SPLIT.txt : procedure-codes-cleaned/%.txt
	Rscript --vanilla scripts/split-code.R $^ $@
#	Rscript --vanilla scripts/split-code.R $<
#	@touch $@

# Split the codes into sections
.PHONY : csplits
csplits : $(SPLIT_CCODES)

copyright-codes-sections/%.txt : copyright-codes-cleaned/%.txt
	Rscript --vanilla scripts/split-code.R $^ $@


# Find the similarities in the split codes
.PHONY : lsh
lsh : cache/p-corpus-lsh.rda

cache/p-corpus-lsh.rda : $(SPLIT_CODES)
	Rscript --vanilla scripts/corpus-lsh.R procedure-codes-sections cache/p-corpus-lsh.rda

# Find the similarities in the split codes
.PHONY : clsh
clsh : cache/c-corpus-lsh.rda

cache/c-corpus-lsh.rda : $(SPLIT_CCODES)
	Rscript --vanilla scripts/corpus-lsh.R copyright-codes-sections cache/c-corpus-lsh.rda


# Create the network graph data from the split codes
.PHONY : network
network : cache/p-network-graphs.rda

cache/p-network-graphs.rda : cache/p-corpus-lsh.rda
	Rscript --vanilla scripts/network-graphs.R cache/p-corpus-lsh.rda cache/p-network-graphs.rda

# Create the network graph data from the split copyright codes
.PHONY : cnetwork
cnetwork : cache/c-network-graphs.rda

cache/c-network-graphs.rda : cache/c-corpus-lsh.rda
	Rscript --vanilla scripts/network-graphs.R cache/c-corpus-lsh.rda cache/c-network-graphs.rda


# Create the clusters
.PHONY : clusters
clusters : out/clusters/DONE.txt

out/clusters/DONE.txt : cache/corpus-lsh.rda
	Rscript --vanilla scripts/cluster-sections.R && \
	touch $@

# Create the article
.PHONY : article
article : article/Funk-Mullen.Spine-of-American-Law.pdf

article/Funk-Mullen.Spine-of-American-Law.pdf : article/Funk-Mullen.Spine-of-American-Law.Rmd cache/corpus-lsh.rda cache/network-graphs.rda
	R --slave -e "set.seed(100); rmarkdown::render('$<', output_format = 'all')"

# Update certain files in the research compendium for AHR
.PHONY : compendium
compendium :
	zip -j compendium/all-section-matches.csv.zip out/matches/all_matches.csv
	zip -j compendium/best-section-matches.csv.zip out/matches/best_matches.csv
	zip -r compendium/procedure-codes.zip procedure-codes/
	zip -r compendium/procedure-code-sections.zip procedure-code-sections/
	zip -j -r compendium/clusters-of-sections.zip out/clusters/
	git archive --format=zip --output=compendium/field-code-analysis.zip master

.PHONY : clean
clean :
	rm -rf temp/*

.PHONY : clean-splits
clean-splits :
	rm -f  procedure-codes-cleaned/*
	rm -rf procedure-codes-sections

.PHONY : clean-clusters
clean-clusters :
	rm -rf out/clusters
	rm -f cache/clusters.rds

.PHONY :  clean-compendium
clean-compendium : 
	rm -f compendium/all-section-matches.csv.zip
	rm -f compendium/best-section-matches.csv.zip
	rm -f compendium/procedure-codes.zip
	rm -f compendium/procedure-code-sections.zip
	rm -f compendium/clusters-of-sections.zip
	rm -f compendium/field-code-analysis.zip

.PHONY : clobber
clobber : clean
	rm -f cache/*
	rm -rf out/*

