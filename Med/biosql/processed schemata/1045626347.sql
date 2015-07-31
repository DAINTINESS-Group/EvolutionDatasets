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
  	name           	VARCHAR(128) NOT NULL,
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

CREATE TABLE taxon_name (
       taxon_id		INT(10) UNSIGNED NOT NULL,
       name		VARCHAR(255) NOT NULL,
       name_class	VARCHAR(32) NOT NULL,
       UNIQUE (taxon_id,name,name_class)
) TYPE=INNODB;

CREATE INDEX taxnametaxonid ON taxon_name(taxon_id);
CREATE INDEX taxnamename    ON taxon_name(name);

-- this is the namespace (controlled vocabulary) ontology terms live in
-- we chose to have a separate table for this instead of reusing biodatabase
CREATE TABLE ontology (
       	ontology_id        INT(10) UNSIGNED NOT NULL auto_increment,
       	name	   	   VARCHAR(32) NOT NULL,
       	definition	   TEXT,
	PRIMARY KEY (ontology_id),
	UNIQUE (name)
) TYPE=INNODB;

-- any controlled vocab term, everything from full ontology
-- terms eg GO IDs to the various keys allowed as qualifiers
--
CREATE TABLE ontology_term (
       	ontology_term_id   INT(10) UNSIGNED NOT NULL auto_increment,
       	name	   	   VARCHAR(255) NOT NULL,
       	definition	   TEXT,
	identifier	   VARCHAR(40),
	ontology_id	   INT(10) UNSIGNED NOT NULL,
	PRIMARY KEY (ontology_term_id),
	UNIQUE (name,ontology_id),
	UNIQUE (identifier)
) TYPE=INNODB;

CREATE INDEX ont_cat ON ontology_term(ontology_id);

-- ontology terms to dbxref association: ontology terms have dbxrefs
CREATE TABLE ontology_dbxref (
       	ontology_term_id	INT(10) UNSIGNED NOT NULL,
       	dbxref_id               INT(10) UNSIGNED NOT NULL,
	PRIMARY KEY (ontology_term_id, dbxref_id)
) TYPE=INNODB;

CREATE INDEX ontdbxref_dbxrefid ON ontology_dbxref(dbxref_id);

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

CREATE TABLE ontology_relationship (
        ontology_relationship_id INT(10) UNSIGNED NOT NULL auto_increment,
       	subject_id	INT(10) UNSIGNED NOT NULL,
       	predicate_id    INT(10) UNSIGNED NOT NULL,
       	object_id       INT(10) UNSIGNED NOT NULL,
	ontology_id	INT(10) UNSIGNED,
	PRIMARY KEY (ontology_relationship_id),
	UNIQUE (subject_id,predicate_id,object_id,ontology_id)
) TYPE=INNODB;

CREATE INDEX ontrel_predicateid ON ontology_relationship(predicate_id);
CREATE INDEX ontrel_objectid ON ontology_relationship(object_id);
-- you may want to add this for mysql because MySQL often is broken with
-- respect to using the composite index for the initial keys
--CREATE INDEX ontrel_subjectid ON ontology_relationship(subject_id);

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
CREATE TABLE ontology_path (
       	subject_id	INT(10) UNSIGNED NOT NULL,
       	predicate_id    INT(10) UNSIGNED NOT NULL,
       	object_id       INT(10) UNSIGNED NOT NULL,
	distance	INT(10) UNSIGNED,
	PRIMARY KEY (subject_id,predicate_id,object_id)
) TYPE=INNODB;

CREATE INDEX ontpath_predicateid ON ontology_path(predicate_id);
CREATE INDEX ontpath_objectid ON ontology_path(object_id);
-- you may want to add this for mysql because MySQL often is broken with
-- respect to using the composite index for the initial keys
--CREATE INDEX ontpath_subjectid ON ontology_path(subject_id);

-- we can be a bioentry without a biosequence, but not visa-versa
-- most things are going to be keyed off bioentry_id

-- accession is the stable id, display_id is a potentially volatile,
-- human readable name.

