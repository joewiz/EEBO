xquery version "3.1";

(:~
 : Non-standard extension functions, mainly used for the documentation.
 :)
module namespace pmf="http://existsolutions.com/apps/eebo/ext-html";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function pmf:accordion($config as map(*), $node as element(), $class as xs:string, $title, $content) {
    <div class="panel-group" id="{generate-id($node)}" role="tablist">
        <div class="panel panel-default">
            <div class="panel-heading" role="tab">
                <h4 class="panel-title">
                    <a data-toggle="collapse" data-parent="#{generate-id($node)}"
                        href="#{translate(generate-id($content), '.', '_')}">
                        {$title}
                    </a>
                </h4>
            </div>
            <div id="{translate(generate-id($content), '.', '_')}" class="panel-collapse collapse" role="tabpanel">
                <div class="panel-body">
                { pmf:apply-children($config, $node, $content) }
                </div>
            </div>
        </div>
    </div>
};

declare function pmf:code($config as map(*), $node as element(), $class as xs:string, $content as node()*, $lang as item()?) {
    <pre class="sourcecode" data-language="{if ($lang) then $lang else 'xquery'}">{$config?apply($config, $content/node())}</pre>
};

declare %private function pmf:apply-children($config as map(*), $node as element(), $content as item()*) {
    if ($node/@xml:id) then
        attribute id { $node/@xml:id }
    else
        (),
    $content ! (
        typeswitch(.)
            case element() return
                if (. is $node) then
                    $config?apply($config, ./node())
                else
                    $config?apply($config, .)
            default return
                string(.)
    )
};