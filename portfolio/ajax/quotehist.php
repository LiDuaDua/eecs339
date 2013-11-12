<?php
header('Content-type: text/html; charset=utf-8');

$command = "~pdinda/339-f13/HANDOUT/portfolio/quotehist.pl --open --high --low --close ".$_GET['symbol'];

$res = array();
exec($command,$res);

$count = count($res);

for($i=0; $i<$count; $i++){
	$tmp = explode("\t",$res[$i]);

	$res[$i] = array(floatval($tmp[0])*1000,floatval($tmp[2]),floatval($tmp[3]),floatval($tmp[4]),floatval($tmp[5]));
}

echo json_encode($res);