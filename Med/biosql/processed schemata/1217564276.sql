-- $Id$
--
-- Copyright 2002-2003 Ewan Birney, Elia Stupka, Chris Mungall
-- Copyright 2003-2008 Hilmar Lapp 
-- 
--  This file is part of BioSQL.
--
--  BioSQL is free software: you can redistribute it and/or modify it
--  under the terms of the GNU Lesser General Public License as
--  published by the Free Software Foundation, either version 3 of the
--  License, or (at your option) any later version.
--
--  BioSQL is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU Lesser General Public License for more details.
--
--  You should have received a copy of the GNU Lesser General Public License
--  along with BioSQL. If not, see <http://www.gnu.org/licenses/>.
--
-- ========================================================================
--
-- Authors: Ewan Birney, Elia Stupka, Hilmar Lapp, Aaron Mackey
-- Post-Cape Town changes by Hilmar Lapp.
-- Singapore changes by Hilmar Lapp and Aaron Mackey.
-- Migration of the MySQL schema to InnoDB by Hilmar Lapp
--
-- comments to biosql - biosql-l@open-bio.org

-- conventions:
-- <table_name>_id is primary internal id (usually autogenerated)
--
-- Certain definitions in this schema, in particular certain unique
-- key constrain definitions, are optional, or may optionally be
-- changed (customized, if you wil). Search for the word OPTION: in
-- capital letters.
--
-- Note that some aspects of the schema like uniqueness constraints
-- may be changed to best suit your requirements. Search for the tag
-- CONFIG and read the documentation you find there.
--

-- database have bioentries. That is about it.
-- we do not store different versions of a database as different dbids
-- (there is no concept of versions of database). There is a concept of
-- versions of entries. Versions of databases deserve their own table and
-- join to bioentry table for tracking with versions of entries 

CREATE TABLE biodatabase (
  	biodatabase_id 	INT(10) UNSIGNED NOT NULL auto_increment,
  	name           	VARCHAR(128) BINARY NOT NULL,
	authority	VARCHAR(128),
	description	TEXT,
	PRIMARY KEY (biodatabase_id),
  	UNIQUE (name)
) TYPE=INNODB;

CREATE INDEX db_auth on biodatabase(authority);

-- we could insist that taxa are NCBI taxon id, but on reflection I made this
-- an optional extra line, as many flat file formats do not have the NCBI id
--
-- no organelle/sub species
--
-- this corresponds to the node table of the NCBI taxonomy database 
-- left_value, right_value implement a nested sets model;
-- see http://www.oreillynet.com/pub/a/network/2002/11/27/bioconf.html
-- or Joe Celko's 'SQL for smarties' for more information.
CREATE TABLE taxon (
       taxon_id		INT(10) UNSIGNED NOT NULL auto_increment,
       ncbi_taxon_id 	INT(10),
       parent_taxon_id	INT(10) UNSIGNED,
       node_rank	VARCHAR(32),
       genetic_code	TINYINT UNSIGNED,
       mito_genetic_code TINYINT UNSIGNED,
       left_value	INT(10) UNSIGNED,
       right_value	INT(10) UNSIGNED,
       PRIMARY KEY (taxon_id),
       UNIQUE (ncbi_taxon_id),
       UNIQUE (left_value),
       UNIQUE (right_value)
) TYPE=INNODB;

CREATE INDEX taxparent ON taxon(parent_taxon_id);

-- corresponds to the names table of the NCBI taxonomy databaase
CREATE TABLE taxon_name (
       taxon_id		INT(10) UNSIGNED NOT NULL,
       name		VARCHAR(255) BINARY NOT NULL,
       name_class	VARCHAR(32) BINARY NOT NULL,
       UNIQUE (taxon_id,name,name_class)
) TYPE=INNODB;

CREATE INDEX taxnametaxonid ON taxon_name(taxon_id);
CREATE INDEX taxnamename    ON taxon_name(name);

-- this is the namespace (controlled vocabulary) ontology terms live in
-- we chose to have a separate table for this instead of reusing biodatabase
CREATE TABLE ontology (
       	ontology_id        INT(10) UNSIGNED NOT NULL auto_increment,
       	name	   	   VARCHAR(32) BINARY NOT NULL,
       	definition	   TEXT,
	PRIMARY KEY (ontology_id),
	UNIQUE (name)
) TYPE=INNODB;

