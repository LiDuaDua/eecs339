<?php
header('Content-type: text/html; charset=utf-8');
require_once "./Portfolio.php";
$portfolio = new Portfolio();
$status = $portfolio->signup($_GET['username'],$_GET['full_name'],$_GET['password']);

echo json_encode($status);
?>