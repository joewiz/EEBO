/*!
* put application-specific JavaScript code
*/
'use strict';

$(document).ready(function() {
    $("#toc-toggle").click(function(ev) {
        $(".sidebar-offcanvas").parent().toggleClass("active");
        $("html, body").animate({ scrollTop: 0 }, "fast");
    });
    
    // table of contents tree
    
    // expand current item
    $(".contents .current").parents("ul").each(function() {
        $(this).show().prevAll(".toc-toggle").find("i").removeClass("glyphicon-plus").addClass("glyphicon-minus");
        $(this).parent().addClass("open");
    });
    
    // handle click on +/-
    $(".toc-toggle").click(function(ev) {
        ev.preventDefault();
        var link = $(this);
        if (link.parent().is(".open")) {
            link.nextAll("ul").hide(200);
            link.find("i").removeClass("glyphicon-minus").addClass("glyphicon-plus");
        } else {
            link.nextAll("ul").show(200);
            link.find("i").removeClass("glyphicon-plus").addClass("glyphicon-minus");
        }
        link.parent().toggleClass("open");
    });
    
    // search form
    var select = $("select[name='index']");
    
    // hide mode selection unless lucene index is chosen
    function initIndexSelect() {
        if (select.length == 0) {
            return;
        }
        var index = select.val();
        $("#mode-selection").hide();
        if (index === "lucene") {
            $("#mode-selection").show();
        }
    }
    
    select.change(function(ev) {
        initIndexSelect();
    });
    initIndexSelect();
    
    $('.popover-dismiss').popover({
        html:true,
        placement:"auto top",
        content:function(note)
        {
            $(note).next(".note-contents").html()
        }
    });
    
    var downloadCheck;
    
    $(".pdf-link").click(function(ev) {
        $("#pdf-info").modal({
            show: true
        });
        var token = $(this).attr("data-token");
        downloadCheck = window.setInterval(function() {
            var cookieValue = $.macaroon("sarit.token");
            if (cookieValue == token) {
                window.clearInterval(downloadCheck);
                $.macaroon("sarit.token", null);
                $("#pdf-info").modal("hide");
            }
        });
    });
    
    $(".note1").popover({trigger: "hover", html: "true"});
    $('[data-toggle="tooltip"]').tooltip();
    
    $('.typeahead-meta').typeahead({
        items: 20,
        minLength: 4,
        source: function(query, callback) {
            var type = $("select[name='browse']").val();
            $.getJSON("../modules/autocomplete.xql?q=" + query + "&type=" + type, function(data) {
                callback(data || []);
            });
        },
        updater: function(item) {
            if (/[\s,]/.test(item)) {
                return '"' + item + '"';
            }
            return item;
        }
    });
    $('.typeahead-search').typeahead({
        items: 30,
        minLength: 4,
        source: function(query, callback) {
            var type = $("select[name='tei-target']").val();
            $.getJSON("../modules/autocomplete.xql?q=" + query + "&type=" + type, function(data) {
                callback(data || []);
            });
        }
    });
    
    /* AJAX page loading when browsing book */
    var historySupport = !!(window.history && window.history.pushState);
    
    function load(params, direction) {
        var animOut = direction == "next" ? "fadeOutLeft" : "fadeOutRight";
        var animIn = direction == "next" ? "fadeInRight" : "fadeInLeft";
        $("#content-container").addClass("animated " + animOut)
            .one("webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend animationend", function() {
                var container = $(this);
                $.getJSON("../modules/ajax.xql", params, function(data) {
                    $(".play").replaceWith(data.content);
                    $(".play .note1").popover({trigger: "hover", html: "true"});
                    $('.play span[data-toggle="tooltip"]').tooltip();
                    container.removeClass("animated " + animOut);
                    $("#content-container").addClass("animated " + animIn).one("webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend animationend", function() {
                        $(this).removeClass("animated " + animIn);
                    });
                    if (data.next) {
                        $(".next").attr("href", data.next).css("visibility", "");
                    } else {
                        $(".next").css("visibility", "hidden");
                    }
                    if (data.previous) {
                        $(".previous").attr("href", data.previous).css("visibility", "");
                    } else {
                        $(".previous").css("visibility", "hidden");
                    }
                });
        });
    }
    
    $(".next,.previous").click(function(ev) {
        ev.preventDefault();
        var url = "doc=" + this.pathname.replace(/^.*\/([^/]+)$/, "$1");
        if (historySupport) {
            history.pushState(null, null, this.href);
        }
        load(url, this.className);
    });
    
    $(window).on("popstate", function(ev) {
        var url = "doc=" + window.location.pathname.replace(/^.*\/([^/]+)$/, "$1");
        load(url);
    });
});