-- not all entries have a taxon, but many do.
-- one bioentry only has one taxon! (weirdo chimerias are not handled. tough)

-- Name maps to display_id in bioperl. We have a different column name
-- here to avoid confusion with the naming convention for foreign keys.

CREATE TABLE bioentry (
	bioentry_id	INT(10) UNSIGNED NOT NULL auto_increment,
  	biodatabase_id  INT(10) UNSIGNED NOT NULL,
  	taxon_id     	INT(10) UNSIGNED,
  	name		VARCHAR(40) NOT NULL,
  	accession    	VARCHAR(40) NOT NULL,
  	identifier   	VARCHAR(40),
	division	VARCHAR(6),
  	description  	TEXT,
  	version 	SMALLINT UNSIGNED, 
	PRIMARY KEY (bioentry_id),
  	UNIQUE (accession,biodatabase_id,version),
  	UNIQUE (identifier)
) TYPE=INNODB;

CREATE INDEX bioentry_name ON bioentry(name);
CREATE INDEX bioentry_db   ON bioentry(biodatabase_id);
CREATE INDEX bioentry_tax  ON bioentry(taxon_id);

--
-- bioentry-bioentry relationships: these are typed
--
CREATE TABLE bioentry_relationship (
        bioentry_relationship_id INT(10) UNSIGNED NOT NULL auto_increment,
   	parent_bioentry_id 	INT(10) UNSIGNED NOT NULL,
   	child_bioentry_id 	INT(10) UNSIGNED NOT NULL,
   	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
   	rank 			INT(5),
   	PRIMARY KEY (bioentry_relationship_id),
	UNIQUE (parent_bioentry_id,child_bioentry_id,ontology_term_id)
) TYPE=INNODB;

CREATE INDEX bioentryrel_ont   ON bioentry_relationship(ontology_term_id);
CREATE INDEX bioentryrel_child ON bioentry_relationship(child_bioentry_id);
-- you may want to add this for mysql because MySQL often is broken with
-- respect to using the composite index for the initial keys
--CREATE INDEX bioentryrel_parent ON bioentry_relationship(parent_bioentry_id);

-- for deep (depth > 1) bioentry relationship trees we need a transitive
-- closure table too
CREATE TABLE bioentry_path (
   	parent_bioentry_id 	INT(10) UNSIGNED NOT NULL,
   	child_bioentry_id 	INT(10) UNSIGNED NOT NULL,
   	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
	PRIMARY KEY (parent_bioentry_id,child_bioentry_id,ontology_term_id)
) TYPE=INNODB;

CREATE INDEX bioentrypath_ont   ON bioentry_path(ontology_term_id);
CREATE INDEX bioentrypath_child ON bioentry_path(child_bioentry_id);
-- you may want to add this for mysql because MySQL often is broken with
-- respect to using the composite index for the initial keys
--CREATE INDEX bioentrypath_parent ON bioentry_path(parent_bioentry_id);

-- some bioentries will have a sequence
-- biosequence because sequence is sometimes a reserved word

CREATE TABLE biosequence (
  	bioentry_id     INT(10) UNSIGNED NOT NULL,
  	version     	SMALLINT, 
  	length      	INT(10),
	pI		NUMERIC(4,2),
	MW		DOUBLE ,
  	alphabet        VARCHAR(10),
  	seq 		LONGTEXT,
	PRIMARY KEY (bioentry_id)
) TYPE=INNODB;


-- database cross-references (e.g., GenBank:AC123456.1)
CREATE TABLE dbxref (
        dbxref_id	INT(10) UNSIGNED NOT NULL auto_increment,
        dbname          VARCHAR(40) NOT NULL,
        accession       VARCHAR(40) NOT NULL,
	version		SMALLINT UNSIGNED NOT NULL,
	PRIMARY KEY (dbxref_id),
        UNIQUE(accession, dbname, version)
) TYPE=INNODB;

