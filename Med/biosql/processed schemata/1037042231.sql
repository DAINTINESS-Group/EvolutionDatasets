-- $Id$

-- conventions:
-- <table_name>_id is primary internal id (usually autogenerated)

-- author Ewan Birney
--
-- Copyright Ewan Birney. You may use, modify, and distribute this code under
-- the same terms as Perl. See the Perl Artistic License.
--
-- comments to biosql - biosql-l@open-bio.org

--
-- Migration of the MySQL schema to InnoDB by Hilmar Lapp <hlapp at gmx.net> 
--

-- database have bioentries. That is about it.
-- we do not store different versions of a database as different dbids
-- (there is no concept of versions of database). There is a concept of
-- versions of entries. Versions of databases deserve their own table and
-- join to bioentry table for tracking with versions of entries 

CREATE TABLE biodatabase (
  	biodatabase_id 	INT(10) UNSIGNED NOT NULL auto_increment,
  	name           	VARCHAR(40) NOT NULL,
	authority	VARCHAR(40),
	PRIMARY KEY (biodatabase_id),
  	UNIQUE (name)
) TYPE=INNODB;

CREATE INDEX biodatabaseidx1 on biodatabase(authority);

-- we could insist that taxa are NCBI taxon id, but on reflection I made this
-- an optional extra line, as many flat file formats do not have the NCBI id
--
-- full lineage is : delimited string starting with species.
--
-- no organelle/sub species

CREATE TABLE taxon (
  	taxon_id   	INT(10) UNSIGNED NOT NULL auto_increment,
  	binomial 	VARCHAR(96) NOT NULL,
	variant         VARCHAR(64) NOT NULL,
  	common_name 	VARCHAR(255),
  	ncbi_taxon_id 	INT(10),
  	full_lineage 	TEXT NOT NULL,
	PRIMARY KEY (taxon_id),
  	UNIQUE (binomial,variant),
  	UNIQUE (ncbi_taxon_id)
) TYPE=INNODB;


-- any controlled vocab term, everything from full ontology
-- terms eg GO IDs to the various keys allowed as qualifiers
--
-- this replaces the table "seqfeature_qualifier"
CREATE TABLE ontology_term (
       	ontology_term_id INT(10) UNSIGNED NOT NULL auto_increment,
       	term_name        VARCHAR(255) NOT NULL,
       	term_definition  TEXT,
	term_identifier	 VARCHAR(40),
	category_id      INT(10) UNSIGNED,
	PRIMARY KEY (ontology_term_id),
	UNIQUE (term_name,category_id),
	UNIQUE (term_identifier)
) TYPE=INNODB;

CREATE INDEX ontcat ON ontology_term(category_id);

-- we can be a bioentry without a biosequence, but not visa-versa
-- most things are going to be keyed off bioentry_id

-- accession is the stable id, display_id is a potentially volatile,
-- human readable name.

-- not all entries have a taxon, but many do.
-- one bioentry only has one taxon! (weirdo chimerias are not handled. tough)

CREATE TABLE bioentry (
	bioentry_id	INT(10) UNSIGNED NOT NULL auto_increment,
  	biodatabase_id  INT(10) UNSIGNED NOT NULL,
  	taxon_id     	INT(10) UNSIGNED,
  	display_id   	VARCHAR(40) NOT NULL,
  	accession    	VARCHAR(40) NOT NULL,
  	identifier   	VARCHAR(40),
  	description  	TEXT,
  	entry_version 	TINYINT, 
	PRIMARY KEY (bioentry_id),
  	UNIQUE (biodatabase_id,accession,entry_version),
  	UNIQUE (identifier)
) TYPE=INNODB;

CREATE INDEX bioentrydid  ON bioentry(display_id);
CREATE INDEX bioentryacc  ON bioentry(accession);
CREATE INDEX bioentrytax  ON bioentry(taxon_id);

