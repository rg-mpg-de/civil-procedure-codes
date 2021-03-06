    library("textreuse")
    library("stringr")
    library("dplyr")
    source("R/extract_code_names.R")

As a test run for using LSH on all the codes, we are going to run this
on just NY1850 and CA1851 and see if we can detect matches between
sections of that code.

We begin by identifying all of the sections of those two codes:

    paths <- c(Sys.glob("legal-codes-split/NY1850*"), 
               Sys.glob("legal-codes-split/CA1851*"))

That is 2,847 sections. We want to eliminate extremely small sections.
So we are going to check the sizes of all of the files. Since we know
that a file with five words has 32 bytes (using `du -b`) we will remove
all files with fewer than 32 bytes. This will also take care of the
empty `-SPLIT` files that we use for Make tasks. (Addendum, in the
future we will do this by checking the word count directly.)

    sizes <- file.size(paths)
    paths <- paths[sizes >= 34]

Now we have 2,820 sections.

Loading, tokenizing, and minhashing
-----------------------------------

We need an appropriate threshold for LSH. We are aiming for greater than
`0.1`. So these values seem give us a slightly higher threshold.

    lsh_threshold(1500, 500)

    ## [1] 0.1259921

We load and tokenize those files with 4-grams.

    minhash <- minhash_generator(1500, seed = 343653)
    corpus <- TextReuseCorpus(paths = paths, 
                              tokenizer = tokenize_ngrams, n = 4,
                              hash_func = minhash,
                              keep_tokens = TRUE)

Now we can run LSH on the corpus to find the matches.

    buckets <- lsh(corpus, bands = 500)
    candidates <- lsh_candidates(buckets) 
    corpus <- rehash(corpus, hash_string)
    scores <- lsh_compare(candidates, corpus, jaccard_similarity)
    scores_filtered <- scores %>% 
      mutate(code_a = extract_code_names(a),
             code_b = extract_code_names(b)) %>% 
      filter(code_a != code_b)

We have 784 matches between the two codes. If we filter so that we only
keep track of matches with a similarity of `0.1`, there are 522. For
comparison, there are 691 sections in the split CA1851 code.

Conclusions
-----------

We have genuine matches, even on the low Jaccard scores. 4-grams are too
short because phrases like "in the same manner" and "in a civil action"
are very common. We think 5-grams are the best length to avoid common
phrases. The best threshold for distinguishing genuine matches from
false positives is `0.1`.
