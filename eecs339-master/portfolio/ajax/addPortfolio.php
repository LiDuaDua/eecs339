<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$status = $portfolio->addPortfolio($_GET['name'], $_GET['username']);

echo json_encode($status);
?>