--
-- bioentry-bioentry relationships: these are typed
--
CREATE TABLE bioentry_relationship (
   	parent_bioentry_id 	INT(10) UNSIGNED NOT NULL,
   	child_bioentry_id 	INT(10) UNSIGNED NOT NULL,
   	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
   	relationship_rank 	INT(5),
   	PRIMARY KEY (parent_bioentry_id,child_bioentry_id,ontology_term_id)
) TYPE=INNODB;

CREATE INDEX ber1 ON bioentry_relationship(ontology_term_id);
CREATE INDEX ber2 ON bioentry_relationship(child_bioentry_id);

-- some bioentries will have a sequence
-- biosequence because sequence is sometimes 
-- a reserved word
-- removed not null for seq_version; cjm

CREATE TABLE biosequence (
  	bioentry_id     INT(10) UNSIGNED NOT NULL,
  	seq_version     SMALLINT, 
  	seq_length      INT(10), 
  	alphabet        VARCHAR(10),
	division	VARCHAR(6),
  	biosequence_str LONGTEXT,
	PRIMARY KEY (bioentry_id)
) TYPE=INNODB;


-- new table
CREATE TABLE dbxref (
        dbxref_id	INT(10) UNSIGNED NOT NULL auto_increment,
        dbname          VARCHAR(40) NOT NULL,
        accession       VARCHAR(40) NOT NULL,
	version		TINYINT NOT NULL,
	PRIMARY KEY (dbxref_id),
        UNIQUE(dbname, accession, version)
) TYPE=INNODB;

CREATE INDEX dbxrefdbn  ON dbxref(dbname);
CREATE INDEX dbxrefacc  ON dbxref(accession);

-- new table
-- for roundtripping embl/genbank, we need to have the "optional ID"
-- for the dbxref.
--
-- another use of this table could be for storing
-- descriptive text for a dbxref. for example, we may want to
-- know stuff about the interpro accessions we store (without
-- importing all of interpro), so we can attach the text
-- description as a synonym

CREATE TABLE dbxref_qualifier_value (
	dbxref_qualifier_value_id  INT(10) UNSIGNED NOT NULL auto_increment,
       	dbxref_id 		INT(10) UNSIGNED NOT NULL,
       	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
       	qualifier_value		TEXT,
	PRIMARY KEY (dbxref_qualifier_value_id)
) TYPE=INNODB;

CREATE INDEX dqv1  ON dbxref_qualifier_value(dbxref_id);
CREATE INDEX dqv2  ON dbxref_qualifier_value(ontology_term_id);

-- Direct dblinks. It is tempting to do this
-- from bioentry_id to bioentry_id. But that wont work
-- during updates of one database - we will have to edit
-- this table each time. Better to do the join through accession
-- and db each time. Should be almost as cheap

CREATE TABLE bioentry_dblink (
       	bioentry_id        INT(10) UNSIGNED NOT NULL,
       	dbxref_id          INT(10) UNSIGNED NOT NULL,
	PRIMARY KEY (bioentry_id,dbxref_id)
) TYPE=INNODB;

CREATE INDEX bdl2  ON bioentry_dblink(dbxref_id);

-- We can have multiple references per bioentry, but one reference
-- can also be used for the same bioentry.

CREATE TABLE reference (
  	reference_id       INT(10) UNSIGNED NOT NULL auto_increment,
  	reference_location TEXT NOT NULL,
  	reference_title    TEXT,
  	reference_authors  TEXT NOT NULL,
  	reference_medline  INT(10),
	PRIMARY KEY (reference_id),
	UNIQUE (reference_medline)
) TYPE=INNODB;

CREATE INDEX medlineidx ON reference(reference_medline);

CREATE TABLE bioentry_reference (
  	bioentry_id 	INT(10) UNSIGNED NOT NULL,
  	reference_id 	INT(10) UNSIGNED NOT NULL,
  	reference_start INT(10),
  	reference_end   INT(10),
  	reference_rank  SMALLINT NOT NULL,
  	PRIMARY KEY(bioentry_id,reference_id,reference_rank)
) TYPE=INNODB;

