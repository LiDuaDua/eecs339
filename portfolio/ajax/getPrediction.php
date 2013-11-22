<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$prediction = $portfolio->getPrediction($_GET['symbol'],$_GET['steps']);

echo json_encode($prediction);
?>