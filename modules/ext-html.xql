xquery version "3.1";

(:~
 : Non-standard extension functions, mainly used for the documentation.
 :)
module namespace pmf="http://existsolutions.com/apps/eebo/ext-html";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function pmf:collapse($config as map(*), $node as element(), $class as xs:string, $title, $content) {
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
                { $config?apply-children($config, $node, $content) }
                </div>
            </div>
        </div>
    </div>
};

declare function pmf:break($config as map(*), $node as element(), $class as xs:string, $type as xs:string, $label as item()*, $facs as item()*) {
    switch($type)
        case "page" return
            if ($label) then
                <span class="{$class}" 
                    title="{$config?apply-children($config, $node, $facs)}"
                    data-toggle="tooltip">[p. {$config?apply-children($config, $node, $label)}]</span>
            else
                <span class="{$class}">[{$config?apply-children($config, $node, $facs)}]</span>
        default return
            <br/>
};

declare function pmf:code($config as map(*), $node as element(), $class as xs:string, $content as node()*, $lang as item()?) {
    <pre class="sourcecode" data-language="{if ($lang) then $lang else 'xquery'}">{$config?apply($config, $content/node())}</pre>
};

declare function pmf:cells($config as map(*), $node as element(), $class as xs:string, $content) {
    <tr>
    {
        for $cell in $content/node() | $content/@*
        return
            <td class="{$class}">{$config?apply-children($config, $node, $cell)}</td>
    }
    </tr>
};