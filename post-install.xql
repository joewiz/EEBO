xquery version "3.0";

declare namespace repo="http://exist-db.org/xquery/repo";

import module namespace config="http://exist-db.org/apps/appblueprint/config" at "modules/config.xqm";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

local:mkcol("/db", "eebo"),
local:mkcol("/db/eebo", "download"),
local:mkcol("/db/eebo/download", "pdf"),
sm:chown(xs:anyURI("/db/eebo"), "eebo"),
sm:chgrp(xs:anyURI("/db/eebo"), "eebo"),
sm:chown(xs:anyURI("/db/eebo/download"), "eebo"),
sm:chgrp(xs:anyURI("/db/eebo/download"), "eebo"),
sm:chown(xs:anyURI("/db/eebo/download/pdf"), "eebo"),
sm:chgrp(xs:anyURI("/db/eebo/download/pdf"), "eebo"),
sm:chmod(xs:anyURI($target || "/modules/view.xql"), "rwsr-xr-x"),
sm:chmod(xs:anyURI($target || "/modules/pdf.xql"), "rwsr-xr-x"),
sm:chmod(xs:anyURI($target || "/modules/get-epub.xql"), "rwsr-xr-x"),

(: LaTeX requires dba permissions to execute shell process :)
sm:chmod(xs:anyURI($target || "/modules/latex.xql"), "rwsr-Sr-x"),
sm:chown(xs:anyURI($target || "/modules/latex.xql"), "tei"),
sm:chgrp(xs:anyURI($target || "/modules/latex.xql"), "dba")