<?php
header('Content-type: text/html; charset=utf-8');
include_once "./vars.php";

class DatabaseOCI
{
    private static $_instance = null;

    static function getInstance ()
    {
        PutEnv("ORACLE_SID=CS339");
        PutEnv("ORACLE_HOME=/raid/oracle11g/app/oracle/product/11.2.0.1.0/db_1");
        PutEnv("ORACLE_BASE=/raid/oracle11g/app/oracle/product/11.2.0.1.0");

        if (!self::$_instance) {
            // $iters = 0;

            // while (!self::$_instance && $iters < 20) {
                self::$_instance = oci_connect($GLOBALS['USERNAME'], $GLOBALS['PASSWORD']);
            //     echo "waiting";
            //     usleep(5000);
            //     $iters++;
            // }

            if (!self::$_instance) {
                $e = oci_error();

                echo "Connection to Oracle Failed for some reason ".$e['message'];
                die();
            }
        }

        return self::$_instance;
    }

    static function setEnv ()
    {
        PutEnv("PORTF_DBMS=oracle");
        PutEnv("PORTF_DB=".$GLOBALS['USERNAME']);
        PutEnv("PORTF_DBUSER=".$GLOBALS['USERNAME']);
        PutEnv("PORTF_DBPASS=".$GLOBALS['PASSWORD']);

        PutEnv('PATH=$PATH:/home/bsr618/www/portfolio/perlscripts');
        PutEnv('PERL5LIB=$PERL5LIB:/home/bsr618/www/portfolio/perlscripts');

        // PutEnv('PATH=$PATH:/home/pdinda/339-f13/HANDOUT/portfolio');
        // PutEnv('PERL5LIB=$PERL5LIB:/home/pdinda/339-f13/HANDOUT/portfolio');
    }
}