CREATE INDEX reference_rank_idx3 ON bioentry_reference(reference_id);
CREATE INDEX reference_rank_idx5 ON bioentry_reference(bioentry_id, reference_rank);


-- We can have multiple comments per seqentry, and
-- comments can have embedded '\n' characters

CREATE TABLE comment (
  	comment_id  	INT(10) UNSIGNED NOT NULL auto_increment,
  	bioentry_id    	INT(10) UNSIGNED NOT NULL,
  	comment_text   	TEXT NOT NULL,
  	comment_rank   	SMALLINT NOT NULL,
	PRIMARY KEY (comment_id),
  	UNIQUE(bioentry_id, comment_rank)
) TYPE=INNODB;
-- CREATE INDEX cmtidx1 ON comment(bioentry_id);

-- separate description table separate to save on space when we
-- do not store descriptions

-- this table replaces the old bioentry_description and bioentry_keywords
-- tables
CREATE TABLE bioentry_qualifier_value (
	bioentry_id   		INT(10) UNSIGNED NOT NULL,
   	ontology_term_id  	INT(10) UNSIGNED NOT NULL,
   	qualifier_value         TEXT,
	qualifier_rank		INT(5),
	UNIQUE (bioentry_id,ontology_term_id,qualifier_rank)
) TYPE=INNODB;

CREATE INDEX bqv2 ON bioentry_qualifier_value(ontology_term_id);

-- feature table. We cleanly handle
--   - simple locations
--   - split locations
--   - split locations on remote sequences

-- The fuzzies are not handled yet

CREATE TABLE seqfeature (
   	seqfeature_id 		INT(10) UNSIGNED NOT NULL auto_increment,
   	bioentry_id   		INT(10) UNSIGNED NOT NULL,
   	ontology_term_id	INT(10) UNSIGNED,
   	seqfeature_source_id  	INT(10) UNSIGNED,
   	seqfeature_rank 	INT(5),
	PRIMARY KEY (seqfeature_id),
	UNIQUE (bioentry_id,ontology_term_id,seqfeature_source_id,seqfeature_rank)
) TYPE=INNODB;

CREATE INDEX sf1 ON seqfeature(ontology_term_id);
CREATE INDEX sf2 ON seqfeature(seqfeature_source_id);

-- seqfeatures can be arranged in containment hierarchies.
-- one can imagine storing other relationships between features,
-- in this case the ontology_term_id can be used to type the relationship

CREATE TABLE seqfeature_relationship (
   	parent_seqfeature_id	INT(10) UNSIGNED NOT NULL,
   	child_seqfeature_id 	INT(10) UNSIGNED NOT NULL,
   	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
   	relationship_rank 	INT(5),
   	PRIMARY KEY (parent_seqfeature_id,child_seqfeature_id,ontology_term_id)
) TYPE=INNODB;

CREATE INDEX sfr1 ON seqfeature_relationship(ontology_term_id);
CREATE INDEX sfr3 ON seqfeature_relationship(child_seqfeature_id);

CREATE TABLE seqfeature_qualifier_value (
	seqfeature_id 		INT(10) UNSIGNED NOT NULL,
   	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
   	qualifier_rank 		SMALLINT NOT NULL,
   	qualifier_value  	TEXT NOT NULL,
   	PRIMARY KEY (seqfeature_id,ontology_term_id,qualifier_rank)
) TYPE=INNODB;

CREATE INDEX sqv1 ON seqfeature_qualifier_value(ontology_term_id);
   
-- basically we model everything as potentially having
-- any number of locations, ie, a split location. SimpleLocations
-- just have one location. We need to have a location id for the qualifier
-- associations of fuzzy locations.

-- please do not try to model complex assemblies with this thing. It wont
-- work. Check out the ensembl schema for this.

-- we allow nulls for start/end - this is useful for fuzzies as
-- standard range queries will not be included

