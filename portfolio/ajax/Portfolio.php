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
}