-- any controlled vocab term, everything from full ontology
-- terms eg GO IDs to the various keys allowed as qualifiers
CREATE TABLE term (
       	term_id   INT(10) UNSIGNED NOT NULL auto_increment,
       	name	   	   VARCHAR(255) BINARY NOT NULL,
       	definition	   TEXT,
	identifier	   VARCHAR(40) BINARY,
	is_obsolete	   CHAR(1),
	ontology_id	   INT(10) UNSIGNED NOT NULL,
	PRIMARY KEY (term_id),
	UNIQUE (identifier),
-- CONFIG: uncomment exactly one of the two following lines. The
-- first one puts a unqiueness constraint on term name within an
-- ontology, which is a conservative approach. However, if you are
-- going to load GO and update it too, there are situations where
-- you'll run into problems with this constraint unless you delete
-- obsoleted terms (which has its own shortcomings, read the POD of
-- load_ontology.pl in bioperl-db). The second line includes the
-- obsoleteness into the uniqueness constraint.
--        UNIQUE (name,ontology_id)
          UNIQUE (name,ontology_id,is_obsolete)
) TYPE=INNODB;

CREATE INDEX term_ont ON term(ontology_id);

-- ontology terms have synonyms, here is how to store them
-- Synonym is a reserved word in many RDBMSs, so the column synonym
-- may eventually be renamed to name.
CREATE TABLE term_synonym (
       synonym		  VARCHAR(255) BINARY NOT NULL,
       term_id		  INT(10) UNSIGNED NOT NULL,
       PRIMARY KEY (term_id,synonym)
) TYPE=INNODB;

-- ontology terms to dbxref association: ontology terms have dbxrefs
CREATE TABLE term_dbxref (
       	term_id	          INT(10) UNSIGNED NOT NULL,
       	dbxref_id         INT(10) UNSIGNED NOT NULL,
	rank		  SMALLINT,
	PRIMARY KEY (term_id, dbxref_id)
) TYPE=INNODB;

CREATE INDEX trmdbxref_dbxrefid ON term_dbxref(dbxref_id);

-- relationship between controlled vocabulary / ontology term
-- we use subject/predicate/object but this could also
-- be thought of as child/relationship-type/parent.
-- the subject/predicate/object naming is better as we
-- can think of the graph as composed of statements.
--
-- we also treat the relationshiptypes / predicates as
-- controlled terms in themselves; this is quite useful
-- as a lot of systems (eg GO) will soon require
-- ontologies of relationship types (eg subtle differences
-- in the partOf relationship)
--
-- this table probably won''t be filled for a while, the core
-- will just treat ontologies as flat lists of terms

CREATE TABLE term_relationship (
        term_relationship_id INT(10) UNSIGNED NOT NULL auto_increment,
       	subject_term_id	INT(10) UNSIGNED NOT NULL,
       	predicate_term_id    INT(10) UNSIGNED NOT NULL,
       	object_term_id       INT(10) UNSIGNED NOT NULL,
	ontology_id	INT(10) UNSIGNED NOT NULL,
	PRIMARY KEY (term_relationship_id),
	UNIQUE (subject_term_id,predicate_term_id,object_term_id,ontology_id)
) TYPE=INNODB;

CREATE INDEX trmrel_predicateid ON term_relationship(predicate_term_id);
CREATE INDEX trmrel_objectid ON term_relationship(object_term_id);
CREATE INDEX trmrel_ontid ON term_relationship(ontology_id);
-- CONFIG: you may want to add this for mysql because MySQL often is broken
-- with respect to using the composite index for the initial keys
-- CREATE INDEX ontrel_subjectid ON term_relationship(subject_term_id);

-- This lets one associate a single term with a term_relationship 
-- effecively allowing us to treat triples as 1st class terms.
-- 
-- At this point this table is only supported in Biojava. If you want
-- to know more about the rationale and idea behind it, read the
-- following article that Mat Pocock posted to the mailing list:
-- http://www.open-bio.org/pipermail/biosql-l/2003-October/000455.html
CREATE TABLE term_relationship_term (
        term_relationship_id INT(10) UNSIGNED NOT NULL,
        term_id              INT(10) UNSIGNED NOT NULL,
        PRIMARY KEY ( term_relationship_id ),
        UNIQUE ( term_id ) 
) TYPE=INNODB;

