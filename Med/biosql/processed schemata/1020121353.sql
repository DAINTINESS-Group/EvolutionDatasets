

# conventions:
# <table_name>_id is primary internal id (usually autogenerated)

# author Ewan Birney 
# comments to bioperl - bioperl-l@bioperl.org

# database have bioentries. That is about it.
# we do not store different versions of a database as different dbids
# (there is no concept of versions of database). There is a concept of
# versions of entries. Versions of databases deserve their own table and
# join to bioentry table for tracking with versions of entries 


CREATE TABLE biodatabase (
  biodatabase_id int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
  name        varchar(40) NOT NULL
);
CREATE INDEX biodatabaseidx1 on biodatabase(name);

# we could insist that taxa are NCBI taxa id, but on reflection I made this
# an optional extra line, as many flat file formats do not have the NCBI id

# full lineage is : delimited string starting with species.

# no organelle/sub species

CREATE TABLE taxa (
  taxa_id   int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
  full_lineage mediumtext NOT NULL,
  common_name varchar(255) NOT NULL,
  ncbi_taxa_id int(10)
  
);
CREATE INDEX taxancbi ON taxa(ncbi_taxa_id);
CREATE INDEX taxaname ON taxa(common_name);


# any controlled vocab term, everything from full ontology
# terms eg GO IDs to the various keys allowed as qualifiers
#
# this replaces the table "seqfeature_qualifier"
CREATE TABLE ontology_term (
       ontology_term_id int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
       term_name        char(255),
       term_definition  mediumtext
);
CREATE INDEX otn ON ontology_term(term_name);

# we can be a bioentry without a biosequence, but not visa-versa
# most things are going to be keyed off bioentry_id

# accession is the stable id, display_id is a potentially volatile,
# human readable name.


CREATE TABLE bioentry (
  bioentry_id  int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
  biodatabase_id  int(10) NOT NULL,
  display_id   varchar(40) NOT NULL,
  accession    varchar(40) NOT NULL,
  entry_version int(10), 
  division     varchar(3) NOT NULL,
  UNIQUE (biodatabase_id,accession,entry_version, division),
  FOREIGN KEY (biodatabase_id) REFERENCES biodatabase(biodatabase_id)
);
CREATE INDEX bioentrydbid ON bioentry(biodatabase_id);
CREATE INDEX bioentrydid  ON bioentry(display_id);
CREATE INDEX bioentryacc  ON bioentry(accession);


# not all entries have a taxa, but many do.
# one bioentry only has one taxa! (weirdo chimerias are not handled. tough)

CREATE TABLE bioentry_taxa (
  bioentry_id int(10)  NOT NULL,
  taxa_id     int(10)  NOT NULL,
  FOREIGN KEY (taxa_id) REFERENCES taxa(taxa_id),
  FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id),
  PRIMARY KEY(bioentry_id)
);
# bioentry_id is already the primary key, no index needed
# CREATE INDEX bioentryentry  ON bioentry_taxa(bioentry_id);
CREATE INDEX bioentrytax  ON bioentry_taxa(taxa_id);

# some bioentries will have a sequence
# biosequence because sequence is sometimes 
# a reserved word
# removed not null for seq_version; cjm

CREATE TABLE biosequence (
  biosequence_id  int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
  bioentry_id     int(10) NOT NULL,
  seq_version     int(6), 
  seq_length      int(10), 
  biosequence_str mediumtext,
  molecule        varchar(10),
  FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id),
  UNIQUE(bioentry_id)
);
CREATE INDEX biosequenceeid  ON biosequence(bioentry_id);

# new table
CREATE TABLE dbxref (
        dbxref_id  int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
        dbname                  varchar(40) NOT NULL,
        accession               varchar(40) NOT NULL,
        UNIQUE(dbname, accession)
);
CREATE INDEX dbxrefdbn  ON dbxref(dbname);
CREATE INDEX dbxrefacc  ON dbxref(accession);

# new table
# for roundtripping embl/genbank, we need to have the "optional ID"
# for the dbxref.
#
# another use of this table could be for storing
# descriptive text for a dbxref. for example, we may want to
# know stuff about the interpro accessions we store (without
# importing all of interpro), so we can attach the text
# description as a synonym
#
CREATE TABLE dbxref_qualifier_value (
       dbxref_qualifier_value_id  int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
       dbxref_id               int(10) NOT NULL,
       FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id),
       ontology_term_id  int(10) unsigned NOT NULL,
       FOREIGN KEY(ontology_term_id) REFERENCES ontology_term(ontology_term_id),
       qualifier_value             mediumtext
);
CREATE INDEX dqv1  ON dbxref_qualifier_value(dbxref_id);
CREATE INDEX dqv2  ON dbxref_qualifier_value(ontology_term_id);

