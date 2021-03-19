#!/usr/bin/env php
<?php
/**
 * @author jwright@speareducation.com adapted from fili@speareducation.com deploy script
 */

function process() {
    // get secrets from json file
    $objSecret = json_decode(file_get_contents("php://stdin"));

    // must have a secret
    if (empty($objSecret->SecretString) && empty($objSecret->Parameter->Value)) {
        return;
    }

    // loop through aws secret key value pairs
    $arrSecretPairs = (array) json_decode(!empty($objSecret->SecretString) ? $objSecret->SecretString : $objSecret->Parameter->Value);

    // must be a list
    if (!is_array($arrSecretPairs) || !count($arrSecretPairs)) {
        return;
    }

    // add list of secrets to new secrets file
    $result = '';
    foreach ($arrSecretPairs as $strKey => $strValue) {
        // values with spaces must be in quotes
        if (preg_match('/[ ()$]/', $strValue) && !preg_match('/["\[\]]/', $strValue)) {
            $strValue = "\"$strValue\"";
        }
        // add key/value to secrets file
        $result .= "$strKey";
        $result .= ($strValue ? "=$strValue" : '');
        $result .= PHP_EOL;
    }

    return $result;
}

if (!$result = process()) {
    die(1);
}
echo $result;
die(0);