-- the infamous transitive closure table on ontology term relationships
-- this is a warehouse approach - you will need to update this regularly
--
-- the triple of (subject, predicate, object) is the same as for ontology
-- relationships, with the exception of predicate being the greatest common
-- denominator of the relationships types visited in the path (i.e., if
-- relationship type A is-a relationship type B, the greatest common
-- denominator for path containing both types A and B is B)
--
-- See the GO database or Chado schema for other (and possibly better
-- documented) implementations of the transitive closure table approach.
CREATE TABLE term_path (
        term_path_id         INT(10) UNSIGNED NOT NULL auto_increment,
       	subject_term_id	     INT(10) UNSIGNED NOT NULL,
       	predicate_term_id    INT(10) UNSIGNED NOT NULL,
       	object_term_id       INT(10) UNSIGNED NOT NULL,
	ontology_id          INT(10) UNSIGNED NOT NULL,
	distance	     INT(10) UNSIGNED,
	PRIMARY KEY (term_path_id),
	UNIQUE (subject_term_id,predicate_term_id,object_term_id,ontology_id,distance)
) TYPE=INNODB;

CREATE INDEX trmpath_predicateid ON term_path(predicate_term_id);
CREATE INDEX trmpath_objectid ON term_path(object_term_id);
CREATE INDEX trmpath_ontid ON term_path(ontology_id);
-- CONFIG: you may want to add this for mysql because MySQL often is broken
-- with respect to using the composite index for the initial keys
-- CREATE INDEX trmpath_subjectid ON term_path(subject_term_id);

-- we can be a bioentry without a biosequence, but not visa-versa
-- most things are going to be keyed off bioentry_id
--
-- accession is the stable id, display_id is a potentially volatile,
-- human readable name.
--
-- Version may be unknown, may be undefined, or may not exist for a certain
-- accession or database (namespace). We require it here to avoid RDBMS-
-- dependend enforcement variants (version is in a compound alternative key),
-- and to simplify query construction for UK look-ups. If there is no version
-- the convention is to put 0 (zero) here. Likewise, a record with a version
-- of zero means the version is to be interpreted as NULL.
--
-- not all entries have a taxon, but many do.
-- one bioentry only has one taxon! (weirdo chimerias are not handled. tough)
--
-- Name maps to display_id in bioperl. We have a different column name
-- here to avoid confusion with the naming convention for foreign keys.

CREATE TABLE bioentry (
	bioentry_id	    INT(10) UNSIGNED NOT NULL auto_increment,
  	biodatabase_id  INT(10) UNSIGNED NOT NULL,
  	taxon_id     	INT(10) UNSIGNED,
  	name		VARCHAR(40) NOT NULL,
  	accession    	VARCHAR(128) BINARY NOT NULL,
  	identifier   	VARCHAR(40) BINARY,
	division	VARCHAR(6),
  	description  	TEXT,
  	version 	SMALLINT UNSIGNED NOT NULL, 
	PRIMARY KEY (bioentry_id),
  	UNIQUE (accession,biodatabase_id,version),
-- CONFIG: uncomment one (and only one) of the two lines below. The
-- first puts a uniqueness constraint on the identifier column alone;
-- the other one puts a uniqueness constraint on identifier only
-- within a namespace.
--  	UNIQUE (identifier)
 	UNIQUE (identifier, biodatabase_id)
) TYPE=INNODB;

CREATE INDEX bioentry_name ON bioentry(name);
CREATE INDEX bioentry_db   ON bioentry(biodatabase_id);
CREATE INDEX bioentry_tax  ON bioentry(taxon_id);

--
-- bioentry-bioentry relationships: these are typed
--
CREATE TABLE bioentry_relationship (
        bioentry_relationship_id INT(10) UNSIGNED NOT NULL auto_increment,
        object_bioentry_id 	 INT(10) UNSIGNED NOT NULL,
   	subject_bioentry_id 	 INT(10) UNSIGNED NOT NULL,
   	term_id 		 INT(10) UNSIGNED NOT NULL,
   	rank 			 INT(5),
   	PRIMARY KEY (bioentry_relationship_id),
	UNIQUE (object_bioentry_id,subject_bioentry_id,term_id)
) TYPE=INNODB;

CREATE INDEX bioentryrel_trm   ON bioentry_relationship(term_id);
CREATE INDEX bioentryrel_child ON bioentry_relationship(subject_bioentry_id);
-- CONFIG: you may want to add this for mysql because MySQL often is broken
-- with respect to using the composite index for the initial keys
-- CREATE INDEX bioentryrel_parent ON bioentry_relationship(object_bioentry_id);

