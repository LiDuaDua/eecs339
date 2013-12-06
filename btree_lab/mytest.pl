$diskstem="mydisk";
$numblocks=1024;
$blocksize=360;
$heads=1;
$blockspertrack=1024;
$tracks=1;
$avgseek=10;
$trackseek=1;
$rotlat=10;
$cachesize=64;

$maxerr=10;

$ENV{PATH}.=":.";

system "deletedisk $diskstem";
system "makedisk $diskstem $numblocks $blocksize $heads $blockspertrack $tracks $avgseek $trackseek $rotlat";

system "sim $diskstem $cachesize < mytest.input";