<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$covariance = $portfolio->getCovariance($_GET['symbols'],$_GET['from'],$_GET['to']);

$date = date_parse($_GET['from']);
$from = mktime(0,0,0,$date['month'],$date['day'],$date['year']);
$date = date_parse($_GET['to']);
$to = mktime(0,0,0,$date['month'],$date['day'],$date['year']);

$beta = $portfolio->variationBeta($_GET['symbols'],$from,$to);

echo json_encode(array("COVARIANCE"=>$covariance, "BETA"=>$beta));
?>