-- for deep (depth > 1) bioentry relationship trees we need a transitive
-- closure table too
CREATE TABLE bioentry_path (
   	object_bioentry_id 	INT(10) UNSIGNED NOT NULL,
   	subject_bioentry_id 	INT(10) UNSIGNED NOT NULL,
   	term_id 		INT(10) UNSIGNED NOT NULL,
	distance	     	INT(10) UNSIGNED,
	UNIQUE (object_bioentry_id,subject_bioentry_id,term_id,distance)
) TYPE=INNODB;

CREATE INDEX bioentrypath_trm   ON bioentry_path(term_id);
CREATE INDEX bioentrypath_child ON bioentry_path(subject_bioentry_id);
-- CONFIG: you may want to add this for mysql because MySQL often is broken
-- with respect to using the composite index for the initial keys
-- CREATE INDEX bioentrypath_parent ON bioentry_path(object_bioentry_id);

-- some bioentries will have a sequence
-- biosequence because sequence is sometimes a reserved word

CREATE TABLE biosequence (
  	bioentry_id     INT(10) UNSIGNED NOT NULL,
  	version     	SMALLINT, 
  	length      	INT(10),
  	alphabet        VARCHAR(10),
  	seq 		LONGTEXT,
	PRIMARY KEY (bioentry_id)
) TYPE=INNODB;

-- CONFIG: add these only if you want them:
-- ALTER TABLE biosequence ADD COLUMN ( isoelec_pt NUMERIC(4,2) );
-- ALTER TABLE biosequence ADD COLUMN (	mol_wgt DOUBLE  );
-- ALTER TABLE biosequence ADD COLUMN ( perc_gc DOUBLE  );

-- database cross-references (e.g., GenBank:AC123456.1)
--
-- Version may be unknown, may be undefined, or may not exist for a certain
-- accession or database (namespace). We require it here to avoid RDBMS-
-- dependend enforcement variants (version is in a compound alternative key),
-- and to simplify query construction for UK look-ups. If there is no version
-- the convention is to put 0 (zero) here. Likewise, a record with a version
-- of zero means the version is to be interpreted as NULL.
--
CREATE TABLE dbxref (
        dbxref_id	INT(10) UNSIGNED NOT NULL auto_increment,
        dbname          VARCHAR(40) BINARY NOT NULL,
        accession       VARCHAR(128) BINARY NOT NULL,
	version		SMALLINT UNSIGNED NOT NULL,
	PRIMARY KEY (dbxref_id),
        UNIQUE(accession, dbname, version)
) TYPE=INNODB;

CREATE INDEX dbxref_db  ON dbxref(dbname);

-- for roundtripping embl/genbank, we need to have the "optional ID"
-- for the dbxref.
--
-- another use of this table could be for storing
-- descriptive text for a dbxref. for example, we may want to
-- know stuff about the interpro accessions we store (without
-- importing all of interpro), so we can attach the text
-- description as a synonym
CREATE TABLE dbxref_qualifier_value (
       	dbxref_id 		INT(10) UNSIGNED NOT NULL,
       	term_id 		INT(10) UNSIGNED NOT NULL,
  	rank  		   	SMALLINT NOT NULL DEFAULT 0,
       	value			TEXT,
	PRIMARY KEY (dbxref_id,term_id,rank)
) TYPE=INNODB;

CREATE INDEX dbxrefqual_dbx ON dbxref_qualifier_value(dbxref_id);
CREATE INDEX dbxrefqual_trm ON dbxref_qualifier_value(term_id);

-- Direct dblinks. It is tempting to do this
-- from bioentry_id to bioentry_id. But that wont work
-- during updates of one database - we will have to edit
-- this table each time. Better to do the join through accession
-- and db each time. Should be almost as cheap

CREATE TABLE bioentry_dbxref ( 
       	bioentry_id        INT(10) UNSIGNED NOT NULL,
       	dbxref_id          INT(10) UNSIGNED NOT NULL,
  	rank  		   SMALLINT,
	PRIMARY KEY (bioentry_id,dbxref_id)
) TYPE=INNODB;

CREATE INDEX dblink_dbx  ON bioentry_dbxref(dbxref_id);

-- We can have multiple references per bioentry, but one reference
-- can also be used for the same bioentry.
--
-- No two references can reference the same reference database entry
-- (dbxref_id). This is where the MEDLINE id goes: PUBMED:123456.

