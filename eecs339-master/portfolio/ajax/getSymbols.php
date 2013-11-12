<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$list = $portfolio->getSymbols();

echo json_encode($list);
?>