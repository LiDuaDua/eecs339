drop table portfolio_users;

create table portfolio_users (
	username varchar(64) not null primary key,
	password varchar(64) not null
);

create table portfolio_portfolio (
	id not null primary key,
	user references portfolio_users(username) ON DELETE CASCADE ON UPDATE CASCADE,

)

insert into portfolio_users (username,password) VALUES (root,rootroot);

quit;
