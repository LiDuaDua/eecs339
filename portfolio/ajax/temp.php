<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$status = $portfolio->variationBeta("AAPL","108000","1157346000");

echo json_encode($status);
?>