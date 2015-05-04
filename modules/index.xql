xquery version "3.0";

import module namespace config="http://exist-db.org/apps/appblueprint/config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function local:index() {
    for $doc in collection($config:remote-data-root)/tei:TEI
    let $titleStmt := $doc//tei:sourceDesc/tei:biblFull/tei:titleStmt
    let $index :=
        <doc>
            {
                for $title in $titleStmt/tei:title
                return
                    <field name="title" store="yes">{$title/text()}</field>
            }
            {
                for $author in $titleStmt/tei:author
                let $normalized := replace($author/text(), "^([^,]*,[^,]*),?.*$", "$1")
                return
                    <field name="author" store="yes">{$normalized}</field>
            }
            <field name="year" store="yes">{$doc/tei:teiHeader/tei:fileDesc/tei:editionStmt/tei:edition/tei:date/text()}</field>
            <field name="file" store="yes">{substring-before(util:document-name($doc), ".xml")}</field>
        </doc>
    return
        ft:index(document-uri(root($doc)), $index)
};

declare function local:clear() {
    for $doc in collection($config:remote-data-root)/tei:TEI
    return
        ft:remove-index(document-uri(root($doc)))
};

local:clear(),
local:index()