CREATE TABLE reference (
  	reference_id       INT(10) UNSIGNED NOT NULL auto_increment,
	dbxref_id	   INT(10) UNSIGNED,
  	location 	   TEXT NOT NULL,
  	title    	   TEXT,
  	authors  	   TEXT,
  	crc	   	   VARCHAR(32),
	PRIMARY KEY (reference_id),
	UNIQUE (dbxref_id),
	UNIQUE (crc)
) TYPE=INNODB;

-- bioentry to reference associations
CREATE TABLE bioentry_reference (
  	bioentry_id 	INT(10) UNSIGNED NOT NULL,
  	reference_id 	INT(10) UNSIGNED NOT NULL,
  	start_pos	INT(10),
  	end_pos	  	INT(10),
  	rank  		SMALLINT NOT NULL DEFAULT 0,
  	PRIMARY KEY(bioentry_id,reference_id,rank)
) TYPE=INNODB;

CREATE INDEX bioentryref_ref ON bioentry_reference(reference_id);


-- We can have multiple comments per seqentry, and
-- comments can have embedded '\n' characters

CREATE TABLE comment (
  	comment_id  	INT(10) UNSIGNED NOT NULL auto_increment,
  	bioentry_id    	INT(10) UNSIGNED NOT NULL,
  	comment_text   	TEXT NOT NULL,
  	rank   		SMALLINT NOT NULL DEFAULT 0,
	PRIMARY KEY (comment_id),
  	UNIQUE(bioentry_id, rank)
) TYPE=INNODB;


-- tag/value and ontology term annotation for bioentries goes here
CREATE TABLE bioentry_qualifier_value (
	bioentry_id   		INT(10) UNSIGNED NOT NULL,
   	term_id  		INT(10) UNSIGNED NOT NULL,
   	value         		TEXT,
	rank			INT(5) NOT NULL DEFAULT 0,
	UNIQUE (bioentry_id,term_id,rank)
) TYPE=INNODB;

CREATE INDEX bioentryqual_trm ON bioentry_qualifier_value(term_id);

-- feature table. We cleanly handle
--   - simple locations
--   - split locations
--   - split locations on remote sequences

CREATE TABLE seqfeature (
   	seqfeature_id 		INT(10) UNSIGNED NOT NULL auto_increment,
   	bioentry_id   		INT(10) UNSIGNED NOT NULL,
   	type_term_id		INT(10) UNSIGNED NOT NULL,
   	source_term_id  	INT(10) UNSIGNED NOT NULL,
	display_name		VARCHAR(64),
   	rank 			SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	PRIMARY KEY (seqfeature_id),
	UNIQUE (bioentry_id,type_term_id,source_term_id,rank)
) TYPE=INNODB;

CREATE INDEX seqfeature_trm  ON seqfeature(type_term_id);
CREATE INDEX seqfeature_fsrc ON seqfeature(source_term_id);
-- you may want to add this for mysql because MySQL often is broken with
-- respect to using the composite index for the initial keys
-- CREATE INDEX seqfeature_bioentryid ON seqfeature(bioentry_id);

-- seqfeatures can be arranged in containment hierarchies.
-- one can imagine storing other relationships between features,
-- in this case the term_id can be used to type the relationship

CREATE TABLE seqfeature_relationship (
        seqfeature_relationship_id INT(10) UNSIGNED NOT NULL auto_increment,
   	object_seqfeature_id	INT(10) UNSIGNED NOT NULL,
   	subject_seqfeature_id 	INT(10) UNSIGNED NOT NULL,
   	term_id 	        INT(10) UNSIGNED NOT NULL,
   	rank 			INT(5),
   	PRIMARY KEY (seqfeature_relationship_id),
	UNIQUE (object_seqfeature_id,subject_seqfeature_id,term_id)
) TYPE=INNODB;

CREATE INDEX seqfeaturerel_trm   ON seqfeature_relationship(term_id);
CREATE INDEX seqfeaturerel_child ON seqfeature_relationship(subject_seqfeature_id);
-- CONFIG: you may want to add this for mysql because MySQL often is broken
-- with respect to using the composite index for the initial keys
-- CREATE INDEX seqfeaturerel_parent ON seqfeature_relationship(object_seqfeature_id);

