<?php

$value = $_POST['value'];

//Will take value to be subtracted and update the sql
//How do you get the portfolio ID?

//getting information from portfolio_portfolios
$result = queryMysql("SELECT * FROM portfolio_portfolios WHERE portfolioId='$portfolioId'");
$result = $result - $value;

//mysql_query(UPDATE portfolio_portfolios SET cash_account = $result WHERE portfolioId = $portfolioId);
$sql = "UPDATE portfolio_portfolios SET cash_account='".$result."' WHERE portfolioId='$portfolioId");
$query = mysql_query($sql);


?>
