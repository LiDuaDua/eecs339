<?php
header('Content-type: text/html; charset=utf-8');
require_once "./databaseOCI.php";

class Portfolio
{
	private static $dbConn = null;
	public function __construct ()
	{
		self::initializeConnection();
		date_default_timezone_set('America/Chicago');
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

	public static function addTransaction($portfolio, $shares, $type, $symbol, $cost, $total)
	{
		self::initializeConnection();
		try {
			if ($type == "buy")
			{
				$statement = oci_parse(self::$dbConn,
					"call stock_transaction(:portfolio, :symbol, :shares_count)");
				oci_bind_by_name($statement, ":portfolio", $portfolio);
				oci_bind_by_name($statement, ":symbol", $symbol);
				oci_bind_by_name($statement, ":shares_count", $shares);
				oci_execute($statement, OCI_NO_AUTO_COMMIT);

				$status = self::modifyCash($portfolio,(floatval($total) * -1));
			}
			else
			{
				$statement = oci_parse(self::$dbConn,
					"SELECT shares
					FROM portfolio_stock_holdings
					WHERE portfolio=:portfolio AND symbol=:symbol");
				oci_bind_by_name($statement, ":portfolio", $portfolio);
				oci_bind_by_name($statement,":symbol",$symbol);
				oci_execute($statement);
				$row = oci_fetch_assoc($statement);

				#sell some shares, keep row
				if($row AND floatval($row['SHARES']) > $shares){
					$statement = oci_parse(self::$dbConn,
						"UPDATE portfolio_stock_holdings SET shares=shares - :shares
						WHERE portfolio=:portfolio AND symbol=:symbol");
					oci_bind_by_name($statement, ":portfolio", $portfolio);
					oci_bind_by_name($statement,":symbol",$symbol);
					oci_bind_by_name($statement,"shares",$shares);
					oci_execute($statement, OCI_NO_AUTO_COMMIT);

					$status = self::modifyCash($portfolio,floatval($total));

				#sell all shares, delete row
				}else if ($row AND floatval($row['SHARES']) == $shares){
					$statement = oci_parse(self::$dbConn,
						"DELETE FROM portfolio_stock_holdings
						WHERE portfolio=:portfolio AND symbol=:symbol");
					oci_bind_by_name($statement, ":portfolio", $portfolio);
					oci_bind_by_name($statement,":symbol",$symbol);
					oci_execute($statement, OCI_NO_AUTO_COMMIT);

					$status = self::modifyCash($portfolio,floatval($total));
				}else{
					$status = array("status"=>0,"message"=>"You don't have that many shares to sell!");
				}

			}
		} catch (Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		return $status;
	}

	public static function modifyCash ($portfolio,$ammount)
	{
		self::initializeConnection();
		try {
			$statement = oci_parse(self::$dbConn,
				"UPDATE portfolio_portfolios
				SET cash_account=cash_account + :ammount
				WHERE id=:portfolio");
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

	public static function getStockHoldings ($portfolio)
	{
		self::initializeConnection();
		$list = array();
		$symbols = array();
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

		$len = count($list);
		for($i=0; $i<$len; $i++){
			$quote = self::selectOrFetchStock($list[$i]['SYMBOL']);

			$list[$i] = array_merge($list[$i],$quote);
		}

		return $list;
	}

	public static function selectOrFetchStock ($symbol)
	{
		self::initializeConnection();

		$timestamp = date_parse(date('m/d/y'));
		$timestamp = mktime(0,0,0,$date['month'],$date['day'],$date['year']);

		try {
			$statement = oci_parse(self::$dbConn,
				"SELECT *
				FROM portfolio_stocks_daily
				WHERE symbol=:symbol
				AND timestamp=:timestamp");
			oci_bind_by_name($statement, ":symbol", $symbol);
			oci_bind_by_name($statement, ":timestamp", $timestamp);
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

			# check for quote errors
			if(!$quote['OPEN']){
				$quote['OPEN'] = 0;
			}
			if(!$quote['HIGH']){
				$quote['HIGH'] = 0;
			}
			if(!$quote['LOW']){
				$quote['LOW'] = 0;
			}
			if(!$quote['CLOSE']){
				$quote['CLOSE'] = 0;
			}
			if(!$quote['VOLUME']){
				$quote['VOLUME'] = 0;
			}

			// oci_close(self::$dbConn);
			self::initializeConnection();
			try {
				$statement = oci_parse(self::$dbConn,
					"INSERT INTO portfolio_stocks_daily (timestamp,symbol,open,high,low,close,volume)
					VALUES (:timestamp,:symbol,:open,:high,:low,:close,:volume)");
				oci_bind_by_name($statement, ":timestamp", $timestamp);
				oci_bind_by_name($statement, ":symbol", $symbol);
				oci_bind_by_name($statement, ":open", $quote['OPEN']);
				oci_bind_by_name($statement, ":high", $quote['HIGH']);
				oci_bind_by_name($statement, ":low", $quote['LOW']);
				oci_bind_by_name($statement, ":close", $quote['CLOSE']);
				oci_bind_by_name($statement, ":volume", $quote['VOLUME']);
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

		for($i=2; $i<9; $i++){
			$tmp = explode("\t",$res[$i]);
			$out[strtoupper($tmp[0])] = $tmp[1];
		}

		return $out;
	}

	public static function hasFetchedQuoteHistory ($symbol)
	{
		self::initializeConnection();
		try {
			$statement = oci_parse(self::$dbConn,
				"SELECT symbol
				FROM portfolio_stocks_fetched
				WHERE symbol=:symbol");
			oci_bind_by_name($statement, ":symbol", $symbol);
			oci_execute($statement);
			$hasFetched = oci_fetch_assoc($statement);
		} catch (Exception $e) {
			echo "Error: " . $e['message'];
			die();
		}

		return $hasFetched;
	}

	public static function quoteHistory ($symbol)
	{
		self::initializeConnection();

		$hasFetched = self::hasFetchedQuoteHistory($symbol);

		// if($hasFetched){
		// 	echo "fetched<br/>";
		// }else{
		// 	echo "didnt fetch<br/>";
		// }

		if($hasFetched){
			$quotehist = array();
			try {
				$statement = oci_parse(self::$dbConn,
					"SELECT *
					FROM stocksdaily
					WHERE symbol=:symbol
					ORDER BY timestamp");
				oci_bind_by_name($statement, ":symbol", $symbol);
				oci_execute($statement);

				while($row = oci_fetch_assoc($statement)){
					$quotehist[] = array(floatval($row['TIMESTAMP'])*1000,floatval($row['OPEN']),floatval($row['HIGH']),floatval($row['LOW']),floatval($row['CLOSE']),floatval($row['VOLUME']));
				}
			} catch (Exception $e) {
				echo "Error: " . $e['message'];
				die();
			}

			return $quotehist;
		}else{
			$command = "~pdinda/339-f13/HANDOUT/portfolio/quotehist.pl --from=\"01/01/2006\" --open --high --low --close --vol ".$symbol;

			$res = array();
			exec($command,$res);

			$count = count($res);

			$statement = oci_parse(self::$dbConn,
				"INSERT INTO portfolio_stocks_daily
				(timestamp,symbol,open,high,low,close,volume)
				VALUES (:timestamp, :symbol, :open, :high, :low, :close, :volume)");

			for($i=0; $i<$count; $i++){
				$tmp = explode("\t",$res[$i]);

				$res[$i] = array(floatval($tmp[0])*1000,floatval($tmp[2]),floatval($tmp[3]),floatval($tmp[4]),floatval($tmp[5]));
				try {
					oci_bind_by_name($statement, ":timestamp", $tmp[0]);
					oci_bind_by_name($statement, ":symbol", $symbol);
					oci_bind_by_name($statement, ":open", $tmp[2]);
					oci_bind_by_name($statement, ":high", $tmp[3]);
					oci_bind_by_name($statement, ":low", $tmp[4]);
					oci_bind_by_name($statement, ":close", $tmp[5]);
					oci_bind_by_name($statement, ":volume", $tmp[6]);
					oci_execute($statement, OCI_NO_AUTO_COMMIT);
				} catch (Exception $e) {
					echo "Error: " . $e['message'];
					die();
				}
			}

			$r = oci_commit(self::$dbConn);

			// echo "this means the inserts succeeded: ".$r." and this is how many rows: ".$count;

			if($r){
				try {
					$statement = oci_parse(self::$dbConn,
						"INSERT INTO portfolio_stocks_fetched VALUES (:symbol)");
					oci_bind_by_name($statement, ":symbol", $symbol);
					oci_execute($statement);
				} catch (Exception $e) {
					echo "Error: " . $e['message'];
					die();
				}
			}

			$historic = array();
			try {
				$statement = oci_parse(self::$dbConn,
					"SELECT *
					FROM cs339.StocksDaily
					WHERE symbol=:symbol
					ORDER BY timestamp");
				oci_bind_by_name($statement, ":symbol", $symbol);
				oci_execute($statement);

				while($row = oci_fetch_assoc($statement)){
					$historic[] = array(floatval($row['TIMESTAMP'])*1000,floatval($row['OPEN']),floatval($row['HIGH']),floatval($row['LOW']),floatval($row['CLOSE']),floatval($row['VOLUME']));
				}
			} catch (Exception $e) {
				echo "Error: " . $e['message'];
				die();
			}

			return array_merge($historic,$res);
		}
	}

	public static function getCovariance ($symbols, $from, $to)
	{
		DatabaseOCI::setEnv();

		$command = "/home/bsr618/www/portfolio/perlscripts/get_covar.pl --from=\"$from\" --to=\"$to\" ".implode(" ",$symbols);

		$res = array();
		exec($command,$res);
		return $res;
	}

	public static function variationBeta($symbols, $start, $end)
	{
		self::initializeConnection();

		foreach($symbols as $symbol){
			$hasFetched = self::hasFetchedQuoteHistory($symbol);

			if(!$hasFetched){
				self::quoteHistory($symbol);
			}

			$statement = oci_parse(self::$dbConn,
	 			"SELECT stddev(close) AS stddev, count(close) AS count, avg(close) AS avg
	 			FROM StocksDaily
	 			WHERE symbol = :symbol and timestamp >= :starttime and timestamp <= :endtime");
	 		oci_bind_by_name($statement,":symbol",$symbol);
	 		oci_bind_by_name($statement,":starttime", $start);
	 		oci_bind_by_name($statement,":endtime",$end);
	 		oci_execute($statement);
	 		$individual = oci_fetch_assoc($statement);

			$quote = self::selectOrFetchStock($symbol);

			$statement = oci_parse(self::$dbConn,
				"SELECT stddev(close) AS stddev, count(close) AS count, avg(close) AS avg
				FROM StocksDaily
				WHERE timestamp >= :starttime and timestamp <= :endtime");
	 		oci_bind_by_name($statement,":symbol",$symbol);
	 		oci_bind_by_name($statement,":starttime", $start);
	 		oci_bind_by_name($statement,":endtime",$end);
			oci_execute($statement);
			$overall = oci_fetch_assoc($statement);

			$variation = ($individual['STDDEV']/$individual['AVG']);
			$covariance = ((($quote['CLOSE'] - $overall['AVG']) * ($quote['CLOSE'] - $overall['STDDEV']))/$overall['COUNT']);
			$beta = $covariance/$individual['STDDEV'];
			$list[] = array("SYMBOL"=>$symbol, "VARIATION"=>$variation, "BETA"=>$beta);

		}
		return $list;
	}

	public static function getPrediction ($symbol,$steps)
	{
		$hasFetched = self::hasFetchedQuoteHistory($symbol);

		if(!$hasFetched){
			self::quoteHistory($symbol);
		}

		$command = "/home/bsr618/www/portfolio/perlscripts/time_series_symbol_project.pl ".$symbol." ".$steps." AWAIT 200 AR 16";
		$res = array();

		DatabaseOCI::setEnv();
		exec($command,$res);

		$out = array();
		for($i=0; $i<$steps; $i++){
			$tmp = explode("\t",$res[count($res)-$steps+$i]);

			$out[] = $tmp[2];
		}

		return $out;
	}

	public static function shannonRatchet ($symbol, $account)
	{
		DatabaseOCI::setEnv();

		$quote = self::selectOrFetchStock($symbol);
		$cost = $quote['CLOSE'];

		$command = "/home/bsr618/www/portfolio/perlscripts/shannon_ratchet.pl ".$symbol." ".$account." ".$cost;
		$res = array();

		exec($command,$res);

		return $res;
	}
}