# Direct links. It is tempting to do this
# from bioentry_id to bioentry_id. But that wont work
# during updates of one database - we will have to edit
# this table each time. Better to do the join through accession
# and db each time. Should be almost as cheap

# note: changed to use new dbxref table
CREATE TABLE bioentry_direct_links (
       bio_dblink_id           int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
       source_bioentry_id      int(10) NOT NULL,
       dbxref_id               int(10) NOT NULL,
       FOREIGN KEY (source_bioentry_id) REFERENCES bioentry(bioentry_id),
       FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id)
);
CREATE INDEX bdl1  ON bioentry_direct_links(source_bioentry_id);
CREATE INDEX bdl2  ON bioentry_direct_links(dbxref_id);

#We can have multiple references per bioentry, but one reference
#can also be used for the same bioentry.

CREATE TABLE reference (
  reference_id       int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
  reference_location mediumtext NOT NULL,
  reference_title    mediumtext,
  reference_authors  mediumtext NOT NULL,
  reference_medline  int(10)
);

CREATE INDEX medlineidx ON reference(reference_medline);

CREATE TABLE bioentry_reference (
  bioentry_id int(10) unsigned NOT NULL,
  reference_id int(10) unsigned NOT NULL,
  reference_start    int(10),
  reference_end      int(10),
  reference_rank int(5) unsigned NOT NULL,

  PRIMARY KEY(bioentry_id,reference_id,reference_rank),
  FOREIGN KEY(bioentry_id) REFERENCES bioentry(bioentry_id),
  FOREIGN KEY(reference_id) REFERENCES reference(reference_id)
);
CREATE INDEX reference_rank_idx ON bioentry_reference(reference_rank);
CREATE INDEX reference_rank_idx2 ON bioentry_reference(bioentry_id);
CREATE INDEX reference_rank_idx3 ON bioentry_reference(reference_id);
CREATE INDEX reference_rank_idx4 ON bioentry_reference(reference_rank);
CREATE INDEX reference_rank_idx5 ON bioentry_reference(bioentry_id, reference_rank);


# We can have multiple comments per seqentry, and
# comments can have embedded '\n' characters

CREATE TABLE comment (
  comment_id  int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
  bioentry_id    int(10) NOT NULL,
  comment_text   mediumtext NOT NULL,
  comment_rank   int(5) NOT NULL,
  UNIQUE(bioentry_id, comment_rank),
  FOREIGN KEY(bioentry_id) REFERENCES bioentry(bioentry_id)
);
CREATE INDEX cmtidx1 ON comment(bioentry_id);

# separate description table separate to save on space when we
# do not store descriptions

# this table replaces the old
#  bioentry_description and bioentry_keywords tables
CREATE TABLE bioentry_qualifier_value (
   bioentry_id       int(10) unsigned NOT NULL,
   FOREIGN KEY(bioentry_id) REFERENCES bioentry(bioentry_id),
   ontology_term_id  int(10) unsigned NOT NULL,
   FOREIGN KEY(ontology_term_id) REFERENCES ontology_term(ontology_term_id),
   qualifier_value             mediumtext
);
CREATE INDEX bqv1 ON bioentry_qualifier_value(bioentry_id);
CREATE INDEX bqv2 ON bioentry_qualifier_value(ontology_term_id);
CREATE INDEX bqv3 ON bioentry_qualifier_value(bioentry_id, ontology_term_id);

# feature table. We cleanly handle
#   - simple locations
#   - split locations
#   - split locations on remote sequences

# The fuzzies are not handled yet



CREATE TABLE seqfeature_source (
       seqfeature_source_id int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
       source_name varchar(255) NOT NULL
);

CREATE TABLE seqfeature (
   seqfeature_id int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
   bioentry_id   int(10) NOT NULL,
   seqfeature_key_id     int(10),
   seqfeature_source_id  int(10),
   seqfeature_rank int(5),
  FOREIGN KEY (seqfeature_key_id) REFERENCES ontology_term(ontology_term_id),
  FOREIGN KEY (seqfeature_source_id) REFERENCES seqfeature_source(seqfeature_source_id),
  FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
);
CREATE INDEX sf1 ON seqfeature(seqfeature_key_id);
CREATE INDEX sf2 ON seqfeature(seqfeature_source_id);
CREATE INDEX sf3 ON seqfeature(bioentry_id);

