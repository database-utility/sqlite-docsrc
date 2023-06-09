###############################################################################
# The following macros should be defined before this script is
# invoked:
#
# TCLINC           Extra -I options needed to find the TCL header files
#
# TCLFLAGS         Extra C-compiler options needed to link against TCL
#
# CC               A C-compiler and arguments for building utility programs
#
# The remaining variables all refer to directories that contain source
# material for the documentation.  These directories should all be considered
# read-only.  Build products are written into the directory from which
# "make" was run (DEST) and subdirectories, only.
#
# DOC              The toplevel directory of the documentation source tree.
#
# SRC              The toplevel directory of the source code source tree.
#
# BLD              The directory in which the current source code has been
#                  built using "make sqlite3.c sqlite3"
#
# TH3              The toplevel directory for TH3.  May be an empty string.
#
# SLT              The toplevel directory for SQLLogicTest.  May be an
#                  empty string
#
# Once the macros above are defined, the rest of this make script will
# build the SQLite library and testing tools.
################################################################################

DEST = .

TCLSH = $(DEST)/tclsh.docsrc

default:
	@echo 'make base;       # Build base documents'
	@echo 'make evidence;   # Gather evidence marks'
	@echo 'make matrix;     # Build the traceability matrix'
	@echo 'make searchdb;   # Construct the FTS search database'
	@echo 'make all;        # Do all of the above'
	@echo 'make spell;      # Spell check generated docs'
	@echo 'make fast;       # Build documentation only - no requirements'
	@echo 'make faster;     # Like fast, except build is incremental'
	@echo 'make schema;     # Run once to initialize the build process'
	@echo 'make private;    # Everything except searchdb'
	@echo 'make versions;   # Update SQLite release version list'
	@echo 'make linkcheck;  # Create hyperlink check DB, hlcheck.db'

all:	base evidence format_evidence matrix doc searchdb

private:	base evidence private_evidence matrix doc

fast:	base doc

$(DEST)/sqlite3.h: $(BLD)/sqlite3.h
	cp $(BLD)/sqlite3.h $(DEST)/orig-sqlite3.h
	sed 's/^SQLITE_API //' $(DEST)/orig-sqlite3.h >$(DEST)/sqlite3.h

# Generate the directory tree into which generated documentation files will
# be written.
#
docdir:
	mkdir -p $(DEST)/doc $(DEST)/doc/c3ref $(DEST)/doc/matrix
	mkdir -p $(DEST)/doc/matrix/c3ref $(DEST)/doc/matrix/syntax

