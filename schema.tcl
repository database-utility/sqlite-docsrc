#!/usr/bin/tclsh
#
# Run this script to create two database files "docinfo.db" and "history.db"
# with appropriate schemas.
#
package require sqlite3 ;# Needed if run by stock tclsh

set ::DOC [file dir [info script]]

sqlite3 db [file join $::DOC docinfo.db]
db eval {
  BEGIN;

  /*
  ** Every page in the documentation set is a row in the following table:
  */
  CREATE TABLE IF NOT EXISTS page(
    pageid INTEGER PRIMARY KEY,           -- ID for internal use only
    pagetitle TEXT,                       -- Brief title of the page
    pageabstract TEXT,                    -- Verbose title of the page
    filename TEXT UNIQUE NOT NULL,        -- Name of the HTML file
    parent INTEGER REFERENCES page        -- Aggregate page.  Usually NULL
  );
  CREATE INDEX IF NOT EXISTS page_parent ON page(parent);

  /*
  ** Alternative titles for pages
  */
  CREATE TABLE IF NOT EXISTS alttitle(
    alttitle TEXT,                      -- Alternative title
    pageid INTEGER REFERENCES page      -- The page with the alternative title
  );

  /*
  ** Processed pages/*.in file info in support of minimal generated
  ** page updating. The file attributes kept allow determination
  ** of whether the file on disk is newer or different from what it
  ** was when last scanned.
  **
  ** The file will need a rescan if its md5_digest or file_length
  ** do not match these data, and its md5_digest will need to be
  ** taken if its mod_time or file_length do not match.
  */
  CREATE TABLE IF NOT EXISTS pages_in(
    fileid INTEGER PRIMARY KEY,
    file_name TEXT UNIQUE,              -- its name (as openable)
    file_length INTEGER,                -- length on disk
    mod_time INTEGER,                   -- modification timestamp
    md5_digest TEXT                     -- md5 digest of content
  );

  /*
  ** Link items, both definitions and references. These are associated
  ** with the pages/*.in sources which provide the definitions or make
  ** reference to them. This supports incremental doc builds, allowing
  ** use of this data in lieu of scanning up-to-date sources for links
  ** either defined or to be resolved or not.
  */
  CREATE TABLE IF NOT EXISTS scan_links(
    tag TEXT,                              -- the key within source
    target TEXT,                           -- URL link resolves to
    kind INT,                              -- GLOBAL LOCAL BACK PAGE GLREF
    fileid INT REFERENCES pages_in(fileid),-- where link defined
    UNIQUE(tag,fileid,kind) ON CONFLICT REPLACE
  );

  /*
  ** Each page has one or more fragments.  The first fragment has
  ** a NULL name.  All other fragments are named.
  */
  CREATE TABLE IF NOT EXISTS fragment(
    fragid INTEGER PRIMARY KEY,               -- ID for internal use only
    pageid INTEGER NOT NULL REFERENCES page,  -- Part of this page
    fragname TEXT NOT NULL,                   -- Name or NULL for main fragment
    fragtitle TEXT                -- Optional title for this fragment
  );
  CREATE INDEX IF NOT EXISTS fragment_pageid ON fragment(pageid);

  /*
  ** Keywords used to identify link targets.
  */
  CREATE TABLE IF NOT EXISTS keyword(
    kwid INTEGER PRIMARY KEY,                -- ID  for internal use only
    kw TEXT UNIQUE NOT NULL COLLATE nocase,  -- The keyword or keyphrase
    indexKw BOOLEAN NOT NULL,                -- Show in the keyword doc index
    fragment TEXT                            -- Fragment keyword refers to
  );

  /*
  ** Each row in this table records a hyperlink to a keyword.  The
  ** source and destination of the hyperlink are recorded.
  */
  CREATE TABLE IF NOT EXISTS link(
    fromfrag INTEGER REFERENCES fragment, -- From this fragment
    tokw INTEGER REFERENCES keyword       -- To this keyword
  );
  CREATE INDEX IF NOT EXISTS link_from ON link(fromfrag);
  CREATE INDEX IF NOT EXISTS link_to ON link(tokw);

  /* Requirements or Testable Statements Of Truth (Tsots).
  ** These are extracts from the documentation that define what
  ** the product does and how it performs.
  */
  CREATE TABLE IF NOT EXISTS requirement(
    rid INTEGER PRIMARY KEY, -- Requirement ID for internal use only
    reqno TEXT UNIQUE,       -- Ex: R-12345-67890-...
    reqimage BOOLEAN,        -- True for an image requirement
    reqtext TEXT,            -- Normalized text of requirement or image filename
    origtext TEXT,           -- Original, unnormalized text
    srcfile TEXT,            -- Document from which first extracted
    srcseq INTEGER,          -- Sequence within the same document
    UNIQUE(srcfile,srcseq)
  );

  /* The source text for a requirement.  Some requirements (especially
  ** syntax diagram images) can occur in multiple places.
  */
  CREATE TABLE IF NOT EXISTS reqsrc(
    srcfile TEXT,            -- Document from which extracted
    srcseq INTEGER,          -- Sequence within the same document
    reqno TEXT,              -- The requirement that is repeated
    PRIMARY KEY(srcfile,srcseq)
  ) WITHOUT ROWID;

  /* Image requirements can appear at multiple places in the text. */

  /* Evidence of fulfillment of a requirement is recorded in this table.
  */
  CREATE TABLE IF NOT EXISTS evidence(
    reqno TEXT,              -- Prefix of a requirement number
    reqtext TEXT,            -- Normalized requirement text taken from source
    evtype TEXT,             -- evidence, implementation, assert, testcase
    srcclass TEXT,           -- source class:  tcl, th3, src
    srccat TEXT,             -- source category.  Ex: tcl, th3/cov1
    srcfile TEXT,            -- document from which evidence extracted
    srcline INTEGER,         -- line number in source document
    url TEXT,                -- URL & fragment of htmlized evidence
    UNIQUE(srcfile, srcline, srccat)
  );
  CREATE INDEX IF NOT EXISTS ev_reqno ON evidence(reqno);
  COMMIT;
}
set history_db [file join $::DOC history.db]
db eval {
  ATTACH $history_db AS history;
  BEGIN;
  CREATE TABLE IF NOT EXISTS history.allreq(
    reqno TEXT PRIMARY KEY,  -- Ex: R-12345-67890-...
    reqimage BOOLEAN,        -- True for an image requirement
    reqtext TEXT,            -- Normalized text of requirement or image filename
    srcfile TEXT             -- Document from which extracted
  );
  REPLACE INTO history.allreq
    SELECT reqno, reqimage, reqtext, srcfile FROM requirement;
  COMMIT;
}
db close