-- for remote locations, the join to make is to DBXref
-- the FK to ontology_term is a possibility to store the type of the
-- location for determining in one hit whether it's a fuzzy or not

CREATE TABLE seqfeature_location (
	seqfeature_location_id 	INT(10) UNSIGNED NOT NULL auto_increment,
   	seqfeature_id		INT(10) UNSIGNED NOT NULL,
	dbxref_id		INT(10) UNSIGNED,
	ontology_term_id	INT(10) UNSIGNED,
   	seq_start              	INT(10),
   	seq_end                	INT(10),
   	seq_strand             	TINYINT NOT NULL,
   	location_rank          	SMALLINT,
	PRIMARY KEY (seqfeature_location_id),
   	UNIQUE (seqfeature_id, location_rank)
) TYPE=INNODB;

CREATE INDEX sfl2 ON seqfeature_location(seq_start);
CREATE INDEX sfl3 ON seqfeature_location(seq_end);
CREATE INDEX sfl4 ON seqfeature_location(dbxref_id);
CREATE INDEX sfl5 ON seqfeature_location(ontology_term_id);

-- location qualifiers - mainly intended for fuzzies but anything
-- can go in here
-- some controlled vocab terms have slots;
-- fuzzies could be modeled as min_start(5), max_start(5)
-- 
-- there is no restriction on extending the fuzzy ontology
-- for your own nefarious aims, although the bio* apis will
-- most likely ignore these
CREATE TABLE location_qualifier_value (
	seqfeature_location_id	INT(10) UNSIGNED NOT NULL,
   	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
   	qualifier_value  	VARCHAR(255) NOT NULL,
   	qualifier_int_value 	INT(10),
	PRIMARY KEY (seqfeature_location_id,ontology_term_id)
) TYPE=INNODB;

-- CREATE INDEX lqv1 ON location_qualifier_value(seqfeature_location_id);
CREATE INDEX lqv2 ON location_qualifier_value(ontology_term_id);

--
-- this is a tiny table to allow a caching corba server to
-- persistently store aspects of the root server - so when/if
-- the server gets reaped it can reconnect
--

CREATE TABLE cache_corba_support (
       biodatabase_id    int(10) unsigned NOT NULL PRIMARY KEY,  
       http_ior_string   VARCHAR(255),
       direct_ior_string VARCHAR(255)
       );

--
-- Create the foreign key constraints
--

