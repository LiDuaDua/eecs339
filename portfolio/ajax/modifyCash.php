<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$status = $portfolio->modifyCash($_GET['portfolio_id'],$_GET['ammount']);

echo json_encode($status);
?>