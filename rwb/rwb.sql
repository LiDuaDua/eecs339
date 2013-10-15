--
-- Part of the Red, White, and Blue example application
-- from EECS 339 at Northwestern University
--
--
-- This contains *part* of the Red, White, and Blue data
-- schema.  It does not include the representation of the
-- FEC data and the Geolocation data,  which is available
-- separately in ~pdinda/339/HANDOUT/rwb/fec.
-- These shared tables should be
-- access using cs339.tablename, that is, the student groups
-- share the FEC and geolocation data
--
-- Primarily, what's contained here is the user model
-- permissions, etc.  These should be accessed as tablename,
-- that is, each student group's tables are a separate
--
--

--temp while debugging
drop table rwb_invites;
drop table rwb_permissions;
drop table rwb_actions;
drop table rwb_opinions;
drop table rwb_cs_ind_to_geo;
drop table rwb_users;

--
-- RWB users.  Self explanatory
--
create table rwb_users (
--
-- Each user must have a name and a unique one at that.
--
  name  varchar(64) not null primary key,
--
-- Each user must have a password of at least eight characters
--
-- Note - this keeps the password in clear text in the database
-- which is a bad practice and only useful for illustration
--
-- The right way to do this is to store an encrypted password
-- in the database
--
  password varchar(64) not null,
    constraint long_passwd check (password like '________%'),
--
-- Each user must have an email address and it must be unique
-- the constraint checks to see that there is an "@" in the name
--
  email    varchar(256) not null unique
    constraint email_ok check (email like '%@%'),
--
-- Except for the root user and the nobody users, a user must be
-- validated by an existing user (but not nobody)
--
  referer varchar(64) not null references rwb_users(name),
--
-- Only root can refer himself
--
  constraint sane_referer check (name='root' or name<>referer)
);

create table rwb_invites (
  code varchar(64) not null primary key,
---
  email varchar(256) not null unique constraint email_ok2 check (email like '%@%'),
---
  referer varchar(64) not null references rwb_users(name)
);

--
-- the list of things that a user can do on the system
--
create table rwb_actions (
  action varchar(64) NOT NULL primary key
);

--
-- And the mapping from users to their actions
--
create table rwb_permissions (
--
-- must be a current user on the system.  if a user is deleted
-- his permissions should be deleted with him
--
  name  varchar(64) not null references rwb_users(name)
     on delete cascade,
--
-- must be a current action on the system.  if an action is deleted
-- then all permissions with that action must also be deleted
--
  action varchar(64) not null references rwb_actions(action)
     on delete cascade,
--
-- name->action mappings must be unique
--
--
  constraint perm_unique unique(name,action)
);


--
-- The crowd-sourced individual to geolocation coordinates
-- The FEC data gives individual geolocation to the level
-- of
--
create table rwb_cs_ind_to_geo (
--
-- Requester must be a user
--
  requester varchar(64) not null references rwb_users(name) on delete cascade,
--
-- Submitter must be a user
-- If this is null, it indicates that the geolocation is requested
--
  submitter varchar(64) references rwb_users(name) on delete cascade,
--
-- Validator must be a user
-- If this is null, it indicates that the geolocation needs to be
-- validated
--
  validator varchar(64) references rwb_users(name) on delete cascade,
--
-- Validator must not be the submitter
--
  constraint val_differ check ((validator is null) or (submitter <> validator)),
--
-- Request and validation times (Unix timestamps), zeros mean "not done yet"
--
-- must be given at record create time
  request_time number not null,
-- given later
  submission_time number default 0 not null,
-- given later
  validation_time number default 0 not null,
--
-- An individual is identified by the following
-- references into the individuals table
--
-- Can't do the refs since we don't have a primary key on individual...
--
  ind_name  varchar2(200) not null, -- references cs339.individual(name),
  ind_city  varchar2(30) not null, -- references  cs339.individual(city),
  ind_state varchar2(2) not null, --  references   cs339.individual(state),
  ind_zip   varchar2(9) not null, -- references   cs339.individual(zip_code),
--
-- The geolocation info
--
  latitude number default 0 not null,
  longitude number default 0 not null
);


--
--
-- Opinions
--
create table rwb_opinions (
--
-- Submitter must be a user
--
  submitter varchar(64) not null references rwb_users(name) on delete cascade,
--
-- (color scale -1=>Red, +1=>Blue, 0=>Neutral
--
  color number not null check (color between -1 and 1),
--
-- Location
--
  latitude number not null,
  longitude number not null
);

--
-- Create a set of actions
--
--
insert into rwb_actions values ('manage-users');
insert into rwb_actions values ('invite-users');
insert into rwb_actions values ('add-users');
insert into rwb_actions values ('query-fec-data');
insert into rwb_actions values ('query-cs-ind-data');
insert into rwb_actions values ('query-opinion-data');
insert into rwb_actions values ('give-cs-ind-data');
insert into rwb_actions values ('give-opinion-data');

--
-- Create the required users
--
insert into rwb_users (name,password,email,referer) values ('root','rootroot','root@root.com','root');
insert into rwb_users (name,password,email,referer) values ('anon','anonanon','anon@anon.com','root');

--
-- And what they can do  (root can do everything, none can do nothing)
--
-- Anon can simply query
--
insert into rwb_permissions (name,action) values('anon','query-fec-data');
insert into rwb_permissions (name,action) values('anon','query-opinion-data');
--
-- Root can do anything
--
insert into rwb_permissions (name,action) values('root','manage-users');
insert into rwb_permissions (name,action) values('root','invite-users');
insert into rwb_permissions (name,action) values('root','add-users');
insert into rwb_permissions (name,action) values('root','query-fec-data');
insert into rwb_permissions (name,action) values('root','query-cs-ind-data');
insert into rwb_permissions (name,action) values('root','query-opinion-data');
insert into rwb_permissions (name,action) values('root','give-cs-ind-data');
insert into rwb_permissions (name,action) values('root','give-opinion-data');
--
-- A user that's been added will be able to do all but manage-users
--

quit;
