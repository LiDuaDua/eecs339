<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$out = $portfolio->quote($_GET['symbol']);

echo json_encode($out);
?>