-- ontology
ALTER TABLE ontology_term ADD CONSTRAINT FKontology_ontology
	FOREIGN KEY (category_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;

-- bioentry
ALTER TABLE bioentry ADD CONSTRAINT FKtaxon_bioentry
	FOREIGN KEY (taxon_id) REFERENCES taxon(taxon_id);
ALTER TABLE bioentry ADD CONSTRAINT FKbiodatabase_bioentry
	FOREIGN KEY (biodatabase_id) REFERENCES biodatabase(biodatabase_id);

-- bioentry_relationship
ALTER TABLE bioentry_relationship ADD CONSTRAINT FKontology_bioentryrel
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id)	ON DELETE CASCADE;
ALTER TABLE bioentry_relationship ADD CONSTRAINT FKparentent_bioentryrel
	FOREIGN KEY (parent_bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_relationship ADD CONSTRAINT FKchildent_bioentryrel
	FOREIGN KEY (child_bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- biosequence
ALTER TABLE biosequence ADD CONSTRAINT FKbioentry_bioseq
	FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- comment
ALTER TABLE comment ADD CONSTRAINT FKbioentry_comment
	FOREIGN KEY(bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- bioentry_dblink
ALTER TABLE bioentry_dblink ADD CONSTRAINT FKbioentry_dblink
        FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_dblink ADD CONSTRAINT FKdbxref_dblink
       	FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id)
	ON DELETE CASCADE;

-- dbxref_qualifier_value
ALTER TABLE dbxref_qualifier_value ADD CONSTRAINT FKont_dbxrefqual
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);
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
ALTER TABLE bioentry_qualifier_value ADD CONSTRAINT FKontology_entqual
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;

-- seqfeature
ALTER TABLE seqfeature ADD CONSTRAINT FKontology_seqfeature
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);
ALTER TABLE seqfeature ADD CONSTRAINT FKsourceterm_seqfeature
	FOREIGN KEY (seqfeature_source_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature ADD CONSTRAINT FKbioentry_seqfeature
	FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- seqfeature_relationship
ALTER TABLE seqfeature_relationship ADD CONSTRAINT FKontology_seqfeatrel
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id)	ON DELETE CASCADE;
ALTER TABLE seqfeature_relationship ADD CONSTRAINT FKparentfeat_seqfeatrel
	FOREIGN KEY (parent_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_relationship ADD CONSTRAINT FKchildfeat_seqfeatrel
	FOREIGN KEY (child_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;

-- seqfeature_qualifier_value
ALTER TABLE seqfeature_qualifier_value ADD CONSTRAINT FKontology_featqual
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_qualifier_value ADD CONSTRAINT FKseqfeature_featqual
	FOREIGN KEY (seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;

-- seqfeature_location
ALTER TABLE seqfeature_location ADD CONSTRAINT FKseqfeature_featloc
	FOREIGN KEY (seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_location ADD CONSTRAINT FKdbxref_featloc
	FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_location ADD CONSTRAINT FKontologyterm_featloc
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;

-- location_qualifier_value
ALTER TABLE location_qualifier_value ADD CONSTRAINT FKfeatloc_locqual
	FOREIGN KEY (seqfeature_location_id) REFERENCES seqfeature_location(seqfeature_location_id)
	ON DELETE CASCADE;
ALTER TABLE location_qualifier_value ADD CONSTRAINT FKontology_locqual
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;

-- Done with foreign key constraints.

-- pre-make the fuzzy ontology
-- CREATE TABLE _tmp AS SELECT * FROM ontology_term;
-- INSERT INTO ontology_term (term_name) VALUES ('Location Tags');
-- INSERT INTO _tmp (term_name, category_id)
-- SELECT 'min_start', t.ontology_term_id
-- FROM ontology_term t WHERE t.term_name = 'Location Tags';
-- INSERT INTO _tmp (term_name, category_id)
-- SELECT 'min_end', t.ontology_term_id
-- FROM ontology_term t WHERE t.term_name = 'Location Tags';
-- INSERT INTO _tmp (term_name, category_id)
-- SELECT 'max_start', t.ontology_term_id
-- FROM ontology_term t WHERE t.term_name = 'Location Tags';
-- INSERT INTO _tmp (term_name, category_id)
-- SELECT 'max_end', t.ontology_term_id
-- FROM ontology_term t WHERE t.term_name = 'Location Tags';
-- INSERT INTO _tmp (term_name, category_id)
-- SELECT 'unknown_start', t.ontology_term_id
-- FROM ontology_term t WHERE t.term_name = 'Location Tags';
-- INSERT INTO _tmp (term_name, category_id)
-- SELECT 'unknown_end', t.ontology_term_id
-- FROM ontology_term t WHERE t.term_name = 'Location Tags';
-- INSERT INTO _tmp (term_name, category_id)
-- SELECT 'end_pos_type', t.ontology_term_id
-- FROM ontology_term t WHERE t.term_name = 'Location Tags';
-- INSERT INTO _tmp (term_name, category_id)
-- SELECT 'start_pos_type', t.ontology_term_id
-- FROM ontology_term t WHERE t.term_name = 'Location Tags';
-- INSERT INTO _tmp (term_name, category_id)
-- SELECT 'location_type', t.ontology_term_id
-- FROM ontology_term t WHERE t.term_name = 'Location Tags';

-- INSERT INTO ontology_term (term_name, category_id)
-- SELECT t.term_name, t.category_id FROM _tmp t;

-- DROP TABLE _tmp;
-- coordinate policies?



