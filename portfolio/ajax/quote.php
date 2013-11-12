<?php
header('Content-type: text/html; charset=utf-8');

$command = "~pdinda/339-f13/HANDOUT/portfolio/quote.pl ".implode(" ",$_GET['symbol']);

$res = array();
$out = array();
exec($command,$res);

$count = count($res);
for($i=0; $i<$count; $i+=10){
	$name = $res[$i];

	$tmp = array();

	for($j=2; $j<9; $j++){
		$tmp2 = explode("\t",$res[$i+$j]);

		$tmp[$tmp2[0]] = $tmp2[1];
	}

	$out[$name] = $tmp;
}

echo json_encode($out);
?>