CREATE INDEX dbxref_db  ON dbxref(dbname);

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
  	rank  		   	SMALLINT,
       	value			TEXT,
	PRIMARY KEY (dbxref_qualifier_value_id),
	UNIQUE (dbxref_id,ontology_term_id,rank)
) TYPE=INNODB;

CREATE INDEX dbxrefqual_dbx ON dbxref_qualifier_value(dbxref_id);
CREATE INDEX dbxrefqual_ont ON dbxref_qualifier_value(ontology_term_id);

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
  	authors  	   TEXT NOT NULL,
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
  	rank  		SMALLINT NOT NULL,
  	PRIMARY KEY(bioentry_id,reference_id,rank)
) TYPE=INNODB;

CREATE INDEX bioentryref_ref ON bioentry_reference(reference_id);


-- We can have multiple comments per seqentry, and
-- comments can have embedded '\n' characters

CREATE TABLE comment (
  	comment_id  	INT(10) UNSIGNED NOT NULL auto_increment,
  	bioentry_id    	INT(10) UNSIGNED NOT NULL,
  	comment_text   	TEXT NOT NULL,
  	rank   		SMALLINT NOT NULL,
	PRIMARY KEY (comment_id),
  	UNIQUE(bioentry_id, rank)
) TYPE=INNODB;


-- this table replaces the old bioentry_description and bioentry_keywords
-- tables

CREATE TABLE bioentry_qualifier_value (
	bioentry_id   		INT(10) UNSIGNED NOT NULL,
   	ontology_term_id  	INT(10) UNSIGNED NOT NULL,
   	value         		TEXT,
	rank			INT(5),
	UNIQUE (bioentry_id,ontology_term_id,rank)
) TYPE=INNODB;

CREATE INDEX bioentryqual_ont ON bioentry_qualifier_value(ontology_term_id);

-- feature table. We cleanly handle
--   - simple locations
--   - split locations
--   - split locations on remote sequences

CREATE TABLE seqfeature (
   	seqfeature_id 		INT(10) UNSIGNED NOT NULL auto_increment,
   	bioentry_id   		INT(10) UNSIGNED NOT NULL,
   	type_term_id		INT(10) UNSIGNED NOT NULL,
   	source_term_id  	INT(10) UNSIGNED,
	display_name		VARCHAR(64),
   	rank 			SMALLINT UNSIGNED NOT NULL,
	PRIMARY KEY (seqfeature_id),
	UNIQUE (bioentry_id,type_term_id,source_term_id,rank)
) TYPE=INNODB;

CREATE INDEX seqfeature_ont  ON seqfeature(type_term_id);
CREATE INDEX seqfeature_fsrc ON seqfeature(source_term_id);
-- you may want to add this for mysql because MySQL often is broken with
-- respect to using the composite index for the initial keys
--CREATE INDEX seqfeature_bioentryid ON seqfeature(bioentry_id);

-- seqfeatures can be arranged in containment hierarchies.
-- one can imagine storing other relationships between features,
-- in this case the ontology_term_id can be used to type the relationship

CREATE TABLE seqfeature_relationship (
        seqfeature_relationship_id INT(10) UNSIGNED NOT NULL auto_increment,
   	parent_seqfeature_id	INT(10) UNSIGNED NOT NULL,
   	child_seqfeature_id 	INT(10) UNSIGNED NOT NULL,
   	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
   	rank 			INT(5),
   	PRIMARY KEY (seqfeature_relationship_id),
	UNIQUE (parent_seqfeature_id,child_seqfeature_id,ontology_term_id)
) TYPE=INNODB;

CREATE INDEX seqfeaturerel_ont   ON seqfeature_relationship(ontology_term_id);
CREATE INDEX seqfeaturerel_child ON seqfeature_relationship(child_seqfeature_id);
-- you may want to add this for mysql because MySQL often is broken with
-- respect to using the composite index for the initial keys
--CREATE INDEX seqfeaturerel_parent ON seqfeature_relationship(parent_seqfeature_id);