# With build option CHECKOUT_ONLY=1, only files belonging to checkout are used.
ifdef CHECKOUT_ONLY
CPIO_PASS_OPTS = --pass-through --make-directories --quiet --unconditional
PAGES_IN = $$(cd $(DOC); fossil ls pages | sed -e '/\.in$$/! d ; s/^/.\//')
RAW_PAGES = $$(cd $(DOC); fossil ls rawpages)
COPY_RAW_PAGES = cp --target-directory=$(DEST)/doc $(RAW_PAGES)
COPY_IMAGES = $$(cd $(DOC); fossil ls images | cpio $(CPIO_PASS_OPTS) ./doc)
else
PAGES_IN = $(DOC)/pages/*.in
COPY_RAW_PAGES = cp $(DOC)/rawpages/* $(DEST)/doc
COPY_IMAGES = cp -r $(DOC)/images $(DEST)/doc
endif

HTMLGEN = $(TCLSH) $(DOC)/wrap.tcl

# This rule generates all documention files from their sources.  The
# special markup on HTML files used to identify testable statements and
# requirements are retained in the HTML and so the HTML generated by
# this rule is not suitable for publication.  This is the first step
# only.
#
base:	$(TCLSH) $(DEST)/sqlite3.h docdir schema always
	rm -rf $(DEST)/doc/images
	$(COPY_IMAGES)
	$(COPY_RAW_PAGES)
	$(HTMLGEN) $(DOC) $(SRC) $(DEST)/doc $(PAGES_IN)
	cp $(DEST)/doc/fileformat2.html $(DEST)/doc/fileformat.html

# Strip the special markup in HTML files that identifies testable statements
# and requirements. (Not needed for releaselog/ or syntax/ .html files.)
#
DECARETSX = $(DEST)/doc/c3ref/'*.html' $(DEST)/doc/session/'*.html'
doc $(DEST)/doc/toc.db:	base $(DOC)/remove_carets.tcl
	$(TCLSH) $(DOC)/remove_carets.tcl $(DEST)/doc/'*.html' $(DECARETSX)
	cp $(DEST)/toc.db $(DEST)/doc

# These rules generate documention files from their outdated sources,
# similarly to the base and doc targets combined. The build is faster
# because it does not copy, revisit or transform unchanged inputs.
# Target faster is unproven as suitable for publication, so should
# be used only for expedient checking of results during development.
$(DEST)/version_dates.txt : $(DOC)/pages/chronology.tcl
	egrep -e '^[[:xdigit:]]{10}\|[0-9]{4}(-[0-9][0-9]){2}\|Version' $< >$@

GENS = $(DEST)/pages_generated
faster:	$(TCLSH) $(DEST)/sqlite3.h docdir schema
	$(COPY_IMAGES)
	$(COPY_RAW_PAGES)
	$(HTMLGEN) -update $(GENS) $(DOC) $(SRC) $(DEST)/doc $(PAGES_IN)
	cp --update $(DEST)/doc/fileformat2.html $(DEST)/doc/fileformat.html
	$(TCLSH) $(DOC)/remove_carets.tcl -at $(GENS) $(DECARETSX)

# Possibly bring versions info list in ./pages/chronology.tcl up to date.
# This will get that done if ../sqlite is a SQLite library check-out and
# its release tags continue to have the format established circa 2009.
# It will either fail and say why, indicate nothing done, or revise the
# list and issue a reminder to commit the ./pages/chronology.tcl change.
versions:
	$(TCLSH) $(DOC)/regen_version_list.tcl

# Spell check generated docs.
#
spell: $(DOC)/spell_chk.sh $(DOC)/custom.txt
	sh $(DOC)/spell_chk.sh doc '*.html' custom.txt

# Construct the database schema and DB having it.
# This is idempotent, without effect if needless.
#
schema $(DEST)/docinfo.db:	$(TCLSH)
	$(TCLSH) $(DOC)/schema.tcl

# The following rule scans sqlite3.c source text, the text of the TCL
# test cases, and (optionally) the TH3 test case sources looking for
# comments that identify assertions and test cases that provide evidence
# that SQLite behaves as it says it does.  See the comments in
# scan_test_cases.tcl for additional information.
#
# The output file evidence.txt is used by requirements coverage analysis.
#
SCANNER = $(DOC)/scan_test_cases.tcl

evidence:	$(TCLSH)
	$(TCLSH) $(SCANNER) -reset src $(SRC)/src/*.[chy]
	$(TCLSH) $(SCANNER) src $(SRC)/ext/fts3/*.[ch]
	$(TCLSH) $(SCANNER) src $(SRC)/ext/rtree/*.h
	$(TCLSH) $(SCANNER) src $(SRC)/ext/rtree/rtree.c
	$(TCLSH) $(SCANNER) src $(SRC)/ext/rtree/geopoly.c
	$(TCLSH) $(SCANNER) tcl $(SRC)/ext/rtree/test_rtreedoc.c
	$(TCLSH) $(SCANNER) tcl $(SRC)/ext/rtree/*.test
	$(TCLSH) $(SCANNER) tcl $(SRC)/test/*.test
	if test '' != '$(TH3)'; then \
	  $(TCLSH) $(SCANNER) th3 $(TH3)/mkth3.tcl; \
	  $(TCLSH) $(SCANNER) th3 $(TH3)/base/*.c; \
	  $(TCLSH) $(SCANNER) th3/req1 $(TH3)/req1/*.test; \
	  $(TCLSH) $(SCANNER) th3/cov1 $(TH3)/cov1/*.test; \
	  $(TCLSH) $(SCANNER) th3/stress $(TH3)/stress/*.test; \
	fi
	if test '' != '$(SLT)'; then \
	  $(TCLSH) $(SCANNER) slt $(SLT)/test/evidence/*.test; \
	fi

# Copy and HTMLize evidence files
#
FMT = $(DOC)/format_evidence.tcl

format_evidence: $(TCLSH)
	rm -fr $(DEST)/doc/matrix/ev/*
	$(TCLSH) $(FMT) src $(DEST)/doc/matrix $(SRC)/src/*.[chy]
	$(TCLSH) $(FMT) src $(DEST)/doc/matrix $(SRC)/ext/fts3/*.[ch]
	$(TCLSH) $(FMT) src $(DEST)/doc/matrix $(SRC)/ext/rtree/*.[ch]
	$(TCLSH) $(FMT) tcl $(DEST)/doc/matrix $(SRC)/test/*.test
	if test '' != '$(SLT)'; then \
	  $(TCLSH) $(FMT) slt $(DEST)/doc/matrix $(SLT)/test/evidence/*.test; \
	fi

private_evidence: format_evidence
	$(TCLSH) $(FMT) th3 $(DEST)/doc/matrix $(TH3)/mkth3.tcl
	$(TCLSH) $(FMT) th3/req1 $(DEST)/doc/matrix $(TH3)/req1/*.test
	$(TCLSH) $(FMT) th3/cov1 $(DEST)/doc/matrix $(TH3)/cov1/*.test

# Generate the traceability matrix
#
# matrix: base
# 	rm -rf $(DEST)/doc/matrix/images
# 	cp -r $(DEST)/doc/images $(DEST)/doc/matrix
# 	cp $(DOC)/rawpages/sqlite.css $(DEST)/doc/matrix
# 	$(TCLSH) $(DOC)/matrix.tcl

#-------------------------------------------------------------------------
# Hyperlink checking for the ready-to-publish doc tree

HLCHK_DB = $(DEST)/hlcheck.db
URLCHK = $(DOC)/urlcheck --ok-silent
DOCHTML = $$(find $(DEST)/doc -name '*.html' -print)
NBPL = $$(echo 'SELECT count(*) FROM BrokenPageLinks go' | sqlite3 $(HLCHK_DB))
NMFL = $$(echo 'SELECT count(*) FROM BrokenFragLinks go' | sqlite3 $(HLCHK_DB))

linkcheck $(HLCHK_DB): urlcheck
	@$(TCLSH) $(DOC)/hlinkchk.tcl $(DEST)/doc $(HLCHK_DB) $(DOCHTML)
	@echo There are $(NBPL) broken internal page hyperlinks
	@echo and $(NMFL) missed internal page fragment targets.
	@echo 'External URIs can be checked via "make uris_check".'

# Checking web URIs takes awhile, so make this target rarely.
Q_EXT_URI = 'SELECT * FROM ExtHttpLinks;'
uris_check: $(HLCHK_DB)
	@echo This check takes several minutes to run. Silence is success.
	@echo $(Q_EXT_URI) | sqlite3 $(HLCHK_DB) | $(URLCHK)

#-------------------------------------------------------------------------

# Source files for the [tclsqlite3.search] executable.
#
SSRC = $(DOC)/search/searchc.c \
	    $(DOC)/search/parsehtml.c \
	    $(DOC)/search/fts5ext.c \
	    $(DOC)/search/pikchr.c \
	    $(SRC)/src/test_md5.c \
	    $(BLD)/tclsqlite3.c

# Flags to build [tclsqlite3.search] with.
#
SFLAGS = $(TCLINC) \
  -DSQLITE_THREADSAFE=0 \
  -DSQLITE_ENABLE_FTS5 \
  -DSQLITE_TCLMD5 \
  -DPIKCHR_TCL \
  -DTCLSH -Dmain=xmain

$(TCLSH): $(SSRC)
	$(CC) -O2 -o $@ -I. $(SFLAGS) $(SSRC) $(TCLFLAGS)

# The stand-alone pikchr utility.
pikchr:	$(DOC)/search/pikchr.c
	$(CC) -o $@ -DPIKCHR_SHELL $(DOC)/search/pikchr.c -lm

$(DEST)/doc/search:	$(TCLSH) $(DOC)/search/mkscript.tcl \
 $(DOC)/search/search.tcl.in $(DOC)/search/wapp.tcl $(DOC)/document_header.tcl
	$(TCLSH) $(DOC)/search/mkscript.tcl $(DOC)/search/search.tcl.in >$@
	chmod 744 $@

$(DEST)/doc/search.d/admin:	$(TCLSH) $(DOC)/search/mkscript.tcl \
 $(DOC)/search/admin.tcl.in $(DOC)/search/wapp.tcl $(DOC)/document_header.tcl
	mkdir -p $(DEST)/doc/search.d/
	$(TCLSH) $(DOC)/search/mkscript.tcl $(DOC)/search/admin.tcl.in >$@
	chmod 744 $(DEST)/doc/search.d/admin

searchdb: $(TCLSH) $(DEST)/doc/search $(DEST)/doc/search.d/admin
	$(TCLSH) $(DOC)/search/buildsearchdb.tcl

urlcheck: $(DOC)/urlcheck.c
	$(CC) -Os $(DOC)/urlcheck.c -o $@ -lcurl

#	cp $(DOC)/search/search.tcl $(DEST)/doc/search.d/admin
#	chmod +x $(DEST)/doc/search.d/admin

$(DEST)/fts5ext.so:	$(DOC)/search/fts5ext.c
	gcc -shared -fPIC -I$(DOC) -DSQLITE_EXT \
		$(DOC)/search/fts5ext.c -o $@

# Build the "docsapp" application by adding an appropriate SQLAR
# repository onto the end of the "sqltclsh" application.
#
DABUILD = '.read $(DOC)/docapp/build.sql'
$(DEST)/docsapp: faster $(DOC)/docapp/main.tcl $(DOC)/docapp/wapp.tcl $(DABUILD)
	cp $(DOC)/docapp/main.tcl $(DOC)/docapp/wapp.tcl .
	cp $(BLD)/sqltclsh $@
	echo .q | $(BLD)/sqlite3 -append -batch -cmd $(DABUILD) $@
	chmod +x $@

always:

# Remove intermediate build products.
clean:
	-rm -f $(DEST)/chronology.json $(DEST)/doc_vardump.txt
	-rm -f $(DEST)/orig-sqlite3.h $(DEST)/toc.db $(DEST)/docinfo.db
	-rm -f $(DEST)/history.db $(DEST)/main.tcl $(DEST)/sqlite3.h
	-rm -f $(DEST)/wapp.tcl $(GENS)

# Remove end-products of build too.
cleaner:  clean
	-rm -rf $(DEST)/doc
	-rm -f $(TCLSH) $(DEST)/docsapp $(DEST)/docs.sqlar
