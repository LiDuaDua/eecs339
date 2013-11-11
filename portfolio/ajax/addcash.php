<?php

if (!$loggedin) die();

if (isset($_GET['view'])) $view = sanitizeString($_GET['view']);
else                      $view = $portfolioId;

//Will take value to be subtracted and update the sql

echo "<div class='main'>";

//getting information from portfolio_portfolios
$result = queryMysql("SELECT * FROM portfolio_portfolios WHERE portfolioId='$portfolioId'");
$result = $result - $value;


for ($j = 0 ; $j < $num ; ++$j)
{
    $row           = mysql_fetch_row($result);
    $following[$j] = $row[0];
}


if (!$friends) echo "<br />You don't have any friends yet.<br /><br />";

echo "<a class='button' href='messages.php?view=$view'>" .
     "View $name2 messages</a>";
?>

</div><br /></body></html>
