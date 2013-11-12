DROP TABLE portfolio_stock_holdings;
DROP TABLE portfolio_portfolios;
DROP TABLE portfolio_users;
DROP TABLE portfolio_stocks_historical;
DROP TABLE portfolio_stocks_daily;
DROP SEQUENCE portfolio_id_seq;
DROP SEQUENCE stock_holdings_id_seq;

CREATE TABLE portfolio_users (
	username VARCHAR(64) NOT NULL PRIMARY KEY,
	full_name VARCHAR(64) NOT NULL,
	password VARCHAR(32) NOT NULL
);

CREATE TABLE portfolio_portfolios (
	portfolio_id INT NOT NULL PRIMARY KEY,
	name VARCHAR(64) NOT NULL,
	cash_account DECIMAL(19, 4),
	username REFERENCES portfolio_users(username)
);

-- Auto increment portfolio id. Solution from http://stackoverflow.com/questions/11296361/how-to-create-id-with-auto-increment-on-oracle
CREATE SEQUENCE portfolio_id_seq;

CREATE OR REPLACE TRIGGER portfolio_id_bir BEFORE INSERT ON portfolio_portfolios FOR EACH ROW

BEGIN
	SELECT portfolio_id_seq.NEXTVAL
	INTO :new.portfolio_id
	FROM dual;
END;
/

CREATE TABLE portfolio_stock_holdings(
	id INT NOT NULL PRIMARY KEY,
	portfolio REFERENCES portfolio_portfolios(portfolio_id),
	price DECIMAL(19, 4),
	shares INT,
	symbol REFERENCES cs339.StocksSymbols(symbol)
);

-- auto increment stock holdings id
CREATE SEQUENCE stock_holdings_id_seq;

CREATE OR REPLACE TRIGGER stock_holdings_id_bir BEFORE INSERT ON portfolio_stock_holdings FOR EACH ROW

BEGIN
	SELECT stock_holdings_id_seq.NEXTVAL
	INTO :new.id
	FROM dual;
END;
/

CREATE TABLE portfolio_stocks_historical(
	symbol REFERENCES cs339.StocksSymbols(symbol)
);

CREATE TABLE portfolio_stocks_daily(
	timestamp TIMESTAMP,
	symbol REFERENCES cs339.StocksSymbols(symbol),
	open DECIMAL(19, 4),
	high DECIMAL(19, 4),
	low DECIMAL(19, 4),
	close DECIMAL(19, 4),
	volume INT
);

INSERT INTO portfolio_users (username,full_name,password) VALUES ('root','Root User','b4b8daf4b8ea9d39568719e1e320076f');
INSERT INTO portfolio_portfolios (name,cash_account,username) VALUES ('Default',2000.05,'root');
INSERT INTO portfolio_stock_holdings (portfolio,price,shares,symbol) VALUES (1,10.01,100,'AAPL');