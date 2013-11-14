DROP TABLE portfolio_stock_holdings;
DROP TABLE portfolio_portfolios;
DROP TABLE portfolio_users;
DROP TABLE portfolio_stocks_daily;
DROP SEQUENCE portfolio_id_seq;
DROP SEQUENCE stock_holdings_id_seq;

CREATE TABLE portfolio_users (
	username VARCHAR(64) NOT NULL PRIMARY KEY,
	full_name VARCHAR(64) NOT NULL,
	password VARCHAR(32) NOT NULL
);

CREATE TABLE portfolio_portfolios (
	id INT NOT NULL PRIMARY KEY,
	name VARCHAR(64) NOT NULL,
	cash_account DECIMAL(19, 4) NOT NULL,
		CONSTRAINT positive_cash_account CHECK (cash_account>=0),
	username REFERENCES portfolio_users(username) NOT NULL
);

ALTER TABLE portfolio_portfolios
	ADD CONSTRAINT unique_portfolio_name_per_user UNIQUE (name,username);

-- Auto increment portfolio id. Solution from http://stackoverflow.com/questions/11296361/how-to-create-id-with-auto-increment-on-oracle
CREATE SEQUENCE portfolio_id_seq;

CREATE OR REPLACE TRIGGER portfolio_id_bir BEFORE INSERT ON portfolio_portfolios FOR EACH ROW

BEGIN
	SELECT portfolio_id_seq.NEXTVAL
	INTO :new.id
	FROM dual;
END;
/

CREATE TABLE portfolio_stock_holdings(
	id INT NOT NULL PRIMARY KEY,
	portfolio REFERENCES portfolio_portfolios(id) NOT NULL,
	symbol VARCHAR2(16) NOT NULL,
	shares INT NOT NULL,
		CONSTRAINT positive_shares CHECK (shares>=0)
);

ALTER TABLE portfolio_stock_holdings
	ADD CONSTRAINT unique_symbols_in_portfolio UNIQUE (portfolio, symbol);

-- auto increment stock holdings id
CREATE SEQUENCE stock_holdings_id_seq;

CREATE OR REPLACE TRIGGER stock_holdings_id_bir BEFORE INSERT ON portfolio_stock_holdings FOR EACH ROW

BEGIN
	SELECT stock_holdings_id_seq.NEXTVAL
	INTO :new.id
	FROM dual;
END;
/

--procedure to insert or update, from http://stackoverflow.com/questions/237327/oracle-how-to-upsert-update-or-insert-into-a-table
CREATE OR REPLACE PROCEDURE stock_transaction(p NUMBER, sym VARCHAR2, s NUMBER)
AS
BEGIN
	MERGE INTO portfolio_stock_holdings sh USING DUAL ON (portfolio=p AND symbol=sym)
		WHEN NOT MATCHED THEN INSERT (portfolio,symbol,shares) VALUES (p,sym,s)
			WHEN MATCHED THEN UPDATE SET sh.shares=sh.shares+s;
END stock_transaction;
/

CREATE TABLE portfolio_stocks_daily(
	timestamp NUMBER NOT NULL,
	symbol VARCHAR2(16) NOT NULL,
	open NUMBER NOT NULL,
	high NUMBER NOT NULL,
	low NUMBER NOT NULL,
	close NUMBER NOT NULL,
	volume NUMBER NOT NULL
);

ALTER TABLE portfolio_stocks_daily
	ADD CONSTRAINT unique_symbol_per_day UNIQUE (timestamp, symbol);


INSERT INTO portfolio_users (username,full_name,password) VALUES ('root','Root User','b4b8daf4b8ea9d39568719e1e320076f');
INSERT INTO portfolio_portfolios (name,cash_account,username) VALUES ('Default',2000.05,'root');
INSERT INTO portfolio_stock_holdings (portfolio,shares,symbol) VALUES (1,100,'AAPL');