-- for deep (depth > 1) bioentry relationship trees we need a transitive
-- closure table too
CREATE TABLE seqfeature_path (
   	parent_seqfeature_id	INT(10) UNSIGNED NOT NULL,
   	child_seqfeature_id 	INT(10) UNSIGNED NOT NULL,
   	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
	PRIMARY KEY (parent_seqfeature_id,child_seqfeature_id,ontology_term_id)
) TYPE=INNODB;

CREATE INDEX seqfeaturepath_ont   ON seqfeature_path(ontology_term_id);
CREATE INDEX seqfeaturepath_child ON seqfeature_path(child_seqfeature_id);
-- you may want to add this for mysql because MySQL often is broken with
-- respect to using the composite index for the initial keys
--CREATE INDEX seqfeaturerel_parent ON seqfeature_path(parent_seqfeature_id);

-- tag/value associations - or ontology annotations
CREATE TABLE seqfeature_qualifier_value (
	seqfeature_id 		INT(10) UNSIGNED NOT NULL,
   	ontology_term_id 	INT(10) UNSIGNED NOT NULL,
   	rank 			SMALLINT NOT NULL,
   	value  			TEXT NOT NULL,
   	PRIMARY KEY (seqfeature_id,ontology_term_id,rank)
) TYPE=INNODB;

CREATE INDEX seqfeaturequal_ont ON seqfeature_qualifier_value(ontology_term_id);
   
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
   	start_pos              	INT(10),
   	end_pos                	INT(10),
   	strand             	TINYINT NOT NULL,
   	rank          		SMALLINT,
	PRIMARY KEY (seqfeature_location_id),
   	UNIQUE (seqfeature_id, rank)
) TYPE=INNODB;

CREATE INDEX seqfeatureloc_start ON seqfeature_location(start_pos);
CREATE INDEX seqfeatureloc_end   ON seqfeature_location(end_pos);
CREATE INDEX seqfeatureloc_dbx   ON seqfeature_location(dbxref_id);
CREATE INDEX seqfeatureloc_ont   ON seqfeature_location(ontology_term_id);

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
   	value  			VARCHAR(255) NOT NULL,
   	int_value 		INT(10),
	PRIMARY KEY (seqfeature_location_id,ontology_term_id)
) TYPE=INNODB;

CREATE INDEX locationqual_ont ON location_qualifier_value(ontology_term_id);

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
	FOREIGN KEY (ontology_id) REFERENCES ontology(ontology_id)
	ON DELETE CASCADE;

-- ontology_dbxref
ALTER TABLE ontology_dbxref ADD CONSTRAINT FKdbxref_ontdbxref
       	FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id)
	ON DELETE CASCADE;
ALTER TABLE ontology_dbxref ADD CONSTRAINT FKontology_ontdbxref
      FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;

-- ontology_relationship

