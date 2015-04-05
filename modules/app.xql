xquery version "3.0";

module namespace app="http://exist-db.org/apps/appblueprint/templates";

import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://exist-db.org/apps/appblueprint/config" at "config.xqm";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace pmu="http://www.tei-c.org/tei-simple/xquery/util" at "/db/apps/tei-simple/content/util.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace h="http://www.w3.org/1999/xhtml";
declare namespace functx="http://www.functx.com";

declare variable $app:EXIDE := 
    let $pkg := collection(repo:get-root())//expath:package[@name = "http://exist-db.org/apps/eXide"]
    let $appLink :=
        if ($pkg) then
            substring-after(util:collection-name($pkg), repo:get-root())
        else
            ()
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $appLink, "index.html"), "/")
    return
        replace($path, "/+", "/");
    
(:~
 : Process navbar links to cope with browsing.
 :)
declare
    %templates:wrap
function app:nav-set-active($node as node(), $model as map(*)) {
    let $path := request:get-attribute("$exist:path")
    let $res := request:get-attribute("$exist:resource")
    for $li in $node/h:li
    let $link := $li/h:a
    let $href := $link/@href
    return
        element { node-name($li) } {
            if ($href = $res or ($href = "works/" and starts-with($path, "/works/"))) then
                attribute class { "active" }
            else
                (),
            <h:a>
            {
                $link/@* except $link/@href,
                attribute href {
                    if ($link/@href = "works/" and starts-with($path, "/works/")) then
                        "."
                    else if (starts-with($path, ("/works/", "/docs/"))) then
                        "../" || $link/@href
                    else
                        $link/@href
                },
                $link/node()
            }
            </h:a>,
            $li/h:ul
        }
};

declare function functx:contains-any-of
  ( $arg as xs:string? ,
    $searchStrings as xs:string* )  as xs:boolean {

   some $searchString in $searchStrings
   satisfies contains($arg,$searchString)
 } ;

(:modified by applying functx:escape-for-regex() :)
declare function functx:number-of-matches 
  ( $arg as xs:string? ,
    $pattern as xs:string )  as xs:integer {
       
   count(tokenize(functx:escape-for-regex(functx:escape-for-regex($arg)),functx:escape-for-regex($pattern))) - 1
 } ;

