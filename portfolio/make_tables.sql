DROP TABLE portfolio_users;
DROP TABLE portfolio_portfolios

CREATE TABLE portfolio_users (
	username varchar(64) NOT NULL PRIMARY KEY,
	password varchar(32) NOT NULL
);

CREATE TABLE portfolio_portfolios (
	id INT NOT NULL PRIMARY KEY,
	username REFERENCES portfolio_users(username) ON DELETE CASCADE
);

INSERT INTO portfolio_users (username,password) VALUES ('root','b4b8daf4b8ea9d39568719e1e320076f');

CREATE TABLE portfolio_transactions (
	timestamp TIMESTAMP,
	portfolio REFERENCES portfolio_portfolios(id) ON DELETE CASCADE
);