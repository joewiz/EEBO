xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://exist-db.org/apps/appblueprint/config" at "config.xqm";

declare option output:method "json";
declare option output:media-type "application/json";

let $q := request:get-parameter("q", ())
let $type := request:get-parameter("type", "title")
let $items :=
    if ($q) then
        switch ($type)
            case "author" return
                distinct-values(ft:search($config:remote-data-root, "author:" || $q || "*", "author")//field)
            case "tei-text" return
                collection($config:remote-data-root)/util:index-keys-by-qname(xs:QName("tei:div"), $q, 
                    function($key, $count) {
                        $key
                    }, 30, "lucene-index")
            case "tei-head" return
                collection($config:remote-data-root)/util:index-keys-by-qname(xs:QName("tei:head"), $q, 
                    function($key, $count) {
                        $key
                    }, 30, "lucene-index")
            default return
                collection($config:remote-data-root)/util:index-keys-by-qname(xs:QName("tei:title"), $q, 
                    function($key, $count) {
                        $key
                    }, -1, "lucene-index")
    else
        ()
return
    array { $items }