declare function functx:escape-for-regex
  ( $arg as xs:string? )  as xs:string {

   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;

(:~
 : List SARIT works
 :)
declare 
    %templates:wrap
function app:list-works($node as node(), $model as map(*), $filter as xs:string?, $browse as xs:string?) {
    let $cached := session:get-attribute("sarit.works")
    let $filtered :=
        if ($filter) then
            let $ordered :=
                for $item in
                    ft:search($config:remote-data-root, $browse || ":" || $filter, ("author", "title"))/search
                let $author := $item/field[@name = "author"]
                order by $author[1], $author[2], $author[3]
                return
                    $item
            for $doc in $ordered
            return
                doc($doc/@uri)/tei:TEI
        else if ($cached) then
            $cached
        else
            collection($config:remote-data-root)/tei:TEI
    return (
        session:set-attribute("sarit.works", $filtered),
        session:set-attribute("browse", $browse),
        session:set-attribute("filter", $filter),
        map {
            "all" : $filtered
        }
    )
};

declare
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:browse($node as node(), $model as map(*), $start as xs:int, $per-page as xs:int) {
    subsequence($model?all, $start, $per-page) !
        element { node-name($node) } {
            $node/@*,
            templates:process($node/node(), map:new(($model, map { "work": . })))
        }
};

declare
    %templates:wrap
function app:work($node as node(), $model as map(*), $id as xs:string) {
(:    console:log("sarit", "id: " || $id),:)
    let $work := app:load(collection($config:remote-data-root), $id)
    return
        map { "work" := $work[1] }
};

declare %private function app:load($context as node()*, $id as xs:string) {
    (:$context is tei:TEI when loading a document from the TOC and when loading a hit from tei:text; when loading a hit from tei:teiHeader, it is tei:teiHeader.:)
    let $work := if ($context instance of element(tei:teiHeader)) then $context else $context//id($id)
	return
        if ($work) then
            $work
        else 
            if (matches($id, "_[p\d\.]+$")) then
            let $analyzed := analyze-string($id, "^(.*)_([^_]+)$")
            let $docName := $analyzed//fn:group[@nr = 1]/text()
            let $doc := doc($config:remote-data-root || "/" || $docName)
            let $nodeId := $analyzed//fn:group[@nr = 2]/string()
(:            let $log := console:log("sarit", "loading node '" || $nodeId || "' from document " || $config:remote-data-root || "/" || $docName):)
            return
                if (starts-with($nodeId, "p")) then
                    let $page := number(substring-after($nodeId, "p"))
                    return
                        ($doc//tei:pb)[$page]
                else
                    util:node-by-id($doc, $nodeId)
        else (
            console:log("sarit", "Loading " || $config:remote-data-root || "/" || $id),
            doc($config:remote-data-root || "/" || $id)/tei:TEI
        )
};

declare function app:header($node as node(), $model as map(*)) {
    pmu:process($config:odd-root || "/teisimple.odd", $model("work")/tei:teiHeader, $config:odd-root, "web", "../resources/odd")
};

(:You can always see three levels: the current level, is siblings, its parent and its children. 
This means that you can always go up and down (and sideways).
One could leave out or elide the siblings. :)
declare 
    %templates:default("full", "false")
function app:outline($node as node(), $model as map(*), $full as xs:boolean) {
    let $position := $model("work")
    let $root := if ($full) then $position/ancestor::tei:TEI else $position
    let $long := $node/@data-template-details/string()
    let $work := $root/ancestor-or-self::tei:TEI
    return
        if (
            exists($work/tei:text/tei:front/tei:titlePage) or 
            exists($work/tei:text/tei:front/tei:div) or 
            exists($work/tei:text/tei:body/tei:div) or 
            exists($work/tei:text/tei:back/tei:div)
           ) 
        then (
            <ul class="contents">{
                typeswitch($root)
                    case element(tei:div) return
                        (:if it is not the whole work:)
                        app:generate-toc-from-div($root, $long, $position) 
                    case element(tei:titlePage) return
                        (:if it is not the whole work:)
                        app:generate-toc-from-div($root, $long, $position)
                    default return
                        (:if it is the whole work:)
                        (
                        if ($work/tei:text/tei:front/tei:titlePage, $work/tei:text/tei:front/tei:div)
                        then
                            <div class="text-front">
                            <h6>Front Matter</h6>
                            {for $div in 
                                (
                                $work/tei:text/tei:front/tei:titlePage, 
                                $work/tei:text/tei:front/tei:div 
                                )
                            return app:toc-div($div, $long, $position, 'list-item')
                            }</div>
                            else ()
                        ,
                        <div class="text-body">
                        <h6>{if ($work/tei:text/tei:front/tei:titlePage, $work/tei:text/tei:front/tei:div, $work/tei:text/tei:back/tei:div) then 'Text' else ''}</h6>
                        {for $div in 
                            (
                            $work/tei:text/tei:body/tei:div 
                            )
                        return app:toc-div($div, $long, $position, 'list-item')
                        }</div>
                        ,
                        if ($work/tei:text/tei:back/tei:div)
                        then
                            <h6 class="text-back">
                            <h6>Back Matter</h6>
                            {for $div in 
                                (
                                $work/tei:text/tei:back/tei:div 
                                )
                            return app:toc-div($div, $long, $position, 'list-item')
                            }</h6>
                        else ()
                        )
            }</ul>
        ) else ()
};

declare function app:generate-toc-from-div($root, $long, $position) {
	(:if it has divs below itself:)
    <li>{
    if ($root/tei:div) then
        (
        if ($root/parent::tei:div) 
        (:show the parent:)
        then app:toc-div($root/parent::tei:div, $long, $position, 'no-list-item') 
        (:NB: this creates an empty <li> if there is no div parent:)
        (:show nothing:)
        else ()
        ,
        for $div in $root/preceding-sibling::tei:div
        return app:toc-div($div, $long, $position, 'list-item')
        ,
        app:toc-div($root, $long, $position, 'list-item')
        ,
        <ul>
            {
            for $div in $root/tei:div
            return app:toc-div($div, $long, $position, 'list-item')
            }
        </ul>
        ,
        for $div in $root/following-sibling::tei:div
        return app:toc-div($div, $long, $position, 'list-item')
        )
    else
    (
        (:if it is a leaf:)
        (:show its parent:)
        app:toc-div($root/parent::tei:div, $long, $position, 'no-list-item')
        ,
        (:show its preceding siblings:)
        <ul>
            {
            for $div in $root/preceding-sibling::tei:div
            return app:toc-div($div, $long, $position, 'list-item')
            ,
            (:show itself:)
            (:NB: should not have link:)
            app:toc-div($root, $long, $position, 'list-item')
            ,
            (:show its following siblings:)
            for $div in $root/following-sibling::tei:div
            return app:toc-div($div, $long, $position, 'list-item')
            }
        </ul>
        )
       }</li>
};

(:based on Joe Wicentowski, http://digital.humanities.ox.ac.uk/dhoxss/2011/presentations/Wicentowski-XMLDatabases-materials.zip:)
declare function app:generate-toc-from-divs($node, $current as element()?, $long as xs:string?) {
    if ($node/tei:div) 
    then
        <ul style="display: none">{
            for $div in $node/tei:div
            return app:toc-div($div, $long, $current, 'list-item')
        }</ul>
    else ()
};

(:based on Joe Wicentowski, http://digital.humanities.ox.ac.uk/dhoxss/2011/presentations/Wicentowski-XMLDatabases-materials.zip:)
declare %private function app:derive-title($div) {
    typeswitch ($div)
        case element(tei:div) return
            let $n := $div/@n/string()
            let $title := 
                (:if the div has a header:)
                if ($div/tei:head) 
                then
                    concat(
                        if ($n) then concat($n, ': ') else ''
                        ,
                        string-join(
                            for $node in $div/tei:head/node() 
                            return data($node)
                        , ' ')
                    )
                else
                    let $type := $div/@type
                    let $data := app:generate-title($div//text(), 0)
                    return
                        (:otherwise, take part of the text itself:)
                        if (string-length($data) gt 0) 
                        then
                            concat(
                                if ($type) 
                                then concat('[', $type/string(), '] ') 
                                else ''
                            , substring($data, 1, 25), '…') 
                        else concat('[', $type/string(), ']')
            return $title
        case element(tei:titlePage) return
            pmu:process($config:odd-root || "/teisimple.odd", $div, $config:odd-root, "web", "../resources/odd")
        default return
            ()
};

declare %private function app:generate-title($nodes as text()*, $length as xs:int) {
    if ($nodes) then
        let $text := head($nodes)
        return
            if ($length + string-length($text) > 25) then
                (substring($text, 1, 25 - $length) || "…")
            else
                ($text || app:generate-title(tail($nodes), $length + string-length($text)))
    else
        ()
};

(:based on Joe Wicentowski, http://digital.humanities.ox.ac.uk/dhoxss/2011/presentations/Wicentowski-XMLDatabases-materials.zip:)
declare function app:toc-div($div, $long as xs:string?, $current as element()?, $list-item as xs:string?) {
    let $div-id := $div/@xml:id/string()
    let $div-id := 
        if ($div-id) then $div-id else util:document-name($div) || "_" || util:node-id($div)
    return
        if ($list-item eq 'list-item')
        then
            if (count($div/ancestor::tei:div) < 2)
            then
                <li class="{if ($div is $current) then 'current' else 'not-current'}">
                    {
                        if ($div/tei:div and count($div/ancestor::tei:div) < 1) then
                            <a href="#" class="toc-toggle"><i class="glyphicon glyphicon-plus"/></a>
                        else
                            ()
                    }
                    <a href="{$div-id}.html" class="toc-link">{app:derive-title($div)}</a> 
                    {if ($long eq 'yes') then app:generate-toc-from-divs($div, $current, $long) else ()}
                </li>
            else ()
        else
            <a href="{$div-id}.html">{app:derive-title($div)}</a> 
};

(:~
 : 
 :)
declare function app:work-title($node as node(), $model as map(*), $type as xs:string?) {
    let $suffix := if ($type) then "." || $type else ()
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $id := $work/@xml:id
    let $id := if ($id) then $id else util:document-name($work) || ".xml"
    return
        <a xmlns="http://www.w3.org/1999/xhtml" href="{$node/@href}{$id}{$suffix}">{ app:work-title($work) }</a>
};

declare %private function app:work-title($work as element(tei:TEI)?) {
    let $main-title := $work/*:teiHeader/*:fileDesc/*:titleStmt/*:title[@type eq 'main']/text()
    let $main-title := if ($main-title) then $main-title else $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1]/text()
    return
        $main-title
};

declare 
    %templates:wrap
function app:checkbox($node as node(), $model as map(*), $target-texts as xs:string*) {
    let $id := $model("work")/@xml:id/string()
    return (
        attribute { "value" } {
            $id
        },
        if ($id = $target-texts) then
            attribute checked { "checked" }
        else
            ()
    )
};

declare function app:work-author($node as node(), $model as map(*)) {
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $work-authors := $work//tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:biblFull/tei:titleStmt/tei:author
    return 
        $work-authors
};

declare function app:epub-link($node as node(), $model as map(*)) {
    let $id := $model("work")/@xml:id/string()
    return
        <a xmlns="http://www.w3.org/1999/xhtml" href="{$node/@href}{$id}.epub">{ $node/node() }</a>
};

declare function app:pdf-link($node as node(), $model as map(*)) {
    let $file := replace(util:document-name($model("work")), "^(.*?)\..*$", "$1")
    let $uuid := util:uuid()
    return
        <a class="pdf-link" xmlns="http://www.w3.org/1999/xhtml" 
            data-token="{$uuid}" href="{$node/@href}{$file}.pdf?token={$uuid}&amp;cache=no">{ $node/node() }</a>
};

declare function app:xml-link($node as node(), $model as map(*)) {
    let $doc-path := document-uri(root($model("work")))
    let $eXide-link := $app:EXIDE || "?open=" || $doc-path
    let $rest-link := '/exist/rest' || $doc-path
    return
        if ($app:EXIDE)
        then 
            <a xmlns="http://www.w3.org/1999/xhtml" href="{$eXide-link}" 
                target="eXide" class="eXide-open" data-exide-open="{$doc-path}">{ $node/node() }</a>
        else 
            <a xmlns="http://www.w3.org/1999/xhtml" href="{$rest-link}" target="_blank">{ $node/node() }</a>
};

declare function app:copy-params($node as node(), $model as map(*)) {
    element { node-name($node) } {
        $node/@* except $node/@href,
        attribute href {
            let $link := $node/@href
            let $params :=
                string-join(
                    for $param in request:get-parameter-names()
                    for $value in request:get-parameter($param, ())
                    return
                        $param || "=" || $value,
                    "&amp;"
                )
            return
                $link || "?" || $params
        },
        $node/node()
    }
};

declare function app:work-authors($node as node(), $model as map(*)) {
    let $authors := distinct-values(collection($config:remote-data-root)//tei:fileDesc/tei:titleStmt/tei:author)
    let $authors := for $author in $authors order by translate($author, 'ĀŚ', 'AS') return $author 
    let $control := 
        <select multiple="multiple" name="work-authors" class="form-control">
            <option value="all" selected="selected">In Texts By Any Author</option>
            {for $author in $authors
            return <option value="{$author}">{$author}</option>
            }
        </select>
    return
        templates:form-control($control, $model)
};

declare 
    %templates:wrap
function app:navigation($node as node(), $model as map(*)) {
    let $div := $model("work")
    let $parent := $div/ancestor::tei:div[not(*[1] instance of element(tei:div))][1]
    let $prevDiv := $div/preceding::tei:div[1]
    let $prevDiv := app:get-previous(if ($parent and $div/.. >> $prevDiv) then $div/.. else $prevDiv)
    let $nextDiv := app:get-next($div)
(:        ($div//tei:div[not(*[1] instance of element(tei:div))] | $div/following::tei:div)[1]:)
    let $work := $div/ancestor-or-self::tei:TEI
    return
        map {
            "previous" := $prevDiv,
            "next" := $nextDiv,
            "work" := $work,
            "div" := $div
        }
};

declare %private function app:get-next($div as element()) {
    if ($div/tei:div) then
        if (count(($div/tei:div[1])/preceding-sibling::*) < 5) then
            app:get-next($div/tei:div[1])
        else
            $div/tei:div[1]
    else
        $div/following::tei:div[1]
};

declare %private function app:get-previous($div as element(tei:div)?) {
    if (empty($div)) then
        ()
    else
        if (
            empty($div/preceding-sibling::tei:div)  (: first div in section :)
            and count($div/preceding-sibling::*) < 5 (: less than 5 elements before div :)
            and $div/.. instance of element(tei:div) (: parent is a div :)
        ) then
            app:get-previous($div/..)
        else
            $div
};

declare %private function app:get-current($div as element()?) {
    if (empty($div)) then
        ()
    else
        if ($div instance of element(tei:teiHeader)) then
        $div
        else
            if (
                empty($div/preceding-sibling::tei:div)  (: first div in section :)
                and count($div/preceding-sibling::*) < 5 (: less than 5 elements before div :)
                and $div/.. instance of element(tei:div) (: parent is a div :)
            ) then
                app:get-previous($div/..)
            else
                $div
};

declare
    %templates:wrap
function app:navigation-title($node as node(), $model as map(*)) {
    let $id :=
        if ($model("work")/@xml:id) then
            $model("work")/@xml:id
        else
            util:document-name($model("work")) || "_" || util:node-id($model("work"))
    return
        element { node-name($node) } {
            attribute href { $id },
            $node/@* except $node/@href,
            app:work-title($model('work'))
        }
};

declare function app:navigation-link($node as node(), $model as map(*), $direction as xs:string) {
    if ($model($direction)) then
        element { node-name($node) } {
            $node/@* except $node/@href,
            let $id := 
                if ($model($direction)/@xml:id) then
                    $model($direction)/@xml:id/string()
                else
                    util:document-name($model($direction)) || "_" || util:node-id($model($direction))
            return
                attribute href { $id || ".html" },
            $node/node()
        }
    else
        '&#xA0;' (:hack to keep "Next" from dropping into the hr when there is no "Previous":) 
};

declare 
    %templates:default("index", "lucene")
    %templates:default("action", "browse")
    %templates:default("query-scripts", "all")
function app:view($node as node(), $model as map(*), $id as xs:string, $action as xs:string, $query-scripts as xs:string) {
        let $query := 
            if ($action eq 'search')
            then session:get-attribute("apps.sarit.query")
            else ()
        let $query-scope := 
            if (not(empty($query)))
            then session:get-attribute("apps.sarit.scope")
            else ()
        return
            app:lucene-view($node, $model, $id, $query, $query-scope, $query-scripts)
};

declare function app:lucene-view($node as node(), $model as map(*), $id as xs:string, $query as item()?, $query-scope as xs:string?, $query-scripts as xs:string) {    
(:    console:log("sarit", "lucene-view: " || $id),:)
    for $div in $model("work")
    let $div :=
        if ($query) then
            if ($query-scope eq 'narrow') then
                util:expand((
                $div[.//tei:p[ft:query(., $query)]],
                $div[.//tei:head[ft:query(., $query)]],
                $div[.//tei:lg[ft:query(., $query)]],
                $div[.//tei:trailer[ft:query(., $query)]],
                $div[.//tei:note[ft:query(., $query)]],
                $div[.//tei:list[ft:query(., $query)]],
                $div[.//tei:l[ft:query(., $query)]],
                $div[.//tei:quote[ft:query(., $query)]],
                $div[.//tei:table[ft:query(., $query)]],
                $div[.//tei:listApp[ft:query(., $query)]],
                $div[.//tei:listBibl[ft:query(., $query)]],
                $div[.//tei:cit[ft:query(., $query)]],
                $div[.//tei:label[ft:query(., $query)]],
                $div[.//tei:encodingDesc[ft:query(., $query)]],
                $div[.//tei:fileDesc[ft:query(., $query)]],
                $div[.//tei:profileDesc[ft:query(., $query)]],
                $div[.//tei:revisionDesc[ft:query(., $query)]]
                ),
                "add-exist-id=all")
            else
                util:expand(
                (
                    $div[ft:query(., $query)], 
                    $div[.//tei:teiHeader[ft:query(., $query)]]
                )
                , "add-exist-id=all")
        else
            $div
    let $view := app:get-content($div[1])
    return
        <div xmlns="http://www.w3.org/1999/xhtml" class="play">
        {
            pmu:process($config:odd-root || "/teisimple.odd", $view, $config:odd-root, "web", "../resources/odd")
        }
        </div>
};

declare function app:get-content($div as element()) {
    if ($div instance of element(tei:teiHeader)) then 
        $div
    else
        if ($div instance of element(tei:div)) then
            if ($div/tei:div) then
                if (count(($div/tei:div[1])/preceding-sibling::*) < 5) then
                    let $child := $div/tei:div[1]
                    return
                        element { node-name($div) } {
                            $div/@*,
                            $child/preceding-sibling::*,
                            app:get-content($child)
                        }
                else
                    element { node-name($div) } {
                        $div/@*,
                        $div/tei:div[1]/preceding-sibling::*
                    }
            else
                $div
        else ()
};


(:~
    
:)
(:~
: Execute the query. The search results are not output immediately. Instead they
: are passed to nested templates through the $model parameter.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @param $node 
: @param $model
: @param $query The query string. This string is transformed into a <query> element containing one or two <bool> elements in a Lucene query and it is transformed into a sequence of one or two query strings in an ngram query. The first <bool> and the first string contain the query as input and the second the query as transliterated into Devanagari or IAST as determined by $query-scripts. One <bool> and one query string may be empty.
: @param $index The index against which the query is to be performed, as the string "ngram" or "lucene".
: @param $lucene-query-mode If a Lucene query is performed, which of the options "any", "all", "phrase", "near-ordered", "near-unordered", "fuzzy", or "regex" have been selected (note that wildcard is not implemented, due to its syntactic overlap with regex).
: @param $tei-target A sequence of one or more targets within a TEI document, the tei:teiHeader or tei:text.
: @param $work-authors A sequence of the string "all" or of the xml:ids of the documents associated with the selected authors.
: @param $query-scripts A sequence of the string "all" or of the values "sa-Latn" or "sa-Deva", indicating whether or not the user wishes to transliterate the query string.
: @param $target-texts A sequence of the string "all" or of the xml:ids of the documents selected.

: @return The function returns a map containing the $hits, the $query, and the $query-scope. The search results are output through the nested templates, app:hit-count, app:paginate, and app:show-hits.
:)

declare 
    %templates:default("lucene-query-mode", "any")
    %templates:default("tei-target", "tei-text")
    %templates:default("query-scope", "narrow")
    %templates:default("work-authors", "all")
    %templates:default("query-scripts", "all")
    %templates:default("target-texts", "all")
function app:query($node as node()*, $model as map(*), $query as xs:string?, $lucene-query-mode as xs:string, $tei-target as xs:string+, $query-scope as xs:string, $work-authors as xs:string+, $query-scripts as xs:string, $target-texts as xs:string+) as map(*) {
        (:If there is no query string, fill up the map with existing values:)
        if (empty($query))
        then
            map {
                "hits" := session:get-attribute("apps.sarit"),
                "query" := session:get-attribute("apps.sarit.query"),
                "scope" := $query-scope (:NB: what about the other arguments?:)
            }
        else
            (:Otherwise, perform the query.:)
            (:First, which documents to query against has to be found out. Users can either make no selections in the list of documents, passing the value "all", or they can select individual document, passing a sequence of their xml:ids in $target-texts. Users can also select documents based on their authors. If no specific authors are selected, the value "all" is passed in $work-authors, but if selections have been made, a sequence of their xml:ids is passed. :)
            (:$target-texts will either have the value 'all' or contain a sequence of document xml:ids.:)
            let $target-texts := "all"
            (: Here the actual query commences. This is split into two parts, the first for a Lucene query and the second for an ngram query. :)
            (:The query passed to a Luecene query in ft:query is an XML element <query> containing one or two <bool>. The <bool> contain the original query and the transliterated query, as indicated by the user in $query-scripts.:)
            let $hits :=
                    (:If the $query-scope is narrow, query the elements immediately below the lowest div in tei:text and the four major element below tei:teiHeader.:)
                    if ($query-scope eq 'narrow')
                    then
                        for $hit in 
                            (:If both tei-text and tei-header is queried.:)
                            if (count($tei-target) eq 2)
                            then 
                                (
                                collection($config:remote-data-root)//tei:div[ft:query(., $query)]
(:                                collection($config:remote-data-root)//tei:head[ft:query(., $query)],:)
(:                                collection($config:remote-data-root)//tei:l[ft:query(., $query)],:)
(:                                collection($config:remote-data-root)//tei:item[ft:query(., $query)]:)
                                )
                            else
                                if ($tei-target = 'tei-text')
                                then
                                    (
                                    collection($config:remote-data-root)//tei:div[ft:query(., $query)]
(:                                    collection($config:remote-data-root)//tei:head[ft:query(., $query)],:)
(:                                    collection($config:remote-data-root)//tei:l[ft:query(., $query)],:)
(:                                    collection($config:remote-data-root)//tei:item[ft:query(., $query)]:)
                                    )
                                else 
                                    if ($tei-target = 'tei-header')
                                    then 
                                        (
                                        collection($config:remote-data-root)//tei:encodingDesc[ft:query(., $query)],
                                        collection($config:remote-data-root)//tei:fileDesc[ft:query(., $query)],
                                        collection($config:remote-data-root)//tei:profileDesc[ft:query(., $query)],
                                        collection($config:remote-data-root)//tei:revisionDesc[ft:query(., $query)]
                                        )
                                    else ()    
                        order by ft:score($hit) descending
                        return $hit
                    (:If the $query-scope is broad, query the lowest div in tei:text and tei:teiHeader.:)
                    else
                        for $hit in 
                            if (count($tei-target) eq 2)
                            then
                                (
                                collection($config:remote-data-root)//tei:div[not(tei:div)][ft:query(., $query)],
                                collection($config:remote-data-root)/descendant-or-self::tei:teiHeader[ft:query(., $query)](:NB: Can divs occur in the header? If so, they have to be removed here5:)
                                )
                            else
                                if ($tei-target = 'tei-text')
                                then
                                    (
                                    collection($config:remote-data-root)//tei:div[not(tei:div)][ft:query(., $query)]
                                    )
                                else 
                                    if ($tei-target = 'tei-header')
                                    then 
                                        collection($config:remote-data-root)/descendant-or-self::tei:teiHeader[ft:query(., $query)]
                                    else ()
                        order by ft:score($hit) descending
                        return $hit
            (:Store the result in the session.:)
            let $store := (
                session:set-attribute("apps.sarit", $hits),
                session:set-attribute("apps.sarit.query", $query),
                session:set-attribute("apps.sarit.scope", $query-scope)
                )
            return
                (: The hits are not returned directly, but processed by the nested templates :)
                map {
                    "hits" := $hits,
                    "query" := $query
                }
};

(:~
 : Create a bootstrap pagination element to navigate through the hits.
 :)
declare
    %templates:wrap
    %templates:default('key', 'hits')
    %templates:default('start', 1)
    %templates:default("per-page", 10)
    %templates:default("min-hits", 0)
    %templates:default("max-pages", 10)
function app:paginate($node as node(), $model as map(*), $key as xs:string, $start as xs:int, $per-page as xs:int, $min-hits as xs:int,
    $max-pages as xs:int) {
    if ($min-hits < 0 or count($model($key)) >= $min-hits) then
        let $count := xs:integer(ceiling(count($model($key))) div $per-page) + 1
        let $middle := ($max-pages + 1) idiv 2
        return (
            if ($start = 1) then (
                <li class="disabled">
                    <a><i class="glyphicon glyphicon-fast-backward"/></a>
                </li>,
                <li class="disabled">
                    <a><i class="glyphicon glyphicon-backward"/></a>
                </li>
            ) else (
                <li>
                    <a href="?start=1"><i class="glyphicon glyphicon-fast-backward"/></a>
                </li>,
                <li>
                    <a href="?start={max( ($start - $per-page, 1 ) ) }"><i class="glyphicon glyphicon-backward"/></a>
                </li>
            ),
            let $startPage := xs:integer(ceiling($start div $per-page))
            let $lowerBound := max(($startPage - ($max-pages idiv 2), 1))
            let $upperBound := min(($lowerBound + $max-pages - 1, $count))
            let $lowerBound := max(($upperBound - $max-pages + 1, 1))
            for $i in $lowerBound to $upperBound
            return
                if ($i = ceiling($start div $per-page)) then
                    <li class="active"><a href="?start={max( (($i - 1) * $per-page + 1, 1) )}">{$i}</a></li>
                else
                    <li><a href="?start={max( (($i - 1) * $per-page + 1, 1)) }">{$i}</a></li>,
            if ($start + $per-page < count($model($key))) then (
                <li>
                    <a href="?start={$start + $per-page}"><i class="glyphicon glyphicon-forward"/></a>
                </li>,
                <li>
                    <a href="?start={max( (($count - 1) * $per-page + 1, 1))}"><i class="glyphicon glyphicon-fast-forward"/></a>
                </li>
            ) else (
                <li class="disabled">
                    <a><i class="glyphicon glyphicon-forward"/></a>
                </li>,
                <li>
                    <a><i class="glyphicon glyphicon-fast-forward"/></a>
                </li>
            )
        ) else
            ()
};

(:~
    Create a span with the number of items in the current search result.
:)
declare 
    %templates:default("key", "hits")
function app:hit-count($node as node()*, $model as map(*), $key as xs:string) {
    <span xmlns="http://www.w3.org/1999/xhtml" id="hit-count">{ count($model($key)) }</span>
};

(:~
    Output the actual search result as a div, using the kwic module to summarize full text matches.
:)
declare 
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:show-hits($node as node()*, $model as map(*), $start as xs:integer, $per-page as xs:integer) {
    for $hit at $p in subsequence($model("hits"), $start, $per-page)
    let $parent := $hit/ancestor-or-self::tei:div[1]
    let $parent := if ($parent) then $parent else $hit/ancestor-or-self::tei:teiHeader  
    let $div := app:get-current($parent)
    let $parent-id := ($parent/@xml:id/string(), util:document-name($parent) || "_" || util:node-id($parent))[1]
    let $div-id := ($div/@xml:id/string(), util:document-name($div) || "_" || util:node-id($div))[1]
    (:if the nearest div does not have an xml:id, find the nearest element with an xml:id and use it:)
    (:is this necessary - can't we just use the nearest ancestor?:) 
(:    let $div-id := :)
(:        if ($div-id) :)
(:        then $div-id :)
(:        else ($hit/ancestor-or-self::*[@xml:id]/@xml:id)[1]/string():)
    (:if it is not a div, it will not have a head:)
    let $div-head := $parent/tei:head/text()
    (:TODO: what if the hit is in the header?:)
    let $work := $hit/ancestor::tei:TEI
    let $work-title := app:work-title($work)
    (:the work always has xml:id.:)
    let $work-id := $work/@xml:id/string()
    (:pad hit with surrounding siblings:)
    let $hit-padded := <hit>{($hit/preceding-sibling::*[1], $hit, $hit/following-sibling::*[1])}</hit>
    let $loc := 
        <tr class="reference">
            <td colspan="3">
                <span class="number">{$start + $p - 1}</span>
                <a href="{$work-id}">{$work-title}</a>{if ($div-head) then ', ' else ''}<a href="{$parent-id}.html">{$div-head}</a>
            </td>
        </tr>
    let $matchId := ($hit/@xml:id, util:node-id($hit))[1]
    let $config := <config width="60" table="yes" link="{$div-id}.html?action=search#{$matchId}"/>
    let $kwic := kwic:summarize($hit-padded, $config)
    return
        ($loc, $kwic)        
};

declare function app:base($node as node(), $model as map(*)) {
    let $context := request:get-context-path()
    let $app-root := substring-after($config:app-root, "/db/")
    return
        <base xmlns="http://www.w3.org/1999/xhtml" href="{$context}/{$app-root}/"/>
};

(: This functions provides crude way to avoid the most common errors with paired expressions and apostrophes. :)
(: TODO: check order of pairs:)
declare %private function app:sanitize-lucene-query($query-string as xs:string) as xs:string {
    let $query-string := replace($query-string, "'", "''") (:escape apostrophes:)
    (:TODO: notify user if query has been modified.:)
    (:Remove colons – Lucene fields are not supported.:)
    let $query-string := translate($query-string, ":", " ")
    let $query-string := 
       if (functx:number-of-matches($query-string, '"') mod 2) 
       then $query-string
       else replace($query-string, '"', ' ') (:if there is an uneven number of quotation marks, delete all quotation marks.:)
    let $query-string := 
       if ((functx:number-of-matches($query-string, '\(') + functx:number-of-matches($query-string, '\)')) mod 2 eq 0) 
       then $query-string
       else translate($query-string, '()', ' ') (:if there is an uneven number of parentheses, delete all parentheses.:)
    let $query-string := 
       if ((functx:number-of-matches($query-string, '\[') + functx:number-of-matches($query-string, '\]')) mod 2 eq 0) 
       then $query-string
       else translate($query-string, '[]', ' ') (:if there is an uneven number of brackets, delete all brackets.:)
    let $query-string := 
       if ((functx:number-of-matches($query-string, '{') + functx:number-of-matches($query-string, '}')) mod 2 eq 0) 
       then $query-string
       else translate($query-string, '{}', ' ') (:if there is an uneven number of braces, delete all braces.:)
    let $query-string := 
       if ((functx:number-of-matches($query-string, '<') + functx:number-of-matches($query-string, '>')) mod 2 eq 0) 
       then $query-string
       else translate($query-string, '<>', ' ') (:if there is an uneven number of angle brackets, delete all angle brackets.:)
    return $query-string
};

(: Function to translate a Lucene search string to an intermediate string mimicking the XML syntax, 
with some additions for later parsing of boolean operators. The resulting intermediary XML search string will be parsed as XML with util:parse(). 
Based on Ron Van den Branden, https://rvdb.wordpress.com/2010/08/04/exist-lucene-to-xml-syntax/:)
(:TODO:
The following cases are not covered:
1)
<query><near slop="10"><first end="4">snake</first><term>fillet</term></near></query>
as opposed to
<query><near slop="10"><first end="4">fillet</first><term>snake</term></near></query>

w(..)+d, w[uiaeo]+d is not treated correctly as regex.
:)
declare %private function app:parse-lucene($string as xs:string) {
    (: replace all symbolic booleans with lexical counterparts :)
    if (matches($string, '[^\\](\|{2}|&amp;{2}|!) ')) 
    then
        let $rep := 
            replace(
            replace(
            replace(
                $string, 
            '&amp;{2} ', 'AND '), 
            '\|{2} ', 'OR '), 
            '! ', 'NOT ')
        return app:parse-lucene($rep)                
    else 
        (: replace all booleans with '<AND/>|<OR/>|<NOT/>' :)
        if (matches($string, '[^<](AND|OR|NOT) ')) 
        then
            let $rep := replace($string, '(AND|OR|NOT) ', '<$1/>')
            return app:parse-lucene($rep)
        else 
            (: replace all '+' modifiers in token-initial position with '<AND/>' :)
            if (matches($string, '(^|[^\w&quot;])\+[\w&quot;(]'))
            then
                let $rep := replace($string, '(^|[^\w&quot;])\+([\w&quot;(])', '$1<AND type=_+_/>$2')
                return app:parse-lucene($rep)
            else 
                (: replace all '-' modifiers in token-initial position with '<NOT/>' :)
                if (matches($string, '(^|[^\w&quot;])-[\w&quot;(]'))
                then
                    let $rep := replace($string, '(^|[^\w&quot;])-([\w&quot;(])', '$1<NOT type=_-_/>$2')
                    return app:parse-lucene($rep)
                else 
                    (: replace parentheses with '<bool></bool>' :)
                    (:NB: regex also uses parentheses!:) 
                    if (matches($string, '(^|[\W-[\\]]|>)\(.*?[^\\]\)(\^(\d+))?(<|\W|$)'))                
                    then
                        let $rep := 
                            (: add @boost attribute when string ends in ^\d :)
                            (:if (matches($string, '(^|\W|>)\(.*?\)(\^(\d+))(<|\W|$)')) 
                            then replace($string, '(^|\W|>)\((.*?)\)(\^(\d+))(<|\W|$)', '$1<bool boost=_$4_>$2</bool>$5')
                            else:) replace($string, '(^|\W|>)\((.*?)\)(<|\W|$)', '$1<bool>$2</bool>$3')
                        return app:parse-lucene($rep)
                    else 
                        (: replace quoted phrases with '<near slop="0"></bool>' :)
                        if (matches($string, '(^|\W|>)(&quot;).*?\2([~^]\d+)?(<|\W|$)')) 
                        then
                            let $rep := 
                                (: add @boost attribute when phrase ends in ^\d :)
                                (:if (matches($string, '(^|\W|>)(&quot;).*?\2([\^]\d+)?(<|\W|$)')) 
                                then replace($string, '(^|\W|>)(&quot;)(.*?)\2([~^](\d+))?(<|\W|$)', '$1<near boost=_$5_>$3</near>$6')
                                (\: add @slop attribute in other cases :\)
                                else:) replace($string, '(^|\W|>)(&quot;)(.*?)\2([~^](\d+))?(<|\W|$)', '$1<near slop=_$5_>$3</near>$6')
                            return app:parse-lucene($rep)
                        else (: wrap fuzzy search strings in '<fuzzy max-edits=""></fuzzy>' :)
                            if (matches($string, '[\w-[<>]]+?~[\d.]*')) 
                            then
                                let $rep := replace($string, '([\w-[<>]]+?)~([\d.]*)', '<fuzzy max-edits=_$2_>$1</fuzzy>')
                                return app:parse-lucene($rep)
                            else (: wrap resulting string in '<query></query>' :)
                                concat('<query>', replace(normalize-space($string), '_', '"'), '</query>')
};

(: Function to transform the intermediary structures in the search query generated through app:parse-lucene() and util:parse() 
to full-fledged boolean expressions employing XML query syntax. 
Based on Ron Van den Branden, https://rvdb.wordpress.com/2010/08/04/exist-lucene-to-xml-syntax/:)
declare %private function app:lucene2xml($node as item(), $lucene-query-mode as xs:string) {
    typeswitch ($node)
        case element(query) return 
            element { node-name($node)} {
            element bool {
            $node/node()/app:lucene2xml(., $lucene-query-mode)
        }
    }
    case element(AND) return ()
    case element(OR) return ()
    case element(NOT) return ()
    case element() return
        let $name := 
            if (($node/self::phrase | $node/self::near)[not(@slop > 0)]) 
            then 'phrase' 
            else node-name($node)
        return
            element { $name } {
                $node/@*,
                    if (($node/following-sibling::*[1] | $node/preceding-sibling::*[1])[self::AND or self::OR or self::NOT or self::bool])
                    then
                        attribute occur {
                            if ($node/preceding-sibling::*[1][self::AND]) 
                            then 'must'
                            else 
                                if ($node/preceding-sibling::*[1][self::NOT]) 
                                then 'not'
                                else 
                                    if ($node[self::bool]and $node/following-sibling::*[1][self::AND])
                                    then 'must'
                                    else
                                        if ($node/following-sibling::*[1][self::AND or self::OR or self::NOT][not(@type)]) 
                                        then 'should' (:must?:) 
                                        else 'should'
                        }
                    else ()
                    ,
                    $node/node()/app:lucene2xml(., $lucene-query-mode)
        }
    case text() return
        if ($node/parent::*[self::query or self::bool]) 
        then
            for $tok at $p in tokenize($node, '\s+')[normalize-space()]
            (:Here the query switches into regex mode based on whether or not characters used in regex expressions are present in $tok.:)
            (:It is not possible reliably to distinguish reliably between a wildcard search and a regex search, so switching into wildcard searches is ruled out here.:)
            (:One could also simply dispense with 'term' and use 'regex' instead - is there a speed penalty?:)
                let $el-name := 
                    if (matches($tok, '((^|[^\\])[.?*+()\[\]\\^|{}#@&amp;<>~]|\$$)') or $lucene-query-mode eq 'regex')
                    then 'regex'
                    else 'term'
                return 
                    element { $el-name } {
                        attribute occur {
                        (:if the term follows AND:)
                        if ($p = 1 and $node/preceding-sibling::*[1][self::AND]) 
                        then 'must'
                        else 
                            (:if the term follows NOT:)
                            if ($p = 1 and $node/preceding-sibling::*[1][self::NOT])
                            then 'not'
                            else (:if the term is preceded by AND:)
                                if ($p = 1 and $node/following-sibling::*[1][self::AND][not(@type)])
                                then 'must'
                                    (:if the term follows OR and is preceded by OR or NOT, or if it is standing on its own:)
                                else 'should'
                    }
                    (:,
                    if (matches($tok, '((^|[^\\])[.?*+()\[\]\\^|{}#@&amp;<>~]|\$$)')) 
                    then
                        (\:regex searches have to be lower-cased:\)
                        attribute boost {
                            lower-case(replace($tok, '(.*?)(\^(\d+))(\W|$)', '$3'))
                        }
                    else ():)
        ,
        (:regex searches have to be lower-cased:)
        lower-case(normalize-space(replace($tok, '(.*?)(\^(\d+))(\W|$)', '$1')))
        }
        else normalize-space($node)
    default return
        $node
};