# seqfeatures can be arranged in containment hierarchies.
# one can imagine storing other relationships between features,
# in this case the ontology_term_id can be used to type the relationship
CREATE TABLE seqfeature_relationship (
   seqfeature_relationship_id int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
   parent_seqfeature_id int(10) NOT NULL,
   child_seqfeature_id int(10) NOT NULL,
   relationship_type_id int(10) NOT NULL,
   relationship_rank int(5),
   UNIQUE(parent_seqfeature_id, child_seqfeature_id, relationship_type_id),
   FOREIGN KEY (relationship_type_id) REFERENCES ontology_term(ontology_term_id),
   FOREIGN KEY (parent_seqfeature_id) REFERENCES seqfeature(seqfeature_id),
   FOREIGN KEY (child_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
);
CREATE INDEX sfr1 ON seqfeature_relationship(relationship_type_id);
CREATE INDEX sfr2 ON seqfeature_relationship(parent_seqfeature_id);
CREATE INDEX sfr3 ON seqfeature_relationship(child_seqfeature_id);

CREATE TABLE seqfeature_qualifier_value (
   seqfeature_id int(10) NOT NULL,
   ontology_term_id int(10) NOT NULL,
   qualifier_rank int(5) NOT NULL,
   qualifier_value  mediumtext NOT NULL,
   FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id),
   FOREIGN KEY (seqfeature_id) REFERENCES seqfeature(seqfeature_id),
   PRIMARY KEY(seqfeature_id,ontology_term_id,qualifier_rank)
);
CREATE INDEX sqv1 ON seqfeature_qualifier_value(ontology_term_id);
CREATE INDEX sqv3 ON seqfeature_qualifier_value(seqfeature_id);
   
# basically we model everything as potentially having
# any number of locations, ie, a split location. SimpleLocations
# just have one location. We need to have a location id so for remote
# split locations we can specify the start/end point

# please do not try to model complex assemblies with this thing. It wont
# work. Check out the ensembl schema for this.

# we allow nulls for start/end - this is useful for fuzzies as
# standard range queries will not be included
CREATE TABLE seqfeature_location (
   seqfeature_location_id int(10) unsigned NOT NULL PRIMARY KEY auto_increment,
   seqfeature_id          int(10) NOT NULL,
   seq_start              int(10),
   seq_end                int(10),
   seq_strand             int(1)  NOT NULL,
   location_rank          int(5)  NOT NULL,
   UNIQUE (seqfeature_id, location_rank),
  FOREIGN KEY (seqfeature_id) REFERENCES seqfeature(seqfeature_id)
);
CREATE INDEX sfl1 ON seqfeature_location(seqfeature_id);
CREATE INDEX sfl2 ON seqfeature_location(seq_start);
CREATE INDEX sfl3 ON seqfeature_location(seq_end);

# for remote locations, this is the join to make.
# beware - in the object layer it has to make a double SQL query to figure out
# whether this is remote location or not

# like DR links, we do not link directly to a bioentry_id - we have to do
# this run-time

CREATE TABLE remote_seqfeature_name (
       seqfeature_location_id int(10) unsigned NOT NULL PRIMARY KEY,
       accession varchar(40) NOT NULL,
       version   int(10) NOT NULL,
  FOREIGN KEY (seqfeature_location_id) REFERENCES seqfeature_location(seqfeature_location_id)
);
CREATE INDEX rsfn1 ON remote_seqfeature_name(seqfeature_location_id);

# location qualifiers - mainly intended for fuzzies but anything
# can go in here
# some controlled vocab terms have slots;
# fuzzies could be modeled as min_start(5), max_start(5)
# 
# there is no restriction on extending the fuzzy ontology
# for your own nefarious aims, although the bio* apis will
# most likely ignore these
CREATE TABLE location_qualifier_value (
   seqfeature_location_id int(10) unsigned NOT NULL,
   ontology_term_id int(10) NOT NULL,
   qualifier_value  char(255) NOT NULL,
   qualifier_int_value int(10),
  FOREIGN KEY (seqfeature_location_id) REFERENCES seqfeature_location(seqfeature_location_id),
  FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id)
);
CREATE INDEX lqv1 ON location_qualifier_value(seqfeature_location_id);
CREATE INDEX lqv2 ON location_qualifier_value(ontology_term_id);

# pre-make the fuzzy ontology
INSERT INTO ontology_term (term_name) VALUES ('min_start');
INSERT INTO ontology_term (term_name) VALUES ('min_end');
INSERT INTO ontology_term (term_name) VALUES ('max_start');
INSERT INTO ontology_term (term_name) VALUES ('max_end');
INSERT INTO ontology_term (term_name) VALUES ('unknown_start');
INSERT INTO ontology_term (term_name) VALUES ('unknown_end');
INSERT INTO ontology_term (term_name) VALUES ('end_pos_type');
INSERT INTO ontology_term (term_name) VALUES ('start_pos_type');
INSERT INTO ontology_term (term_name) VALUES ('location_type');
# coordinate policies?

#
# this is a tiny table to allow a cach'ing corba server to
# persistently store aspects of the root server - so when/if
# the server gets reaped it can reconnect
#

CREATE TABLE cache_corba_support (
       biodatabase_id    int(10) unsigned NOT NULL PRIMARY KEY,  
       http_ior_string   varchar(255),
       direct_ior_string varchar(255)
       );






