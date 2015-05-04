xquery version "3.0";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";
import module namespace app="http://exist-db.org/apps/appblueprint/templates" at "app.xql";
import module namespace config="http://exist-db.org/apps/appblueprint/config" at "config.xqm";

declare option output:method "json";
declare option output:media-type "application/json";

let $doc := request:get-parameter("doc", ())
let $id := replace($doc, "^(.*)\.\w+$", "$1")
let $xml := app:load(collection($config:remote-data-root), $id)
let $parent := $xml/ancestor::tei:div[not(*[1] instance of element(tei:div))][1]
let $prevDiv := $xml/preceding::tei:div[1]
let $prev := app:get-previous(if ($parent and $xml/.. >> $prevDiv) then $xml/.. else $prevDiv)
let $next := app:get-next($xml)
let $html := app:process-content(app:get-content($xml))
let $docName := replace($id, "^(.*)_.*$", "$1")
let $log := console:log("Loading id " || $id)
return
    map {
        "doc": $docName,
        "next": 
            if ($next) then 
                $docName || "_" || util:node-id($next) || ".html"
            else (),
        "previous": 
            if ($prev) then 
                $docName || "_" || util:node-id($prev) || ".html"
            else (),
        "content": $html
    }