ALTER TABLE ontology_relationship ADD CONSTRAINT FKontsubject_ont
	FOREIGN KEY (subject_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;
ALTER TABLE ontology_relationship ADD CONSTRAINT FKontpredicate_ont
       	FOREIGN KEY (predicate_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;
ALTER TABLE ontology_relationship ADD CONSTRAINT FKontobject_ont
       	FOREIGN KEY (object_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;

-- ontology_path

ALTER TABLE ontology_path ADD CONSTRAINT FKontsubject_ontpath
	FOREIGN KEY (subject_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;
ALTER TABLE ontology_path ADD CONSTRAINT FKontpredicate_ontpath
       	FOREIGN KEY (predicate_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;
ALTER TABLE ontology_path ADD CONSTRAINT FKontobject_ontpath
       	FOREIGN KEY (object_id) REFERENCES ontology_term(ontology_term_id)
	ON DELETE CASCADE;

-- taxon, taxon_name
ALTER TABLE taxon ADD CONSTRAINT FKtaxon_taxon
        FOREIGN KEY (parent_taxon_id) REFERENCES taxon(taxon_id)
        ON DELETE CASCADE; 
ALTER TABLE taxon_name ADD CONSTRAINT FKtaxon_taxonname
        FOREIGN KEY (taxon_id) REFERENCES taxon(taxon_id)
        ON DELETE CASCADE;

-- bioentry
ALTER TABLE bioentry ADD CONSTRAINT FKtaxon_bioentry
	FOREIGN KEY (taxon_id) REFERENCES taxon(taxon_id);
ALTER TABLE bioentry ADD CONSTRAINT FKbiodatabase_bioentry
	FOREIGN KEY (biodatabase_id) REFERENCES biodatabase(biodatabase_id);

-- bioentry_relationship

ALTER TABLE bioentry_relationship ADD CONSTRAINT FKontology_bioentryrel
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);
ALTER TABLE bioentry_relationship ADD CONSTRAINT FKparentent_bioentryrel
	FOREIGN KEY (parent_bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_relationship ADD CONSTRAINT FKchildent_bioentryrel
	FOREIGN KEY (child_bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- bioentry_path

ALTER TABLE bioentry_path ADD CONSTRAINT FKontology_bioentrypath
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);
ALTER TABLE bioentry_path ADD CONSTRAINT FKparentent_bioentrypath
	FOREIGN KEY (parent_bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_path ADD CONSTRAINT FKchildent_bioentrypath
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

-- bioentry_dbxref
ALTER TABLE bioentry_dbxref ADD CONSTRAINT FKbioentry_dblink
        FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;
ALTER TABLE bioentry_dbxref ADD CONSTRAINT FKdbxref_dblink
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
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);

-- seqfeature
ALTER TABLE seqfeature ADD CONSTRAINT FKontology_seqfeature
	FOREIGN KEY (type_term_id) REFERENCES ontology_term(ontology_term_id);
ALTER TABLE seqfeature ADD CONSTRAINT FKsourceterm_seqfeature
	FOREIGN KEY (source_term_id) REFERENCES ontology_term(ontology_term_id);
ALTER TABLE seqfeature ADD CONSTRAINT FKbioentry_seqfeature
	FOREIGN KEY (bioentry_id) REFERENCES bioentry(bioentry_id)
	ON DELETE CASCADE;

-- seqfeature_relationship

ALTER TABLE seqfeature_relationship ADD CONSTRAINT FKontology_seqfeatrel
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);
ALTER TABLE seqfeature_relationship ADD CONSTRAINT FKparentfeat_seqfeatrel
	FOREIGN KEY (parent_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_relationship ADD CONSTRAINT FKchildfeat_seqfeatrel
	FOREIGN KEY (child_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;

-- seqfeature_path

ALTER TABLE seqfeature_path ADD CONSTRAINT FKontology_seqfeatpath
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);
ALTER TABLE seqfeature_path ADD CONSTRAINT FKparentfeat_seqfeatpath
	FOREIGN KEY (parent_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_path ADD CONSTRAINT FKchildfeat_seqfeatpath
	FOREIGN KEY (child_seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;

-- seqfeature_qualifier_value
ALTER TABLE seqfeature_qualifier_value ADD CONSTRAINT FKontology_featqual
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);
ALTER TABLE seqfeature_qualifier_value ADD CONSTRAINT FKseqfeature_featqual
	FOREIGN KEY (seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;

-- seqfeature_location
ALTER TABLE seqfeature_location ADD CONSTRAINT FKseqfeature_featloc
	FOREIGN KEY (seqfeature_id) REFERENCES seqfeature(seqfeature_id)
	ON DELETE CASCADE;
ALTER TABLE seqfeature_location ADD CONSTRAINT FKdbxref_featloc
	FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE seqfeature_location ADD CONSTRAINT FKontologyterm_featloc
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);

-- location_qualifier_value
ALTER TABLE location_qualifier_value ADD CONSTRAINT FKfeatloc_locqual
	FOREIGN KEY (seqfeature_location_id) REFERENCES seqfeature_location(seqfeature_location_id)
	ON DELETE CASCADE;
ALTER TABLE location_qualifier_value ADD CONSTRAINT FKontology_locqual
	FOREIGN KEY (ontology_term_id) REFERENCES ontology_term(ontology_term_id);

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



