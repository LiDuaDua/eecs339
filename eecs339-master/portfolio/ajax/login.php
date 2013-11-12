<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$status = $portfolio->login($_GET['username'],$_GET['password']);

echo json_encode($status);
?>