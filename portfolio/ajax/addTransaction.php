<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$status = $portfolio->addTransaction($_GET['portfolio_id'],$_GET['shares'],$_GET['type'],$_GET['symbol'],$_GET['cost'],$_GET['total']);

echo json_encode($status);
?>