-- for deep (depth > 1) seqfeature relationship trees we need a transitive
-- closure table too
CREATE TABLE seqfeature_path (
   	object_seqfeature_id	INT(10) UNSIGNED NOT NULL,
   	subject_seqfeature_id 	INT(10) UNSIGNED NOT NULL,
   	term_id 		INT(10) UNSIGNED NOT NULL,
	distance	     	INT(10) UNSIGNED,
	UNIQUE (object_seqfeature_id,subject_seqfeature_id,term_id,distance)
) TYPE=INNODB;

CREATE INDEX seqfeaturepath_trm   ON seqfeature_path(term_id);
CREATE INDEX seqfeaturepath_child ON seqfeature_path(subject_seqfeature_id);
-- CONFIG: you may want to add this for mysql because MySQL often is broken
-- with respect to using the composite index for the initial keys
-- CREATE INDEX seqfeaturerel_parent ON seqfeature_path(object_seqfeature_id);

-- tag/value associations - or ontology annotations
CREATE TABLE seqfeature_qualifier_value (
	seqfeature_id 		INT(10) UNSIGNED NOT NULL,
   	term_id 		INT(10) UNSIGNED NOT NULL,
   	rank 			SMALLINT NOT NULL DEFAULT 0,
   	value  			TEXT NOT NULL,
   	PRIMARY KEY (seqfeature_id,term_id,rank)
) TYPE=INNODB;

CREATE INDEX seqfeaturequal_trm ON seqfeature_qualifier_value(term_id);
   
-- DBXrefs for features. This is necessary for genome oriented viewpoints,
-- where you have a few have long sequences (contigs, or chromosomes) with many
-- features on them. In that case the features are the semantic scope for
-- their annotation bundles, not the bioentry they are attached to.

CREATE TABLE seqfeature_dbxref ( 
       	seqfeature_id      INT(10) UNSIGNED NOT NULL,
       	dbxref_id          INT(10) UNSIGNED NOT NULL,
  	rank  		   SMALLINT,
	PRIMARY KEY (seqfeature_id,dbxref_id)
) TYPE=INNODB;

CREATE INDEX feadblink_dbx  ON seqfeature_dbxref(dbxref_id);

-- basically we model everything as potentially having
-- any number of locations, ie, a split location. SimpleLocations
-- just have one location. We need to have a location id for the qualifier
-- associations of fuzzy locations.

-- please do not try to model complex assemblies with this thing. It wont
-- work. Check out the ensembl schema for this.

-- we allow nulls for start/end - this is useful for fuzzies as
-- standard range queries will not be included

-- for remote locations, the join to make is to DBXref
-- the FK to term is a possibility to store the type of the
-- location for determining in one hit whether it's a fuzzy or not

CREATE TABLE location (
	location_id		INT(10) UNSIGNED NOT NULL auto_increment,
   	seqfeature_id		INT(10) UNSIGNED NOT NULL,
	dbxref_id		INT(10) UNSIGNED,
	term_id			INT(10) UNSIGNED,
   	start_pos              	INT(10),
   	end_pos                	INT(10),
   	strand             	TINYINT NOT NULL DEFAULT 0,
   	rank          		SMALLINT NOT NULL DEFAULT 0,
	PRIMARY KEY (location_id),
   	UNIQUE (seqfeature_id, rank)
) TYPE=INNODB;

CREATE INDEX seqfeatureloc_start ON location(start_pos, end_pos);
CREATE INDEX seqfeatureloc_dbx   ON location(dbxref_id);
CREATE INDEX seqfeatureloc_trm   ON location(term_id);

-- location qualifiers - mainly intended for fuzzies but anything
-- can go in here
-- some controlled vocab terms have slots;
-- fuzzies could be modeled as min_start(5), max_start(5)
-- 
-- there is no restriction on extending the fuzzy ontology
-- for your own nefarious aims, although the bio* apis will
-- most likely ignore these
CREATE TABLE location_qualifier_value (
	location_id		INT(10) UNSIGNED NOT NULL,
   	term_id 		INT(10) UNSIGNED NOT NULL,
   	value  			VARCHAR(255) NOT NULL,
   	int_value 		INT(10),
	PRIMARY KEY (location_id,term_id)
) TYPE=INNODB;

CREATE INDEX locationqual_trm ON location_qualifier_value(term_id);

--
-- Create the foreign key constraints
--

-- ontology term

ALTER TABLE term ADD CONSTRAINT FKont_term
	FOREIGN KEY (ontology_id) REFERENCES ontology(ontology_id)
	ON DELETE CASCADE;

-- term synonyms

