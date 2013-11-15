<?php

//covariance takes the variance of two different dimensions

//get the average from the list of stocks and the standard deviation from the list of stocks
//close

//select csdailystocks union all mystocksdaily

$statement = oci_parse(self::$dbConn,"
	select symbol 
	FROM portfolio_stock_holdings 
	WHERE portfolio_stock_holdings = portfolio_portfolios.id");