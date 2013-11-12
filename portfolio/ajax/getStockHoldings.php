<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$status = $portfolio->getStockHoldings($_GET['portfolio']);

echo json_encode($status);
?>