ALTER TABLE term_synonym ADD CONSTRAINT FKterm_syn
	FOREIGN KEY (term_id) REFERENCES term(term_id)
	ON DELETE CASCADE;

-- term_dbxref

ALTER TABLE term_dbxref ADD CONSTRAINT FKdbxref_trmdbxref
       	FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id)
	ON DELETE CASCADE;
ALTER TABLE term_dbxref ADD CONSTRAINT FKterm_trmdbxref
      FOREIGN KEY (term_id) REFERENCES term(term_id)
	ON DELETE CASCADE;

-- term_relationship

ALTER TABLE term_relationship ADD CONSTRAINT FKtrmsubject_trmrel
	FOREIGN KEY (subject_term_id) REFERENCES term(term_id)
	ON DELETE CASCADE;
ALTER TABLE term_relationship ADD CONSTRAINT FKtrmpredicate_trmrel
       	FOREIGN KEY (predicate_term_id) REFERENCES term(term_id)
	ON DELETE CASCADE;
ALTER TABLE term_relationship ADD CONSTRAINT FKtrmobject_trmrel
       	FOREIGN KEY (object_term_id) REFERENCES term(term_id)
	ON DELETE CASCADE;
ALTER TABLE term_relationship ADD CONSTRAINT FKterm_trmrel
       	FOREIGN KEY (ontology_id) REFERENCES ontology(ontology_id)
	ON DELETE CASCADE;

-- term_relationship_term

ALTER TABLE term_relationship_term ADD CONSTRAINT FKtrmrel_trmreltrm
	FOREIGN KEY (term_relationship_id) REFERENCES term_relationship(term_relationship_id)
	ON DELETE CASCADE;
ALTER TABLE term_relationship_term ADD CONSTRAINT FKtrm_trmreltrm
	FOREIGN KEY (term_id) REFERENCES term(term_id)
	ON DELETE CASCADE;

-- term_path

ALTER TABLE term_path ADD CONSTRAINT FKtrmsubject_trmpath
	FOREIGN KEY (subject_term_id) REFERENCES term(term_id)
	ON DELETE CASCADE;
ALTER TABLE term_path ADD CONSTRAINT FKtrmpredicate_trmpath
       	FOREIGN KEY (predicate_term_id) REFERENCES term(term_id)
	ON DELETE CASCADE;
ALTER TABLE term_path ADD CONSTRAINT FKtrmobject_trmpath
       	FOREIGN KEY (object_term_id) REFERENCES term(term_id)
	ON DELETE CASCADE;
ALTER TABLE term_path ADD CONSTRAINT FKontology_trmpath
       	FOREIGN KEY (ontology_id) REFERENCES ontology(ontology_id)
	ON DELETE CASCADE;

-- taxon, taxon_name

-- unfortunately, we can't constrain parent_taxon_id as it is violated
-- occasionally by the downloads available from NCBI
-- ALTER TABLE taxon ADD CONSTRAINT FKtaxon_taxon
--        FOREIGN KEY (parent_taxon_id) REFERENCES taxon(taxon_id);
ALTER TABLE taxon_name ADD CONSTRAINT FKtaxon_taxonname
        FOREIGN KEY (taxon_id) REFERENCES taxon(taxon_id)
        ON DELETE CASCADE;

-- bioentry

ALTER TABLE bioentry ADD CONSTRAINT FKtaxon_bioentry
	FOREIGN KEY (taxon_id) REFERENCES taxon(taxon_id);
ALTER TABLE bioentry ADD CONSTRAINT FKbiodatabase_bioentry
	FOREIGN KEY (biodatabase_id) REFERENCES biodatabase(biodatabase_id);

-- bioentry_relationship

ALTER TABLE bioentry_relationship ADD CONSTRAINT FKterm_bioentryrel
	FOREIGN KEY (term_id) REFERENCES term(term_id);
