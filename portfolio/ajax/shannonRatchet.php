<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();

$out = array();
foreach($_GET['symbols'] as $symbol){
	$res = $portfolio->shannonRatchet($symbol,$_GET['cash_account']);
	$out[] = array("SYMBOL"=>$symbol,"TRADER"=>implode("\n",$res));
}

echo json_encode($out);
?>