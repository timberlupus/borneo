$boardName = $args[0]
$cmd = "idf.py -DBORNEO_BOARD='$boardName' reconfigure"
invoke-expression $cmd
