<?php
header('Content-type: text/html; charset=utf-8');
require_once "./databaseOCI.php";

class Portfolio
{
	private static $dbConn = null;
	public function __construct ()
	{
		self::initializeConnection();
	}

	private static function initializeConnection ()
	{
		if (is_null(self::$dbConn)) {
			self::$dbConn = DatabaseOCI::getInstance();
		}
	}

	public static function login ($user,$pass)
	{
		self::initializeConnection();
		try {
			$statement = oci_parse(self::$dbConn,
				"SELECT *
				FROM portfolio_users
				WHERE username=:username AND password=:password");
			oci_bind_by_name($statement, ":username", $user);
			oci_bind_by_name($statement, ":password", $pass);
			oci_execute($statement);
			$status = oci_fetch_assoc($statement);
		} catch (Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		return $status;
	}

	public static function signup ($user,$name,$pass)
	{
		self::initializeConnection();
		try {
			$statement = oci_parse(self::$dbConn,
				"INSERT INTO portfolio_users (username, full_name, password)
				VALUES (:username, :full_name, :password)");
			oci_bind_by_name($statement, ":username", $user);
			oci_bind_by_name($statement, ":full_name", $name);
			oci_bind_by_name($statement, ":password", $pass);
			$r = oci_execute($statement);

			if($r){
				$status = array("status"=>1);
			}else{
				$err = oci_error($statement);
				$status = array("status"=>0,"message"=>$err['message']);
			}
		} catch (Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		return $status;
	}

	public static function addPortfolio ($name,$user)
	{
		self::initializeConnection();
		try {
			$statement = oci_parse(self::$dbConn,
				"INSERT INTO portfolio_portfolios (name,cash_account,username)
				VALUES (:portfolio_name, 0, :username)");
			oci_bind_by_name($statement, ":portfolio_name", $name);
			oci_bind_by_name($statement, ":username", $user);
			$r = oci_execute($statement);

			if($r){
				$status = array("status"=>1);
			}else{
				$err = oci_error($statement);
				$status = array("status"=>0,"message"=>$err['message']);
			}
		} catch (Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		return $status;
	}

	public static function getUserPortfolios ($user)
	{
		self::initializeConnection();
		$list = array();
		try {
			$statement = oci_parse(self::$dbConn,
				"SELECT *
				FROM portfolio_portfolios
				WHERE username=:username");
			oci_bind_by_name($statement, ":username", $user);
			oci_execute($statement);

			while($row = oci_fetch_assoc($statement)){
				$list[] = $row;
			}
		} catch (Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		return $list;
	}

	public static function addTransaction($portfolio_id, $shareChange, $symbol, $buyOrSell)
	{
		self::initializeConnection();
		$totalPrice = 0;
		try{

			$statement = oci_parse(self::$dbConn,
				"SELECT shares
				FROM portfolio_stock_holdings
				WHERE symbol=:symbol");

			oci_bind_by_name($statement, ":username", $symbol);
			oci_execute($statement);
			//$status = oci_fetch_assoc($statement);
			if ($buyOrSell == 1){
				//This is for buying stock
				$innerLoop = oci_parse(self::$dbConn,
					"UPDATE portfolio_stock_holdings
					SET shares=shares + :spareChange
					WHERE portfolio_id=:portfolio");
				oci_bind_by_name($innerLoop, ":portfolio", $portfolio_id);
				oci_execute($innerLoop);

				$shareAmount = oci_parse(self::$dbConn,
					"SELECT price
					FROM portfolio_stock_holdings
					WHERE symbol=:symbol");
				oci_bind_by_name($shareAmount, ":symbol", $symbol);
				oci_execute($shareAmount);

				$shareAmount = $shareAmount * $statement;
				$shareAmount = -1 * abs($shareAmount);

				modifyCash($portfolio_id,$shareAmount);

			}
			elseif ($buyOrSell == -1) {
				$innerLoop = oci_parse(self::$dbConn,
					"UPDATE portfolio_stock_holdings
					SET shares=shares - :spareChange
					WHERE portfolio_id=:portfolio");
				oci_bind_by_name($innerLoop, ":portfolio", $portfolio_id);
				oci_execute($innerLoop);

				$shareAmount = oci_parse(self::$dbConn,
					"SELECT price
					FROM portfolio_stock_holdings
					WHERE symbol=:symbol");
				oci_bind_by_name($shareAmount, ":symbol", $symbol);
				oci_execute($shareAmount);

				$shareAmount = $shareAmount * $statement;

				modifyCash($portfolio_id,$shareAmount);
			}
		} catch (Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

	}

	// public static function addStockHoldings ($)
	// {
	// 	self::initializeConnection();
	// 	try {
	// 		$statement = oci_parse(self::$dbConn,
	// 				"INSERT INTO portfolio_stock_holdings (id,portfolio,price,shares,symbol)
	// 				VALUES (:id,:portfolio,:price,:shares,:symbol)");
	// 		oci_bind_by_name($statement, ":id", $id);
	// 		oci_bind_by_name($statement, ":portfolio", $portfolio);
	// 		oci_bind_by_name($statement,":price",$price);
	// 		oci_bind_by_name($statement,":shares",$shares);
	// 		oci_bind_by_name($statement,":symbol",$symbol);
	// 		$r = oci_execute($statement);

	// 		if($r){
	// 				$status = array("status"=>1);
	// 		}else{
	// 				$err = oci_error($statement);
	// 				$status = array("status"=>0,"message"=>$err['message']);
	// 		}
	// 	} catch (Exception $e) {
	// 			echo "Error: " . $e['message'];
	// 			die();
	// 	}

	// 	return $status;
	// }

	public static function removeStockHoldings ()
	{
		self::initializeConnection();
		try{
			$statement = oci_parse(self::$dbConn,
				"DELETE
				FROM portfolio_stock_holdings
				WHERE id=:id");
			oci_bind_by_name($statement,":id",$id);
			$r = oci_execute($statement);

			if($r){
					$status = array("status"=>1);
			}else{
					$err = oci_error($statement);
					$status = array("status"=>0,"message"=>$err['message']);
			}
		} catch (Exception $e) {
				echo "Error: " . $e['message'];
				die();
		}

		return $status;
	}

	public static function getStockHoldings($portfolio)
	{
		self::initializeConnection();
		$list = array();
		try {
			$statement = oci_parse(self::$dbConn,
				"SELECT *
				FROM portfolio_stock_holdings
				WHERE portfolio=:portfolio");
			oci_bind_by_name($statement, ":portfolio", $portfolio);
			oci_execute($statement);
			while($row = oci_fetch_assoc($statement)){
				$list[]=$row;
			}
		} catch(Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		return $list;
	}

	public static function selectOrFetchStock ($symbol)
	{
		self::initializeConnection();
		try {
			$statement = oci_parse(self::$dbConn,
				"SELECT *
				FROM portfolio_stocks_daily
				WHERE symbol=:symbol
				ORDER BY date DESC");
			oci_bind_by_name($statement, ":symbol", $symbol);
			oci_execute($statement);
			$row = oci_fetch_assoc($statement);
		} catch(Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		if($row) {
			return $row;
		} else {
			$quote = self::quote($symbol);

			var_dump($quote);

			oci_close(self::$dbConn);
			self::initializeConnection();
			try {
				$statement = oci_parse(self::$dbConn,
					"INSERT INTO portfolio_stocks_daily (date,symbol,open,high,low,close,volume)
					VALUES (:date,:symbol,:open,:high,:low,:close,:volume)");
				oci_bind_by_name($statement, ":date", $quote[$symbol]['date']);
				oci_bind_by_name($statement, ":symbol", $symbol);
				oci_bind_by_name($statement, ":open", $quote[$symbol]['open']);
				oci_bind_by_name($statement, ":high", $quote[$symbol]['high']);
				oci_bind_by_name($statement, ":low", $quote[$symbol]['low']);
				oci_bind_by_name($statement, ":close", $quote[$symbol]['close']);
				oci_bind_by_name($statement, ":volume", $quote[$symbol]['volume']);
				$r = oci_execute($statement);

				if($r){
					return $quote;
				}else{
					$err = oci_error($statement);
					return $err['message'];
				}
			} catch(Exception $e) {
				echo "Error: " . $e['message'];
				die();
			}
		}
	}

	public static function modifyCash ($portfolio,$ammount)
	{
		self::initializeConnection();
		try {
			$statement = oci_parse(self::$dbConn,
				"UPDATE portfolio_portfolios
				SET cash_account=cash_account + :ammount
				WHERE portfolio_id=:portfolio");
			oci_bind_by_name($statement, ":ammount", $ammount);
			oci_bind_by_name($statement, ":portfolio", $portfolio);
			$r = oci_execute($statement);

			if($r){
				$status = array("status"=>1);
			}else{
				$err = oci_error($statement);
				$status = array("status"=>0,"message"=>$err['message']);
			}
		} catch (Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		return $status;
	}

	public static function getSymbols ()
	{
		self::initializeConnection();
		$list = array();
		try {
			$statement = oci_parse(self::$dbConn,
				"SELECT DISTINCT symbol FROM cs339.StocksSymbols");
			oci_execute($statement);

			while($row = oci_fetch_array($statement, OCI_NUM)){
				$list[] = $row[0];
			}
		} catch (Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		return $list;
	}

	public static function quote ($symbol)
	{
		$command = "~pdinda/339-f13/HANDOUT/portfolio/quote.pl ".$symbol;

		$res = array();
		$out = array();
		exec($command,$res);

		$count = count($res);
		for($i=0; $i<$count; $i+=10){
			$name = $res[$i];

			$tmp = array();

			for($j=2; $j<9; $j++){
				$tmp2 = explode("\t",$res[$i+$j]);

				$tmp[$tmp2[0]] = $tmp2[1];
			}

			$out[$name] = $tmp;
		}

		return $out;
	}

	public static function quoteHistory ($symbol)
	{
		$command = "~pdinda/339-f13/HANDOUT/portfolio/quotehist.pl --open --high --low --close ".$symbol;

		$res = array();
		exec($command,$res);

		$count = count($res);

		for($i=0; $i<$count; $i++){
			$tmp = explode("\t",$res[$i]);

			$res[$i] = array(floatval($tmp[0])*1000,floatval($tmp[2]),floatval($tmp[3]),floatval($tmp[4]),floatval($tmp[5]));
		}

		return $res;
	}
}