ALTER TABLE bioentry_relationship ADD CONSTRAINT FKparentent_bioentryrel
	FOREIGN KEY (object_bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_relationship ADD CONSTRAINT FKchildent_bioentryrel
	FOREIGN KEY (subject_bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- bioentry_path

ALTER TABLE bioentry_path ADD CONSTRAINT FKterm_bioentrypath
	FOREIGN KEY (term_id) REFERENCES term(term_id);
ALTER TABLE bioentry_path ADD CONSTRAINT FKparentent_bioentrypath
	FOREIGN KEY (object_bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_path ADD CONSTRAINT FKchildent_bioentrypath
	FOREIGN KEY (subject_bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- biosequence

ALTER TABLE biosequence ADD CONSTRAINT FKbioentry_bioseq
	FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- comment

ALTER TABLE comment ADD CONSTRAINT FKbioentry_comment
	FOREIGN KEY(bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- bioentry_dbxref

ALTER TABLE bioentry_dbxref ADD CONSTRAINT FKbioentry_dblink
        FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_dbxref ADD CONSTRAINT FKdbxref_dblink
       	FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id)
	ON DELETE CASCADE;

-- dbxref_qualifier_value

ALTER TABLE dbxref_qualifier_value ADD CONSTRAINT FKtrm_dbxrefqual
	FOREIGN KEY (term_id) REFERENCES term(term_id);
ALTER TABLE dbxref_qualifier_value ADD CONSTRAINT FKdbxref_dbxrefqual
	FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id)
	ON DELETE CASCADE;

-- bioentry_reference

ALTER TABLE bioentry_reference ADD CONSTRAINT FKbioentry_entryref
	FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_reference ADD CONSTRAINT FKreference_entryref
	FOREIGN KEY (reference_id) REFERENCES reference(reference_id)
	ON DELETE CASCADE;

-- bioentry_qualifier_value

ALTER TABLE bioentry_qualifier_value ADD CONSTRAINT FKbioentry_entqual
	FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_qualifier_value ADD CONSTRAINT FKterm_entqual
	FOREIGN KEY (term_id) REFERENCES term(term_id);

-- reference 
ALTER TABLE reference ADD CONSTRAINT FKdbxref_reference
      FOREIGN KEY ( dbxref_id ) REFERENCES dbxref ( dbxref_id ) ;

-- seqfeature

ALTER TABLE seqfeature ADD CONSTRAINT FKterm_seqfeature
	FOREIGN KEY (type_term_id) REFERENCES term(term_id);
ALTER TABLE seqfeature ADD CONSTRAINT FKsourceterm_seqfeature
	FOREIGN KEY (source_term_id) REFERENCES term(term_id);
ALTER TABLE seqfeature ADD CONSTRAINT FKbioentry_seqfeature
	FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- seqfeature_relationship

ALTER TABLE seqfeature_relationship ADD CONSTRAINT FKterm_seqfeatrel
	FOREIGN KEY (term_id) REFERENCES term(term_id);
ALTER TABLE seqfeature_relationship ADD CONSTRAINT FKparentfeat_seqfeatrel
	FOREIGN KEY (object_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_relationship ADD CONSTRAINT FKchildfeat_seqfeatrel
	FOREIGN KEY (subject_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;

-- seqfeature_path

ALTER TABLE seqfeature_path ADD CONSTRAINT FKterm_seqfeatpath
	FOREIGN KEY (term_id) REFERENCES term(term_id);
ALTER TABLE seqfeature_path ADD CONSTRAINT FKparentfeat_seqfeatpath
	FOREIGN KEY (object_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_path ADD CONSTRAINT FKchildfeat_seqfeatpath
	FOREIGN KEY (subject_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;

-- seqfeature_qualifier_value
ALTER TABLE seqfeature_qualifier_value ADD CONSTRAINT FKterm_featqual
	FOREIGN KEY (term_id) REFERENCES term(term_id);
ALTER TABLE seqfeature_qualifier_value ADD CONSTRAINT FKseqfeature_featqual
	FOREIGN KEY (seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;

-- seqfeature_dbxref

ALTER TABLE seqfeature_dbxref ADD CONSTRAINT FKseqfeature_feadblink
        FOREIGN KEY (seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_dbxref ADD CONSTRAINT FKdbxref_feadblink
       	FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id)
	ON DELETE CASCADE;

-- location

ALTER TABLE location ADD CONSTRAINT FKseqfeature_location
	FOREIGN KEY (seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;
ALTER TABLE location ADD CONSTRAINT FKdbxref_location
	FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE location ADD CONSTRAINT FKterm_featloc
	FOREIGN KEY (term_id) REFERENCES term(term_id);

-- location_qualifier_value

ALTER TABLE location_qualifier_value ADD CONSTRAINT FKfeatloc_locqual
	FOREIGN KEY (location_id) REFERENCES location(location_id)
	ON DELETE CASCADE;
ALTER TABLE location_qualifier_value ADD CONSTRAINT FKterm_locqual
	FOREIGN KEY (term_id) REFERENCES term(term_id);




