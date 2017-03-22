<!--

    The contents of this file are subject to the license and copyright
    detailed in the LICENSE and NOTICE files at the root of the source
    tree and available online at

    http://www.dspace.org/license/

-->

<!--
    Main structure of the page, determines where
    header, footer, body, navigation are structurally rendered.
    Rendering of the header, footer, trail and alerts

    Author: art.lowel at atmire.com
    Author: lieven.droogmans at atmire.com
    Author: ben at atmire.com
    Author: Alexey Maslov

-->

<xsl:stylesheet xmlns:i18n="http://apache.org/cocoon/i18n/2.1"
                xmlns:dri="http://di.tamu.edu/DRI/1.0/"
                xmlns:mets="http://www.loc.gov/METS/"
                xmlns:xlink="http://www.w3.org/TR/xlink/"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:dim="http://www.dspace.org/xmlns/dspace/dim"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:mods="http://www.loc.gov/mods/v3"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:confman="org.dspace.core.ConfigurationManager"
                exclude-result-prefixes="i18n dri mets xlink xsl dim xhtml mods dc confman">

    <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

    <!--
        Requested Page URI. Some functions may alter behavior of processing depending if URI matches a pattern.
        Specifically, adding a static page will need to override the DRI, to directly add content.
    -->
    <xsl:variable name="request-uri" select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='request'][@qualifier='URI']"/>

    <!--
        The starting point of any XSL processing is matching the root element. In DRI the root element is document,
        which contains a version attribute and three top level elements: body, options, meta (in that order).

        This template creates the html document, giving it a head and body. A title and the CSS style reference
        are placed in the html head, while the body is further split into several divs. The top-level div
        directly under html body is called "ds-main". It is further subdivided into:
            "ds-header"  - the header div containing title, subtitle, trail and other front matter
            "ds-body"    - the div containing all the content of the page; built from the contents of dri:body
            "ds-options" - the div with all the navigation and actions; built from the contents of dri:options
            "ds-footer"  - optional footer div, containing misc information

        The order in which the top level divisions appear may have some impact on the design of CSS and the
        final appearance of the DSpace page. While the layout of the DRI schema does favor the above div
        arrangement, nothing is preventing the designer from changing them around or adding new ones by
        overriding the dri:document template.
    -->
    <xsl:template match="dri:document">

        <xsl:choose>
            <xsl:when test="not($isModal)">

            <xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE html&gt;
            </xsl:text>
            <xsl:text disable-output-escaping="yes">&lt;!--[if lt IE 7]&gt; &lt;html class=&quot;no-js lt-ie9 lt-ie8 lt-ie7&quot; lang=&quot;en&quot;&gt; &lt;![endif]--&gt;
            &lt;!--[if IE 7]&gt;    &lt;html class=&quot;no-js lt-ie9 lt-ie8&quot; lang=&quot;en&quot;&gt; &lt;![endif]--&gt;
            &lt;!--[if IE 8]&gt;    &lt;html class=&quot;no-js lt-ie9&quot; lang=&quot;en&quot;&gt; &lt;![endif]--&gt;
            &lt;!--[if gt IE 8]&gt;&lt;!--&gt; &lt;html class=&quot;no-js&quot; lang=&quot;en&quot;&gt; &lt;!--&lt;![endif]--&gt;
            </xsl:text>

                <!-- First of all, build the HTML head element -->

                <xsl:call-template name="buildHead"/>

                <!-- Then proceed to the body -->
                <body>
                    <!-- Prompt IE 6 users to install Chrome Frame. Remove this if you support IE 6.
                   chromium.org/developers/how-tos/chrome-frame-getting-started -->
                    <!--[if lt IE 7]><p class=chromeframe>Your browser is <em>ancient!</em> <a href="http://browsehappy.com/">Upgrade to a different browser</a> or <a href="http://www.google.com/chromeframe/?redirect=true">install Google Chrome Frame</a> to experience this site.</p><![endif]-->
                    <xsl:choose>
                        <xsl:when
                                test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='framing'][@qualifier='popup']">
                            <xsl:apply-templates select="dri:body/*"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:call-template name="buildHeader"/>
                            <xsl:call-template name="buildTrail"/>
                            <!--javascript-disabled warning, will be invisible if javascript is enabled-->
                            <div id="no-js-warning-wrapper" class="hidden">
                                <div id="no-js-warning">
                                    <div class="notice failure">
                                        <xsl:text>JavaScript is disabled for your browser. Some features of this site may not work without it.</xsl:text>
                                    </div>
                                </div>
                            </div>

                            <div id="main-container" class="container">

                                <div class="row row-offcanvas row-offcanvas-right">
                                    <div class="horizontal-slider clearfix">
                                        <div class="col-xs-12 col-sm-12 col-md-9 main-content">
                                            <xsl:apply-templates select="*[not(self::dri:options)]"/>
                                            <!--div class="visible-xs visible-sm container">
                                                <xsl:call-template name="buildFooter"/>
                                            </div-->
                                        </div>
                                        <div class="col-xs-6 col-sm-3 sidebar-offcanvas" id="sidebar" role="navigation">
                                            <xsl:apply-templates select="dri:options"/>
                                        </div>

                                    </div>
                                </div>

                                <!--
                            The footer div, dropping whatever extra information is needed on the page. It will
                            most likely be something similar in structure to the currently given example. -->
                            <!--div class="hidden-xs hidden-sm">
                                <xsl:call-template name="buildFooter"/>
                            </div-->
                         </div>


                        </xsl:otherwise>
                    </xsl:choose>

                        <!--div class="visible-xs visible-sm container"-->
                            <xsl:call-template name="buildFooter"/>
                        <!--/div-->
                    <!-- Javascript at the bottom for fast page loading -->
                    <xsl:call-template name="addJavascript"/>
                </body>
                <xsl:text disable-output-escaping="yes">&lt;/html&gt;</xsl:text>

            </xsl:when>
            <xsl:otherwise>
                <!-- This is only a starting point. If you want to use this feature you need to implement
                JavaScript code and a XSLT template by yourself. Currently this is used for the DSpace Value Lookup -->
                <xsl:apply-templates select="dri:body" mode="modal"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- The HTML head element contains references to CSS as well as embedded JavaScript code. Most of this
    information is either user-provided bits of post-processing (as in the case of the JavaScript), or
    references to stylesheets pulled directly from the pageMeta element. -->
    <xsl:template name="buildHead">
        <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>

            <!-- Use the .htaccess and remove these lines to avoid edge case issues.
             More info: h5bp.com/i/378 -->
            <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1"/>

            <!-- Mobile viewport optimized: h5bp.com/viewport -->
            <meta name="viewport" content="width=device-width,initial-scale=1"/>

            <!--link rel="shortcut icon">
                <xsl:attribute name="href">
                    <xsl:value-of select="$theme-path"/>
                    <xsl:text>images/favicon.ico</xsl:text>
                </xsl:attribute>
            </link>

            <link rel="apple-touch-icon">
                <xsl:attribute name="href">
                    <xsl:value-of select="$theme-path"/>
                    <xsl:text>images/apple-touch-icon.png</xsl:text>
                </xsl:attribute>
            </link-->

            <!-- Re-write below to use theme path as above? -->
            <link rel="apple-touch-icon" sizes="57x57" href="{$theme-path}/images/apple-icon-57x57.png" />
            <link rel="apple-touch-icon" sizes="60x60" href="{$theme-path}/images/apple-icon-60x60.png" />
            <link rel="apple-touch-icon" sizes="72x72" href="{$theme-path}/images/apple-icon-72x72.png" />
            <link rel="apple-touch-icon" sizes="76x76" href="{$theme-path}/images/apple-icon-76x76.png" />
            <link rel="apple-touch-icon" sizes="114x114" href="{$theme-path}/images/apple-icon-114x114.png" />
            <link rel="apple-touch-icon" sizes="120x120" href="{$theme-path}/images/apple-icon-120x120.png" />
            <link rel="apple-touch-icon" sizes="144x144" href="{$theme-path}/images/apple-icon-144x144.png" />
            <link rel="apple-touch-icon" sizes="152x152" href="{$theme-path}/images/apple-icon-152x152.png" />
            <link rel="apple-touch-icon" sizes="180x180" href="{$theme-path}/images/apple-icon-180x180.png" />
            <link rel="icon" type="image/png" sizes="192x192"  href="{$theme-path}/images/android-icon-192x192.png" />
            <link rel="icon" type="image/png" sizes="32x32" href="{$theme-path}/images/favicon-32x32.png" />
            <link rel="icon" type="image/png" sizes="96x96" href="{$theme-path}/images/favicon-96x96.png" />
            <link rel="icon" type="image/png" sizes="16x16" href="{$theme-path}/images/favicon-16x16.png" />
            <link rel="manifest" href="{$theme-path}/images/manifest.json"/>
            <meta name="msapplication-TileColor" content="#ffffff" />
            <meta name="msapplication-TileImage" content="{$theme-path}/images/ms-icon-144x144.png" />
            <meta name="theme-color" content="#ffffff" />

            <meta name="Generator">
                <xsl:attribute name="content">
                    <xsl:text>DSpace</xsl:text>
                    <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='dspace'][@qualifier='version']">
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='dspace'][@qualifier='version']"/>
                    </xsl:if>
                </xsl:attribute>
            </meta>

            <!-- Add stylesheets -->

            <!--TODO figure out a way to include these in the concat & minify-->
            <xsl:for-each select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='stylesheet']">
                <link rel="stylesheet" type="text/css">
                    <xsl:attribute name="media">
                        <xsl:value-of select="@qualifier"/>
                    </xsl:attribute>
                    <xsl:attribute name="href">
                        <xsl:value-of select="$theme-path"/>
                        <xsl:value-of select="."/>
                    </xsl:attribute>
                </link>
            </xsl:for-each>

            <link type="text/css" rel="stylesheet" href="//cdn.jsdelivr.net/bootstrap/3.3.5/css/bootstrap.min.css" media="all" />
            <link rel="stylesheet" href="{concat($theme-path, 'styles/main.css')}"/>

            <link href='https://fonts.googleapis.com/css?family=Lato:400,700' rel='stylesheet' type='text/css'/>
            <link href='https://fonts.googleapis.com/css?family=Open+Sans' rel='stylesheet' type='text/css'/>

            <!-- Add syndication feeds -->
            <xsl:for-each select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='feed']">
                <link rel="alternate" type="application">
                    <xsl:attribute name="type">
                        <xsl:text>application/</xsl:text>
                        <xsl:value-of select="@qualifier"/>
                    </xsl:attribute>
                    <xsl:attribute name="href">
                        <xsl:value-of select="."/>
                    </xsl:attribute>
                </link>
            </xsl:for-each>

            <!--  Add OpenSearch auto-discovery link -->
            <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='opensearch'][@qualifier='shortName']">
                <link rel="search" type="application/opensearchdescription+xml">
                    <xsl:attribute name="href">
                        <xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='request'][@qualifier='scheme']"/>
                        <xsl:text>://</xsl:text>
                        <xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='request'][@qualifier='serverName']"/>
                        <xsl:text>:</xsl:text>
                        <xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='request'][@qualifier='serverPort']"/>
                        <xsl:value-of select="$context-path"/>
                        <xsl:text>/</xsl:text>
                        <xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='opensearch'][@qualifier='autolink']"/>
                    </xsl:attribute>
                    <xsl:attribute name="title" >
                        <xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='opensearch'][@qualifier='shortName']"/>
                    </xsl:attribute>
                </link>
            </xsl:if>

            <!-- The following javascript removes the default text of empty text areas when they are focused on or submitted -->
            <!-- There is also javascript to disable submitting a form when the 'enter' key is pressed. -->
            <script>
                //Clear default text of emty text areas on focus
                function tFocus(element)
                {
                if (element.value == '<i18n:text>xmlui.dri2xhtml.default.textarea.value</i18n:text>'){element.value='';}
                }
                //Clear default text of emty text areas on submit
                function tSubmit(form)
                {
                var defaultedElements = document.getElementsByTagName("textarea");
                for (var i=0; i != defaultedElements.length; i++){
                if (defaultedElements[i].value == '<i18n:text>xmlui.dri2xhtml.default.textarea.value</i18n:text>'){
                defaultedElements[i].value='';}}
                }
                //Disable pressing 'enter' key to submit a form (otherwise pressing 'enter' causes a submission to start over)
                function disableEnterKey(e)
                {
                var key;

                if(window.event)
                key = window.event.keyCode;     //Internet Explorer
                else
                key = e.which;     //Firefox and Netscape

                if(key == 13)  //if "Enter" pressed, then disable!
                return false;
                else
                return true;
                }
            </script>

            <xsl:text disable-output-escaping="yes">&lt;!--[if lt IE 9]&gt;
                &lt;script src="</xsl:text><xsl:value-of select="concat($theme-path, 'vendor/html5shiv/dist/html5shiv.js')"/><xsl:text disable-output-escaping="yes">"&gt;&#160;&lt;/script&gt;
                &lt;script src="</xsl:text><xsl:value-of select="concat($theme-path, 'vendor/respond/dest/respond.min.js')"/><xsl:text disable-output-escaping="yes">"&gt;&#160;&lt;/script&gt;
                &lt;![endif]--&gt;</xsl:text>

            <!-- Modernizr enables HTML5 elements & feature detects -->
            <script src="{concat($theme-path, 'vendor/modernizr/modernizr.js')}">&#160;</script>
            <script src="{concat($theme-path, 'vendor/clipboard/clipboard.min.js')}">&#160;</script>

            <!-- Add the title in -->
            <xsl:variable name="page_title" select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='title'][last()]" />
            <title>
                <xsl:choose>
                    <xsl:when test="starts-with($request-uri, 'page/about')">
                        <i18n:text>xmlui.mirage2.page-structure.aboutThisRepository</i18n:text>
                    </xsl:when>
                    <xsl:when test="starts-with($request-uri, 'page/submit')">
                        <i18n:text>xmlui.mirage2.page-structure.submitWork</i18n:text>
                    </xsl:when>
                    <xsl:when test="not($page_title)">
                        <xsl:text>  </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="$page_title/node()" />
                    </xsl:otherwise>
                </xsl:choose>
            </title>

            <!-- Head metadata in item pages -->
            <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='xhtml_head_item']">
                <xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='xhtml_head_item']"
                              disable-output-escaping="yes"/>
            </xsl:if>

            <!-- Add all Google Scholar Metadata values -->
            <xsl:for-each select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[substring(@element, 1, 9) = 'citation_']">
                <meta name="{@element}" content="{.}"></meta>
            </xsl:for-each>

            <!-- Add MathJAX JS library to render scientific formulas-->
            <xsl:if test="confman:getProperty('webui.browse.render-scientific-formulas') = 'true'">
                <script type="text/x-mathjax-config">
                    MathJax.Hub.Config({
                      tex2jax: {
                        inlineMath: [['$','$'], ['\\(','\\)']],
                        ignoreClass: "detail-field-data|detailtable|exception"
                      },
                      TeX: {
                        Macros: {
                          AA: '{\\mathring A}'
                        }
                      }
                    });
                </script>
                <script type="text/javascript" src="//cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">&#160;</script>
            </xsl:if>

            <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.2/jquery.min.js"></script>
            <script src="//cdn.jsdelivr.net/bootstrap/3.3.5/js/bootstrap.min.js"></script>
            <script src="{concat($theme-path, 'scripts/uolibraries.js')}">&#160;</script>

        </head>
    </xsl:template>


    <!-- The header (distinct from the HTML head element) contains the title, subtitle, login box and various
        placeholders for header images -->
    <xsl:template name="buildHeader">
        <section id="uobannerandfooter-uoheader">
            <div class="uoheader-container container">
                <div class="uoheader-uologo-container">
                  <a href="http://uoregon.edu" rel="home"><!--img src="images/uologo@2x.png" title="University of Oregon" alt="University of Oregon" width="194" height="39" /-->
                    <img src="{$theme-path}/images/uosignature.svg" /></a>
                </div>
            </div>
        </section>
        <header class="uolib-header navbar navbar-default">
          <div class="navbar navbar-static-top">
            <div id="main-header">
              <div class="container">
                <a href="https://library.uoregon.edu">
                  <div id="uolibraries">
                    <img src="{$theme-path}/images/uolibraries.svg" />
                  </div>
                </a>
              </div>
                  <div class="container" style="position:relative">
                    <div class="navbar-collapse collapse" id="main-nav-collapse">
                    </div>
                    <!-- /.nav-collapse -->
              </div><!-- /container -->
            </div>

            <div class="container">
                <div class="navbar-header">

                    <button type="button" class="navbar-toggle" data-toggle="offcanvas">
                        <span class="sr-only">
                            <i18n:text>xmlui.mirage2.page-structure.toggleNavigation</i18n:text>
                        </span>
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                    </button>

                    <!--a href="{$context-path}/" class="navbar-brand">
                        <img src="{$theme-path}/images/DSpace-logo-line.svg" />
                    </a-->

                    <div class="navbar-header pull-right visible-xs hidden-sm hidden-md hidden-lg">
                    <ul class="nav nav-pills pull-left ">

                        <xsl:if test="count(/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='page'][@qualifier='supportedLocale']) &gt; 1">
                            <li id="ds-language-selection-xs" class="dropdown">
                                <xsl:variable name="active-locale" select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='page'][@qualifier='currentLocale']"/>
                                <button id="language-dropdown-toggle-xs" href="#" role="button" class="dropdown-toggle navbar-toggle navbar-link" data-toggle="dropdown">
                                    <b class="visible-xs glyphicon glyphicon-globe" aria-hidden="true"/>
                                </button>
                                <ul class="dropdown-menu pull-right" role="menu" aria-labelledby="language-dropdown-toggle-xs" data-no-collapse="true">
                                    <xsl:for-each
                                            select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='page'][@qualifier='supportedLocale']">
                                        <xsl:variable name="locale" select="."/>
                                        <li role="presentation">
                                            <xsl:if test="$locale = $active-locale">
                                                <xsl:attribute name="class">
                                                    <xsl:text>disabled</xsl:text>
                                                </xsl:attribute>
                                            </xsl:if>
                                            <a>
                                                <xsl:attribute name="href">
                                                    <xsl:value-of select="$current-uri"/>
                                                    <xsl:text>?locale-attribute=</xsl:text>
                                                    <xsl:value-of select="$locale"/>
                                                </xsl:attribute>
                                                <xsl:value-of
                                                        select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='supportedLocale'][@qualifier=$locale]"/>
                                            </a>
                                        </li>
                                    </xsl:for-each>
                                </ul>
                            </li>
                        </xsl:if>

                        <xsl:choose>
                            <xsl:when test="/dri:document/dri:meta/dri:userMeta/@authenticated = 'yes'">
                                <li class="dropdown">
                                    <button class="dropdown-toggle navbar-toggle navbar-link" id="user-dropdown-toggle-xs" href="#" role="button"  data-toggle="dropdown">
                                        <b class="visible-xs glyphicon glyphicon-user" aria-hidden="true"/>
                                    </button>
                                    <ul class="dropdown-menu pull-right" role="menu"
                                        aria-labelledby="user-dropdown-toggle-xs" data-no-collapse="true">
                                        <li>
                                            <a href="{/dri:document/dri:meta/dri:userMeta/
                        dri:metadata[@element='identifier' and @qualifier='url']}">
                                                <i18n:text>xmlui.EPerson.Navigation.profile</i18n:text>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="{/dri:document/dri:meta/dri:userMeta/
                        dri:metadata[@element='identifier' and @qualifier='logoutURL']}">
                                                <i18n:text>xmlui.dri2xhtml.structural.logout</i18n:text>
                                            </a>
                                        </li>
                                    </ul>
                                </li>
                            </xsl:when>
                            <xsl:otherwise>
                                <li>
                                    <form style="display: inline" action="{/dri:document/dri:meta/dri:userMeta/
                        dri:metadata[@element='identifier' and @qualifier='loginURL']}" method="get">
                                        <button class="navbar-toggle navbar-link">
                                        <b class="visible-xs glyphicon glyphicon-user" aria-hidden="true"/>
                                        </button>
                                    </form>
                                </li>
                            </xsl:otherwise>
                        </xsl:choose>
                    </ul>
                          </div>
                </div>
                <div class="navbar-header pull-right hidden-xs">
                    <ul class="nav navbar-nav pull-left">
                          <xsl:call-template name="languageSelection"/>
                    </ul>
                    <!--ul class="nav navbar-nav pull-left">
                        <xsl:choose>
                            <xsl:when test="/dri:document/dri:meta/dri:userMeta/@authenticated = 'yes'">
                                <li class="dropdown">
                                    <a id="user-dropdown-toggle" href="#" role="button" class="dropdown-toggle"
                                       data-toggle="dropdown">
                                        <span class="hidden-xs">
                                            <xsl:value-of select="/dri:document/dri:meta/dri:userMeta/
                        dri:metadata[@element='identifier' and @qualifier='firstName']"/>
                                            <xsl:text> </xsl:text>
                                            <xsl:value-of select="/dri:document/dri:meta/dri:userMeta/
                        dri:metadata[@element='identifier' and @qualifier='lastName']"/>
                                            &#160;
                                            <b class="caret"/>
                                        </span>
                                    </a>
                                    <ul class="dropdown-menu pull-right" role="menu"
                                        aria-labelledby="user-dropdown-toggle" data-no-collapse="true">
                                        <li>
                                            <a href="{/dri:document/dri:meta/dri:userMeta/
                        dri:metadata[@element='identifier' and @qualifier='url']}">
                                                <i18n:text>xmlui.EPerson.Navigation.profile</i18n:text>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="{/dri:document/dri:meta/dri:userMeta/
                        dri:metadata[@element='identifier' and @qualifier='logoutURL']}">
                                                <i18n:text>xmlui.dri2xhtml.structural.logout</i18n:text>
                                            </a>
                                        </li>
                                    </ul>
                                </li>
                            </xsl:when>
                            <xsl:otherwise>
                                <li>
                                    <a href="{/dri:document/dri:meta/dri:userMeta/
                        dri:metadata[@element='identifier' and @qualifier='loginURL']}">
                                        <span class="hidden-xs">
                                            <i18n:text>xmlui.dri2xhtml.structural.login</i18n:text>
                                        </span>
                                    </a>
                                </li>
                            </xsl:otherwise>
                        </xsl:choose>
                    </ul-->

                    <button data-toggle="offcanvas" class="navbar-toggle visible-sm" type="button">
                        <span class="sr-only"><i18n:text>xmlui.mirage2.page-structure.toggleNavigation</i18n:text></span>
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                    </button>
                </div>
            </div>
          </div>
        </header>

        <div id="main-nav">
          <div class="libmenu-wrap">
            <div class="container">
            <nav class="libmenu">
              <ul class="clearfix">
                <li>
                  <a href="#">Research Support <span class="caret"></span></a>
                    <ul class="sub-menu wider">
                      <li><a href="http://researchguides.uoregon.edu/getting-started" title="">Starting Library Research</a></li>
                      <li><a href="http://researchguides.uoregon.edu" title="">Research Guides</a></li>
                      <li><a href="https://library.uoregon.edu/specialists" title="">Subject Librarians</a></li>
                      <li><a href="https://library.uoregon.edu/digitalscholarship" title="">Digital Scholarship Center</a></li>
                      <li><a href="https://library.uoregon.edu/publishing-copyright" title="">Publishing &amp; Copyright</a></li>
                      <li><a href="https://library.uoregon.edu/datamanagement" title="">Research Data Management</a></li>
                      <li><a href="https://researchguides.uoregon.edu/student-success" title="">Study Skills &amp; Campus Resources</a></li>
                      <li><a href="https://library.uoregon.edu/collection-development/order-form" title="">Request a Purchase</a></li>
                    </ul></li>
                <li>
                  <a href="#">Using the Libraries <span class="caret"></span></a>
                    <ul class="sub-menu wider">
                      <li><a href="https://library.uoregon.edu/rooms-study-spaces" title="">Rooms &amp; Study Spaces</a></li>
                      <li><a href="https://library.uoregon.edu/borrowing" title="">Borrowing &amp; Requesting</a></li>
                      <li><a href="https://library.uoregon.edu/connect" title="">Connect from Off-campus</a></li>
                      <li><a href="https://library.uoregon.edu/borrowing/ill" title="">ILL (Interlibrary Loan)</a></li>
                      <li><a href="https://library.uoregon.edu/course-reserves" title="">Course Reserves</a></li>
                      <li><a href="https://library.uoregon.edu/technology" title="">Technology, Printing, &amp; Scanning</a></li>
                      <li><a href="https://library.uoregon.edu/tutoring" title="">Tutoring at the UO Libraries</a></li>
                      <li><a href="https://library.uoregon.edu/cmet/classrooms" title="">Classroom Technology Support</a></li>
                      <li><a href="https://library.uoregon.edu/cmet/canvas" title="">Canvas Support</a></li>
                      <li><a href="https://library.uoregon.edu/library-accessibility" title="">Accessibility</a></li>
                    </ul></li>
                <li>
                  <a href="#">Collections <span class="caret"></span></a>
                    <ul class="sub-menu widest">
                      <li><a href="http://researchguides.uoregon.edu/az.php" title="">Databases A-Z</a></li>
                      <li><a href="https://scholarsbank.uoregon.edu" title="">Scholars' Bank</a></li>
                      <li><a href="https://library.uoregon.edu/resources/videos-music-photos" title="">Videos, Music, Photos</a></li>
                      <li><a href="https://library.uoregon.edu/special-collections" title="">Special Collections &amp; University Archives</a></li>
                      <li><a href="https://library.uoregon.edu/unique-collections" title="">Unique Collections</a></li>
                      <li><a href="https://library.uoregon.edu/govdocs/govinfo" title="">Government Documents</a></li>
                      <li><a href="/map-library" title="">Maps &amp; Aerial Photography</a></li>
                      <li><a href="http://oregondigital.org/catalog/" title="">Oregon Digital</a></li>
                      <li><a href="http://oregonnews.uoregon.edu/" title="">Oregon Newspapers</a></li>
                    </ul></li>
                <li>
                  <a href="#">Library Accounts <span class="caret"></span></a>
                    <ul class="sub-menu wider">
                      <li><a href="http://alliance-primo.hosted.exlibrisgroup.com/primo_library/libweb/action/myAccountMenu.do?vid=UO" title="">LibrarySearch Account</a></li>
                      <li><a href="https://illiad.uoregon.edu/illiad/oru/logon.html" title="">ILLiad Account (Interlibrary Loan)</a></li>
                      <li><a href="http://www.myendnoteweb.com/EndNoteWeb/1.1/release/EndNoteWeb.html?Init=Yes&amp;amp;SrcApp=CR&amp;amp;returnCode=ROUTER.Success&amp;amp;SID=E1p7AHdjCADhID7d1hE" title="">Endnote Web (Citation Manager)</a></li>
                    </ul></li>
                <li>
                  <a href="#">About <span class="caret"></span></a>
                    <ul class="sub-menu widest">
                      <li><a href="https://library.uoregon.edu/hours-and-locations" title="">Hours &amp; Locations</a></li>
                      <li><a href="https://library.uoregon.edu/directory/az" title="">Staff &amp; Department Directory</a></li>
                      <li><a href="https://library.uoregon.edu/communications" title="">News &amp; Events</a></li>
                      <li><a href="https://library.uoregon.edu/calendar" title="">Calendar</a></li>
                      <li><a href="https://library.uoregon.edu/general/about/mission" title="">Mission, Values, &amp; Strategic Directions</a></li>
                      <li><a href="https://library.uoregon.edu/diversity" title="">Diversity &amp; Inclusion</a></li>
                      <li><a href="https://library.uoregon.edu/policies" title="">Policies</a></li>
                      <li><a href="https://library.uoregon.edu/jobs" title="">Jobs</a></li>
                      <li><a href="https://library.uoregon.edu/contact" title="">Comments &amp; Suggestions</a></li>
                    </ul></li>
                <li>
                  <a href="#">Chat/Ask Us <span class="caret"></span></a>
                    <ul class="sub-menu">
                      <li><a href="https://library.uoregon.edu/pubsrvc/emailrefq.html" title="">Email</a></li>
                      <li><a href="https://library.uoregon.edu/ask" title="">Phone</a></li>
                      <li><a href="https://library.uoregon.edu/ask" title="">Text</a></li>
                    </ul>
                  </li>
                </ul>
              </nav>
            </div>
          </div>
        </div>
    </xsl:template>


    <!-- The header (distinct from the HTML head element) contains the title, subtitle, login box and various
        placeholders for header images -->
    <xsl:template name="buildTrail">
        <div class="trail-wrapper hidden-print">
            <div class="container">
                <div class="row">
                    <!--TODO-->
                    <div class="col-xs-9">
                        <xsl:choose>
                            <xsl:when test="count(/dri:document/dri:meta/dri:pageMeta/dri:trail) > 1">
                                <div class="breadcrumb dropdown visible-xs">
                                    <a id="trail-dropdown-toggle" href="#" role="button" class="dropdown-toggle"
                                       data-toggle="dropdown">
                                        <xsl:variable name="last-node"
                                                      select="/dri:document/dri:meta/dri:pageMeta/dri:trail[last()]"/>
                                        <xsl:choose>
                                            <xsl:when test="$last-node/i18n:*">
                                                <xsl:apply-templates select="$last-node/*"/>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:apply-templates select="$last-node/text()"/>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                        <xsl:text>&#160;</xsl:text>
                                        <b class="caret"/>
                                    </a>
                                    <ul class="dropdown-menu" role="menu" aria-labelledby="trail-dropdown-toggle">
                                        <xsl:apply-templates select="/dri:document/dri:meta/dri:pageMeta/dri:trail"
                                                             mode="dropdown"/>
                                    </ul>
                                </div>
                                <ul class="breadcrumb hidden-xs">
                                    <xsl:apply-templates select="/dri:document/dri:meta/dri:pageMeta/dri:trail"/>
                                </ul>
                            </xsl:when>
                            <xsl:when test="starts-with($request-uri, 'page/about')">
                                <ul class="breadcrumb">
                                    <xsl:text>About Scholars' Bank</xsl:text>
                                </ul>
                            </xsl:when>
                            <xsl:when test="starts-with($request-uri, 'page/submit')">
                              <ul class="breadcrumb">
                                <xsl:text>Submit Work</xsl:text>
                              </ul>
                            </xsl:when>
                            <xsl:otherwise>
                                <ul class="breadcrumb">
                                    <xsl:apply-templates select="/dri:document/dri:meta/dri:pageMeta/dri:trail"/>
                                </ul>
                            </xsl:otherwise>
                        </xsl:choose>
                    </div>
                    <div class="col-xs-3">
                      <!--a href="/xmlui/">
                        <img src="{$theme-path}/images/frontlogo.svg" />
                      </a-->
                    </div>
                </div>
            </div>
        </div>


    </xsl:template>

    <!--The Trail-->
    <xsl:template match="dri:trail">
        <!--put an arrow between the parts of the trail-->
        <li>
            <xsl:if test="position()=1">
                <i class="glyphicon glyphicon-home" aria-hidden="true"/>&#160;
            </xsl:if>
            <!-- Determine whether we are dealing with a link or plain text trail link -->
            <xsl:choose>
                <xsl:when test="./@target">
                    <a>
                        <xsl:attribute name="href">
                            <xsl:value-of select="./@target"/>
                        </xsl:attribute>
                        <xsl:apply-templates />
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:attribute name="class">active</xsl:attribute>
                    <xsl:apply-templates />
                </xsl:otherwise>
            </xsl:choose>
        </li>
    </xsl:template>

    <xsl:template match="dri:trail" mode="dropdown">
        <!--put an arrow between the parts of the trail-->
        <li role="presentation">
            <!-- Determine whether we are dealing with a link or plain text trail link -->
            <xsl:choose>
                <xsl:when test="./@target">
                    <a role="menuitem">
                        <xsl:attribute name="href">
                            <xsl:value-of select="./@target"/>
                        </xsl:attribute>
                        <xsl:if test="position()=1">
                            <i class="glyphicon glyphicon-home" aria-hidden="true"/>&#160;
                        </xsl:if>
                        <xsl:apply-templates />
                    </a>
                </xsl:when>
                <xsl:when test="position() > 1 and position() = last()">
                    <xsl:attribute name="class">disabled</xsl:attribute>
                    <a role="menuitem" href="#">
                        <xsl:apply-templates />
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:attribute name="class">active</xsl:attribute>
                    <xsl:if test="position()=1">
                        <i class="glyphicon glyphicon-home" aria-hidden="true"/>&#160;
                    </xsl:if>
                    <xsl:apply-templates />
                </xsl:otherwise>
            </xsl:choose>
        </li>
    </xsl:template>

    <!--The License-->
    <xsl:template name="cc-license">
        <xsl:param name="metadataURL"/>
        <xsl:variable name="externalMetadataURL">
            <xsl:text>cocoon:/</xsl:text>
            <xsl:value-of select="$metadataURL"/>
            <xsl:text>?sections=dmdSec,fileSec&amp;fileGrpTypes=THUMBNAIL</xsl:text>
        </xsl:variable>

        <xsl:variable name="ccLicenseName"
                      select="document($externalMetadataURL)//dim:field[@element='rights']"
                />
        <xsl:variable name="ccLicenseUri"
                      select="document($externalMetadataURL)//dim:field[@element='rights'][@qualifier='uri']"
                />
        <xsl:variable name="handleUri">
            <xsl:for-each select="document($externalMetadataURL)//dim:field[@element='identifier' and @qualifier='uri']">
                <a>
                    <xsl:attribute name="href">
                        <xsl:copy-of select="./node()"/>
                    </xsl:attribute>
                    <xsl:copy-of select="./node()"/>
                </a>
                <xsl:if test="count(following-sibling::dim:field[@element='identifier' and @qualifier='uri']) != 0">
                    <xsl:text>, </xsl:text>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>

        <xsl:if test="$ccLicenseName and $ccLicenseUri and contains($ccLicenseUri, 'creativecommons')">
            <div about="{$handleUri}" class="row">
            <div class="col-sm-3 col-xs-12">
                <a rel="license"
                   href="{$ccLicenseUri}"
                   alt="{$ccLicenseName}"
                   title="{$ccLicenseName}"
                        >
                    <xsl:call-template name="cc-logo">
                        <xsl:with-param name="ccLicenseName" select="$ccLicenseName"/>
                        <xsl:with-param name="ccLicenseUri" select="$ccLicenseUri"/>
                    </xsl:call-template>
                </a>
            </div> <div class="col-sm-8">
                <span>
                    <i18n:text>xmlui.dri2xhtml.METS-1.0.cc-license-text</i18n:text>
                    <xsl:value-of select="$ccLicenseName"/>
                </span>
            </div>
            </div>
        </xsl:if>
    </xsl:template>

    <xsl:template name="cc-logo">
        <xsl:param name="ccLicenseName"/>
        <xsl:param name="ccLicenseUri"/>
        <xsl:variable name="ccLogo">
             <xsl:choose>
                  <xsl:when test="starts-with($ccLicenseUri,
                                           'http://creativecommons.org/licenses/by/')">
                       <xsl:value-of select="'cc-by.png'" />
                  </xsl:when>
                  <xsl:when test="starts-with($ccLicenseUri,
                                           'http://creativecommons.org/licenses/by-sa/')">
                       <xsl:value-of select="'cc-by-sa.png'" />
                  </xsl:when>
                  <xsl:when test="starts-with($ccLicenseUri,
                                           'http://creativecommons.org/licenses/by-nd/')">
                       <xsl:value-of select="'cc-by-nd.png'" />
                  </xsl:when>
                  <xsl:when test="starts-with($ccLicenseUri,
                                           'http://creativecommons.org/licenses/by-nc/')">
                       <xsl:value-of select="'cc-by-nc.png'" />
                  </xsl:when>
                  <xsl:when test="starts-with($ccLicenseUri,
                                           'http://creativecommons.org/licenses/by-nc-sa/')">
                       <xsl:value-of select="'cc-by-nc-sa.png'" />
                  </xsl:when>
                  <xsl:when test="starts-with($ccLicenseUri,
                                           'http://creativecommons.org/licenses/by-nc-nd/')">
                       <xsl:value-of select="'cc-by-nc-nd.png'" />
                  </xsl:when>
                  <xsl:when test="starts-with($ccLicenseUri,
                                           'http://creativecommons.org/publicdomain/zero/')">
                       <xsl:value-of select="'cc-zero.png'" />
                  </xsl:when>
                  <xsl:when test="starts-with($ccLicenseUri,
                                           'http://creativecommons.org/publicdomain/mark/')">
                       <xsl:value-of select="'cc-mark.png'" />
                  </xsl:when>
                  <xsl:otherwise>
                       <xsl:value-of select="'cc-generic.png'" />
                  </xsl:otherwise>
             </xsl:choose>
        </xsl:variable>
        <img class="img-responsive">
             <xsl:attribute name="src">
                <xsl:value-of select="concat($theme-path,'/images/creativecommons/', $ccLogo)"/>
             </xsl:attribute>
             <xsl:attribute name="alt">
                 <xsl:value-of select="$ccLicenseName"/>
             </xsl:attribute>
        </img>
    </xsl:template>

    <!-- Like the header, the footer contains various miscellaneous text, links, and image placeholders -->
    <xsl:template name="buildFooter">
      <footer>
        <div class="row">
          <div class="region region-page-bottom">
            <section id="uobannerandfooter-uoankle">
              <div class="uoankle-container container">
                <div class="col-xs-16 col-sm-16 col-md-12">
                  <div class="row">

                    <div class="grid-item col-md-3">
                        <h3>CAMPUS</h3>
                        <ul>
                          <li><a href="http://around.uoregon.edu/">News</a></li>
                          <li><a href="http://calendar.uoregon.edu/">Events</a></li>
                          <li><a href="//uoregon.edu/maps">Maps</a></li>
                          <li><a href="//uoregon.edu/directions">Directions</a></li>
                          <li><a href="http://classes.uoregon.edu/">Class Schedule</a></li>
                          <li><a href="http://registrar.uoregon.edu/calendars/academic">Academic Calendar</a></li>
                        </ul>
                      </div>
                    <div class="grid-item col-md-3">
                        <h3>RESOURCES</h3>
                        <ul>
                          <li><a href="https://webmail.uoregon.edu/">Webmail</a></li>
                          <li><a href="https://canvas.uoregon.edu/">Canvas</a></li>
                          <li><a href="https://duckweb.uoregon.edu/">Duckweb</a></li>
                          <li><a href="//uoregon.edu/findpeople">Find People</a></li>
                          <li><a href="//uoregon.edu/azindex">A–Z Index</a></li>
                          <li><a href="http://library.uoregon.edu/">UO Libraries</a></li>
                        </ul>
                      </div>
                    <div class="grid-item col-md-3">
                        <h3>RELATED INFORMATION</h3>
                        <ul>
                          <li><a href="">Library Accessibility</a></li>
                          <li><a href="">Privacy Policy</a></li>
                          <li><a href="">Giving</a></li>
                        </ul>
                      </div>
                    <div class="grid-item col-md-3">
                      <div class="uoankle-contact-info">
                        <div itemscope="" itemtype="http://schema.org/Organization">
                          <span itemprop="name"><strong>UO Libraries</strong></span><br/>
                          <div itemprop="address" itemscope="" itemtype="http://schema.org/PostalAddress">
                            <span itemprop="streetAddress">1501 Kincaid Street</span><br/>
                            <span itemprop="streetAddress">1239 University of Oregon</span><br/>
                            <span itemprop="addressLocality">Eugene</span>, <span itemprop="addressRegion">OR </span>
                            <span itemprop="postalCode">97403-1299</span>
                          </div>
                          <p><span class="uoankle-phone-fax">P: <span itemprop="telephone">541-346-3134</span></span></p>

                          <p><a class="socialicon-facebook" href="http://www.facebook.com/uolibraries" title="Facebook" rel="me" itemprop="sameAs">Facebook</a><a class="socialicon-twitter" href="http://twitter.com/uoregonlibnews" title="Twitter" rel="me" itemprop="sameAs">Twitter</a>
                          <a class="socialicon-youtube" href="https://www.youtube.com/c/uolibrarieseugene" title="YouTube" rel="me" itemprop="sameAs">YouTube</a><a class="socialicon-instagram" href="http://instagram.com/uoregonlibraries#" title="Instagram" rel="me" itemprop="sameAs">Instagram</a><link itemprop="url" style="visibility:hidden;" itemscope="http://uonews.uoregon.edu" /></p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="uoankle-contact-info-container">

                </div>
                <p>
                  <link itemprop="url" itemscope="http://library.uoregon.edu" style="visibility:hidden;" />
                </p>
              </div>














            </section>

            <section id="uobannerandfooter-uofooter">
              <div id="uobannerandfooter-uofooter">
                <div class="uofooter-container" style="max-width: 1200px; margin: 0 auto;">
                  <div class="uofooter-links-and-logo-container">
                  <div class="uofooter-links-container">
                  <span class="uofooter-link"><a href="http://hr.uoregon.edu/jobs/available-positions">Careers</a></span><span class="uofooter-link"><a href="http://registrar.uoregon.edu/records-privacy">Privacy Policy</a></span><span class="uofooter-link"><a href="http://uoregon.edu/about">About</a></span><span class="uofooter-link"><a href="http://uoregon.edu/findpeople/">Find People</a></span>
                  </div>
                  <div class="uofooter-logo-container">
                  <a href="http://uoregon.edu"><img src="{$theme-path}/images/footer-logo.png" alt="University of Oregon" title="University of Oregon" width="75" height="61" /></a>
                  </div>
                  <div class="uofooter-copyright-container">
                  <span class="copyright"><span class="copyright-symbol">©</span> <a href="http://uoregon.edu">University of Oregon</a>. </span><span class="all-rights-reserved">All Rights Reserved.</span>
                  </div>
                  </div>
                  <div class="uofooter-legal-container">
                  <p><abbr title="University of Oregon">UO</abbr> prohibits discrimination on the basis of race, color, sex, national or ethnic origin, age, religion, marital status, disability, veteran status, sexual orientation, gender identity, and gender expression in all programs, activities and employment practices as required by Title IX, other applicable laws, and policies. Retaliation is prohibited by <abbr title="University of Oregon">UO</abbr> policy. Questions may be referred to the Title IX Coordinator, Office of Affirmative Action and Equal Opportunity, or to the Office for Civil Rights. Contact information, related policies, and complaint procedures are listed on the <a href="http://studentlife.uoregon.edu/nondiscrimination">statement of non-discrimination</a>.
                  </p>
                  </div>
                </div>
              </div>
            </section>
            </div>
          </div>

          <!--/div-->
          <!--hr/-->
          <!--div class="col-xs-7 col-sm-8">
              <div-->
                  <!--a href="http://www.dspace.org/" target="_blank">DSpace software</a> copyright&#160;&#169;&#160;2002-2015&#160; <a href="http://www.duraspace.org/" target="_blank">DuraSpace</a-->
              <!--/div>
              <div class="hidden-print"-->
                  <!--a>
                      <xsl:attribute name="href">
                          <xsl:value-of
                                  select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='contextPath'][not(@qualifier)]"/>
                          <xsl:text>/contact</xsl:text>
                      </xsl:attribute>
                      <i18n:text>xmlui.dri2xhtml.structural.contact-link</i18n:text>
                  </a>
                  <xsl:text> | </xsl:text>
                  <a>
                      <xsl:attribute name="href">
                          <xsl:value-of
                                  select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='contextPath'][not(@qualifier)]"/>
                          <xsl:text>/feedback</xsl:text>
                      </xsl:attribute>
                      <i18n:text>xmlui.dri2xhtml.structural.feedback-link</i18n:text>
                  </a-->
            <!--div class="col-xs-5 col-sm-4 hidden-print">
                <div class="pull-right"-->
                    <!--span class="theme-by">Theme by&#160;</span>
                    <br/>
                    <a title="@mire NV" target="_blank" href="http://atmire.com">
                        <img alt="@mire NV" src="{concat($theme-path, '/images/@mirelogo-small.png')}"/>
                    </a-->
                <!--/div>
            </div-->
        <!--/div-->
        <!--Invisible link to HTML sitemap (for search engines) -->
        <a class="hidden">
            <xsl:attribute name="href">
                <xsl:value-of
                        select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='contextPath'][not(@qualifier)]"/>
                <xsl:text>/htmlmap</xsl:text>
            </xsl:attribute>
            <xsl:text>&#160;</xsl:text>
        </a>
      </footer>

      <script>
        jQuery(document).ready(function($){
            /*jQuery('.community-browser-wrapper > .killnumber a[name="community-browser-link"]').each(function() {
                var currentElement = $(this).text();
                currentElement = currentElement.substring(3,currentElement.length);
                $(this).text(currentElement);
            });*/

            /*
            $(".nav-tabs a").click(function(){
                $(this).tab('show');
            });
            */

            $("#catalog-search .nav-tabs a").click(function( event ) {
                //event.preventDefault();
                $(this).tab('show');
                history.pushState(null, null, $(event.target).attr("href"));
                console.log('prevent tab anchor 3');
            });
            //$('#catalog-search .nav-tabs a[href="' + window.location.hash + '"]').tab('show');

            $('.nav-tabs a').on('shown.bs.tab', function(event){
                var x = $(event.target).text();         // active tab
                var y = $(event.relatedTarget).text();  // previous tab
                $(".act span").text(x);
                $(".prev span").text(y);
            });

            $( "#librarySearchForm" ).submit(function( event ) {

                    primoQueryTemp =  $("#primoQueryTemp").val();

                    var pindex = $("#primoIndex").val();
                    //var primoQueryTemp = $("#primoQueryTemp").val();
                    $("#primoQuery").val( pindex + ",contains," + primoQueryTemp );
            });

            $( "#articlesSearchForm" ).submit(function( event ) {

                    articleQueryTemp =  $("#articleQueryTemp").val();
                    var pindex = $("#articleIndex").val();
                    //var articleQueryTemp = $("#articleQueryTemp").val();

                    $("#articleQuery").val( pindex + ",contains," + articleQueryTemp );
            });

            var randomSlide = Math.floor(Math.random() * $('#resources-slideshow .item').size());
            $('#resources-slideshow').carousel(randomSlide);
            $('#resources-slideshow').carousel('pause');


            $('.carousel').each(function(){
                $(this).carousel({
                    interval: false
                });
            });

        });
        </script>

        <script>
          (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
          (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
          m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
          })(window,document,'script','https://www.google-analytics.com/analytics.js','ga');

          ga('create', 'UA-9568253-1', 'auto');
          ga('send', 'pageview');

        </script>

    </xsl:template>


    <!--
            The meta, body, options elements; the three top-level elements in the schema
    -->




    <!--
        The template to handle the dri:body element. It simply creates the ds-body div and applies
        templates of the body's child elements (which consists entirely of dri:div tags).
    -->
    <xsl:template match="dri:body">
        <div>
            <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='alert'][@qualifier='message']">
                <div class="alert">
                    <button type="button" class="close" data-dismiss="alert">&#215;</button>
                    <xsl:copy-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='alert'][@qualifier='message']/node()"/>
                </div>
            </xsl:if>

            <!-- Check for the custom pages -->
            <xsl:choose>
                <xsl:when test="starts-with($request-uri, 'page/about')">
                    <div class="hero-unit">
                        <h1><i18n:text>xmlui.mirage2.page-structure.heroUnit.title</i18n:text></h1>
                        <p><i18n:text>xmlui.mirage2.page-structure.heroUnit.content</i18n:text></p>
                    </div>
                </xsl:when>
                <xsl:when test="starts-with($request-uri, 'page/submit')">
                    <div class="hero-unit2">
                        <h1><i18n:text>xmlui.mirage2.page-structure.heroUnit2.title</i18n:text></h1>
                        <p><i18n:text>xmlui.mirage2.page-structure.heroUnit2.content</i18n:text></p>
                    </div>
                </xsl:when>
                <!--xsl:when test="starts-with($request-uri, 'page/')">
                    <div class="hero-unit">
                        <h1><i18n:text>xmlui.mirage2.page-structure.heroUnit.title</i18n:text></h1>
                        <p><i18n:text>xmlui.mirage2.page-structure.heroUnit.content</i18n:text></p>
                    </div>
                </xsl:when>
                <xsl:when test="starts-with($request-uri, 'about/')">
                    <div class="hero-unit">
                        <h1><i18n:text>xmlui.mirage2.page-structure.heroUnit.title</i18n:text></h1>
                        <p><i18n:text>xmlui.mirage2.page-structure.heroUnit.content</i18n:text></p>
                    </div>
                </xsl:when-->
                <!--xsl:when test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='request'][@qualifier='URI']='about'">
                    <div>
                        <h1>About us</h1>
                        <p>Lorem Ipsum dolor sit amet</p>
                    </div>
                </xsl:when>
                <xsl:when test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='request'][@qualifier='URI']='faq'">
                    <xsl:copy-of select="document('faq.xml')" />
                </xsl:when-->

                <!-- Otherwise use default handling of body -->
                <xsl:otherwise>

                    <!--a href="{$context-path}/" class="navbar-brand">
                        <img src="{$theme-path}/images/DSpace-logo-line.svg" />
                    </a>
                    <br /!-->

                    <xsl:apply-templates />

                    <!--xsl:apply-templates select="*[@n='item-related-container']"/>
                    <xsl:apply-templates select="*[not(@n='item-related-container')]"/-->

                </xsl:otherwise>
            </xsl:choose>

        </div>
    </xsl:template>


    <!--
        The template to handle the dri:body element. It simply creates the ds-body div and applies
        templates of the body's child elements (which consists entirely of dri:div tags).
    -->
    <xsl:template match="dri:body">
        <div id="ds-body">
            <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='alert'][@qualifier='message']">
                <div id="ds-system-wide-alert">
                    <p>
                        <xsl:copy-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='alert'][@qualifier='message']/node()"/>
                    </p>
                </div>
            </xsl:if>

            <!-- Check for the custom pages -->
            <xsl:choose>
                <xsl:when test="starts-with($request-uri, 'page/about')">
                    <div>
                      <h2>About This Repository</h2>
                      <p>To add your own content to this page, edit webapps/xmlui/themes/Mirage/lib/xsl/core/page-structure.xsl and add your own content to the title, trail, and body. If you wish to add additional pages, you will need to create an additional xsl:when block and match the request-uri to whatever page you are adding. Currently, static pages created through altering XSL are only available under the URI prefix of page/.</p>
                    </div>
                </xsl:when>
                <xsl:when test="starts-with($request-uri, 'page/submit')">
                    <div>
                      <!--h1 class="dept_header">Scholars&#39; Bank</h1-->
                      <h2>Submitting Work</h2>
                      <p>The Scholars&#39; Bank archive is divided into &quot;communities&quot; corresponding to different organizations or academic departments on campus. Communities are divided into &quot;collections&quot; which contain individual items.</p>

                      <h3>Background &amp; Basic Steps</h3>
                      <ol>
                        <li>While most submissions are made by Scholars&#39; Bank staff or a departmental representative, anyone who is a registered member of an established community in Scholars&#39; Bank may submit appropriate materials to the community&#39;s collections.</li>
                        <li>To register for the first time, a user should click on the <a href="https://scholarsbank.uoregon.edu/xmlui/register">Register</a> link and supply his or her complete email address, such as myself@uoregon.edu. First-time users will receive an email enabling them to select a password for signing in.</li>
                        <li>After accessing the desired collection, the user may proceed with the submission, supplying information in the submission form and uploading files when prompted. Submitters will also be prompted to provide descriptive information (metadata) that will help search engines and other researchers locate their work.</li>
                        <li>For assistance submitting materials to the archive, contact us at <a href="mailto:scholars@uoregon.edu">scholars@uoregon.edu</a>. A brief training session for your departmental representative or other submitters can be arranged. You may also request that submissions be handled by library staff.</li>
                        <li>Some collections require that new submissions be reviewed by a member of the sponsoring community. In that case, individual users will see their submissions appear in Scholars&#39; Bank after review.</li>
                      </ol>
                      <h3>Feedback &amp; Follow-up</h3>
                      <p>To ensure the long-term success of the archive, we require your feedback on how it works and what issues are important to you. You can send your comments by email to <a href="mailto:scholars@uoregon.edu">scholars@uoregon.edu</a>.</p>
                      <p>Thank you for contributing to Scholars&#39; Bank.</p>
                      <p>Questions? Contact <a href="mailto:scholars@uoregon.edu">scholars@uoregon.edu</a> or visit the <a href="http://library.uoregon.edu/digitalscholarship">Digital Scholarship Center</a>.</p>
                    </div>
                </xsl:when>
                <!-- Otherwise use default handling of body -->
                <xsl:otherwise>
                    <xsl:apply-templates />
                </xsl:otherwise>
            </xsl:choose>

        </div>
    </xsl:template>

    <!-- Currently the dri:meta element is not parsed directly. Instead, parts of it are referenced from inside
        other elements (like reference). The blank template below ends the execution of the meta branch -->
    <xsl:template match="dri:meta">
    </xsl:template>

    <!-- Meta's children: userMeta, pageMeta, objectMeta and repositoryMeta may or may not have templates of
        their own. This depends on the meta template implementation, which currently does not go this deep.
    <xsl:template match="dri:userMeta" />
    <xsl:template match="dri:pageMeta" />
    <xsl:template match="dri:objectMeta" />
    <xsl:template match="dri:repositoryMeta" />
    -->

    <xsl:template name="addJavascript">

        <!--TODO concat & minify!-->

        <script>
            <xsl:text>if(!window.DSpace){window.DSpace={};}window.DSpace.context_path='</xsl:text><xsl:value-of select="$context-path"/><xsl:text>';window.DSpace.theme_path='</xsl:text><xsl:value-of select="$theme-path"/><xsl:text>';</xsl:text>
        </script>

        <!--inject scripts.html containing all the theme specific javascript references
        that can be minified and concatinated in to a single file or separate and untouched
        depending on whether or not the developer maven profile was active-->
        <xsl:variable name="scriptURL">
            <xsl:text>cocoon://themes/</xsl:text>
            <!--we can't use $theme-path, because that contains the context path,
            and cocoon:// urls don't need the context path-->
            <xsl:value-of select="$pagemeta/dri:metadata[@element='theme'][@qualifier='path']"/>
            <xsl:text>scripts-dist.xml</xsl:text>
        </xsl:variable>
        <xsl:for-each select="document($scriptURL)/scripts/script">
            <script src="{$theme-path}{@src}">&#160;</script>
        </xsl:for-each>

        <!-- Add javascipt specified in DRI -->
        <xsl:for-each select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='javascript'][not(@qualifier)]">
            <script>
                <xsl:attribute name="src">
                    <xsl:value-of select="$theme-path"/>
                    <xsl:value-of select="."/>
                </xsl:attribute>&#160;</script>
        </xsl:for-each>

        <!-- add "shared" javascript from static, path is relative to webapp root-->
        <xsl:for-each select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='javascript'][@qualifier='static']">
            <!--This is a dirty way of keeping the scriptaculous stuff from choice-support
            out of our theme without modifying the administrative and submission sitemaps.
            This is obviously not ideal, but adding those scripts in those sitemaps is far
            from ideal as well-->
            <xsl:choose>
                <xsl:when test="text() = 'static/js/choice-support.js'">
                    <script>
                        <xsl:attribute name="src">
                            <xsl:value-of select="$theme-path"/>
                            <xsl:text>js/choice-support.js</xsl:text>
                        </xsl:attribute>&#160;</script>
                </xsl:when>
                <xsl:when test="not(starts-with(text(), 'static/js/scriptaculous'))">
                    <script>
                        <xsl:attribute name="src">
                            <xsl:value-of
                                    select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='contextPath'][not(@qualifier)]"/>
                            <xsl:text>/</xsl:text>
                            <xsl:value-of select="."/>
                        </xsl:attribute>&#160;</script>
                </xsl:when>
            </xsl:choose>
        </xsl:for-each>

        <!-- add setup JS code if this is a choices lookup page -->
        <xsl:if test="dri:body/dri:div[@n='lookup']">
            <xsl:call-template name="choiceLookupPopUpSetup"/>
        </xsl:if>

        <!-- Add a google analytics script if the key is present -->
        <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='google'][@qualifier='analytics']">
            <script><xsl:text>
                  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
                  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
                  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
                  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

                  ga('create', '</xsl:text><xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='google'][@qualifier='analytics']"/><xsl:text>', '</xsl:text><xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='request'][@qualifier='serverName']"/><xsl:text>');
                  ga('send', 'pageview');
           </xsl:text></script>
        </xsl:if>
    </xsl:template>

    <!-- Hides the Community List from the Homepage -->
    <xsl:template name="hide_homepage_community-list" match="dri:div[@id='aspect.artifactbrowser.CommunityBrowser.div.comunity-browser']">

      <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='title']='xmlui.general.dspace_home'">


      <style>
        ul.breadcrumb {
          display: none;
        }

        h2.first-page-header, #file_news_div_news {
          display: none !important;
        }

      </style>

      <div class="frontlogo">
        <a>
            <xsl:attribute name="href">
                <xsl:value-of
                        select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='contextPath'][not(@qualifier)]"/>
                <xsl:text>/</xsl:text>
            </xsl:attribute>
            <img src="{$theme-path}/images/frontlogo.svg" />
        </a>

      </div>

      </xsl:if>

      <div id="ds-search-option" class="ds-option-set">
          <!-- The form, complete with a text box and a button, all built from attributes referenced
       from under pageMeta. -->
          <form id="ds-search-form" class="" method="post">
              <xsl:attribute name="action">
                  <xsl:value-of select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='contextPath']"/>
                  <xsl:value-of
                          select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='search'][@qualifier='simpleURL']"/>
              </xsl:attribute>
              <fieldset>
                  <div class="input-group">
                      <input class="ds-text-field form-control" type="text" placeholder="xmlui.general.search"
                             i18n:attr="placeholder">
                          <xsl:attribute name="name">
                              <xsl:value-of
                                      select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='search'][@qualifier='queryField']"/>
                          </xsl:attribute>
                      </input>
                      <span class="input-group-btn">
                          <button class="btn btn-rounded btn-flat-primary" title="xmlui.general.go" i18n:attr="title">
                              <span class="label" value="Submit search"></span>
                              <span class="glyphicon glyphicon-search" aria-hidden="true"/>
                              <xsl:attribute name="onclick">
                                          <xsl:text>
                                              var radio = document.getElementById(&quot;ds-search-form-scope-container&quot;);
                                              if (radio != undefined &amp;&amp; radio.checked)
                                              {
                                              var form = document.getElementById(&quot;ds-search-form&quot;);
                                              form.action=
                                          </xsl:text>
                                  <xsl:text>&quot;</xsl:text>
                                  <xsl:value-of
                                          select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='contextPath']"/>
                                  <xsl:text>/handle/&quot; + radio.value + &quot;</xsl:text>
                                  <xsl:value-of
                                          select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='search'][@qualifier='simpleURL']"/>
                                  <xsl:text>&quot; ; </xsl:text>
                                          <xsl:text>
                                              }
                                          </xsl:text>
                              </xsl:attribute>
                          </button>
                      </span>
                  </div>

                  <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='focus'][@qualifier='container']">
                      <div class="radio">
                          <label>
                              <input id="ds-search-form-scope-all" type="radio" name="scope" value=""
                                     checked="checked"/>
                              <i18n:text>xmlui.dri2xhtml.structural.search</i18n:text>
                          </label>
                      </div>
                      <div class="radio">
                          <label>
                              <input id="ds-search-form-scope-container" type="radio" name="scope">
                                  <xsl:attribute name="value">
                                      <xsl:value-of
                                              select="substring-after(/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='focus'][@qualifier='container'],':')"/>
                                  </xsl:attribute>
                              </input>
                              <xsl:choose>
                                  <xsl:when
                                          test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='focus'][@qualifier='containerType']/text() = 'type:community'">
                                      <i18n:text>xmlui.dri2xhtml.structural.search-in-community</i18n:text>
                                  </xsl:when>
                                  <xsl:otherwise>
                                      <i18n:text>xmlui.dri2xhtml.structural.search-in-collection</i18n:text>
                                  </xsl:otherwise>

                              </xsl:choose>
                          </label>
                      </div>
                  </xsl:if>
              </fieldset>
          </form>
      </div>

      <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='title']='xmlui.general.dspace_home'">

      <div class="explanatorytabs">
        <ul class="nav nav-tabs">
          <li class="active"><a data-toggle="tab" href="#home">Overview</a></li>
          <li><a data-toggle="tab" href="#menu1">Scholarly Communication</a></li>
          <li><a data-toggle="tab" href="#menu2">Copyright</a></li>
          <li><a data-toggle="tab" href="#menu3">FAQ</a></li>
        </ul>

        <div class="tab-content">
          <div id="home" class="tab-pane fade in active">
            <div class="row">
              <div class="col-md-9">
                <p class="intro">Scholars' Bank is the open access repository for the intellectual work of faculty, students, and staff at the University of Oregon. It also houses materials from certain partner institution collections. Open access <b>journals, student projects, theses, dissertations, pre- and post-print articles, instructional resources</b>, and <b>university archival material</b> are all candidates for deposit.<br />
                <a href="http://library.uoregon.edu/diglib/irg/sb-dissertations" class="cta-button" role="button" aria-label="More about Scholars' Bank">More About Scholars' Bank</a></p>
              </div>
              <div class="col-md-3 hidden-sm hidden-xs">
                <img src="{$theme-path}images/open.svg" class="img-responsive center-block"/>
              </div>
            </div>
          </div>
          <div id="menu1" class="tab-pane fade">
            <div class="row">
              <div class="col-md-9">
                <p class="intro">Scholarly communication is considered by many to be in a state of crisis. Rising journal prices, the increasing difficulty that scholars in some disciplines face in getting articles published, and growing lag times between article submission, acceptance, and publication are causing many to look around for other options.<br />
                <a href="http://library.uoregon.edu/diglib/irg/sb-dissertations" class="cta-button" role="button" aria-label="More about Scholars' Communication">Scholarly Communication</a></p>
              </div>
              <div class="col-md-3 hidden-sm hidden-xs">
                <img src="{$theme-path}images/scholarly.svg" class="img-responsive center-block"/>
              </div>
            </div>
          </div>
          <div id="menu2" class="tab-pane fade">
            <div class="row">
              <div class="col-md-9">
                <p class="intro"><b>Authors who submit their research to Scholars' Bank retain their copyright</b> unless they explicitly give it away to a third party. The University of Oregon Libraries does not seek nor claim copyright on work submitted to Scholars' Bank. The Libraries ask authors to agree to a <a href="http://library.uoregon.edu/digitalscholarship/irg/SBlicense.html">non-exclusive distribution license</a>.<br />
                <a href="http://library.uoregon.edu/digitalscholarship/irg/SB_Copyright.html" class="cta-button" role="button" aria-label="More about Copyright">More About Copyright</a></p>
              </div>
              <div class="col-md-3 hidden-sm hidden-xs">
                <img src="{$theme-path}images/copyright.svg" class="img-responsive center-block" />
              </div>
            </div>
          </div>
          <div id="menu3" class="tab-pane fade">
            <div class="row">
              <div class="col-md-9">
                <p class="intro">Scholars' Bank is a digital archive for the scholarly output of the University of Oregon community. Its mission is to preserve and disseminate the intellectual output of the University of Oregon's faculty, staff, and students.<br /><br />
                Please <a href="mailto:scholars.uoregon.edu">contact us</a> with any questions not addressed in the <a href="http://library.uoregon.edu/digitalscholarship/SB_FAQ.html">FAQ</a>.<a href="http://library.uoregon.edu/digitalscholarship/SB_FAQ.html" class="cta-button" role="button" aria-label="Frequently Asked Questions">Frequently Asked Questions</a></p>
              </div>
              <div class="col-md-3 hidden-sm hidden-xs">
                <img src="{$theme-path}images/faq.svg" class="img-responsive center-block"/>
              </div>
            </div>
          </div>
        </div>
      </div>


      <!--div class="flex-grid">
        <div class="col">
          <a href="http://library.uoregon.edu/digitalscholarship/irg/SB_Copyright.html" class="cta-button" role="button" aria-label="More about Copyright">Journals</a>
        </div>
        <div class="col">
          <a href="http://library.uoregon.edu/digitalscholarship/irg/SB_Copyright.html" class="cta-button" role="button" aria-label="More about Copyright">Articles</a>
        </div>
      </div-->
            <!--button id="btn1">Set Text</button-->
            <!--script>

                $(document).ready(function(){
                    $("#btn1").click(function(){
                        $("p.intro").text("Hello world!");
                    });
                });

                function jsonCallback(json){
                  console.log(json);
                }

                //$.ajax({
                //  url: "https://library.uoregon.edu/scholars-bank-page-feed?callback=scholarsBank",
                //  dataType: "application/json",
                //  jsonpCallback: "scholarsBank"
                //});
            </script-->

            <!--div id="testy">testy</div-->

            <!--script>
                //$('#testy').load('http://library.uoregon.edu/digitalscholarship/Faculty_Resources.html #testme');

                $.ajax({
                    url:'https://library.uoregon.edu/digitalscholarship/Faculty_Resources.html',
                    type:'GET',
                    success: function(data){
                        $('#testy').html($(data).find('#testme').html());
                    }
                });
            </script-->

        </xsl:if>

        <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='request'][@qualifier='URI']/text()">
            <xsl:apply-templates />
        </xsl:if>
    </xsl:template>

    <!--The Language Selection-->
    <xsl:template name="languageSelection">
        <xsl:if test="count(/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='page'][@qualifier='supportedLocale']) &gt; 1">
            <li id="ds-language-selection" class="dropdown">
                <xsl:variable name="active-locale" select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='page'][@qualifier='currentLocale']"/>
                <a id="language-dropdown-toggle" href="#" role="button" class="dropdown-toggle" data-toggle="dropdown">
                    <span class="hidden-xs">
                        <xsl:value-of
                                select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='supportedLocale'][@qualifier=$active-locale]"/>
                        <xsl:text>&#160;</xsl:text>
                        <b class="caret"/>
                    </span>
                </a>
                <ul class="dropdown-menu pull-right" role="menu" aria-labelledby="language-dropdown-toggle" data-no-collapse="true">
                    <xsl:for-each
                            select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='page'][@qualifier='supportedLocale']">
                        <xsl:variable name="locale" select="."/>
                        <li role="presentation">
                            <xsl:if test="$locale = $active-locale">
                                <xsl:attribute name="class">
                                    <xsl:text>disabled</xsl:text>
                                </xsl:attribute>
                            </xsl:if>
                            <a>
                                <xsl:attribute name="href">
                                    <xsl:value-of select="$current-uri"/>
                                    <xsl:text>?locale-attribute=</xsl:text>
                                    <xsl:value-of select="$locale"/>
                                </xsl:attribute>
                                <xsl:value-of
                                        select="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='supportedLocale'][@qualifier=$locale]"/>
                            </a>
                        </li>
                    </xsl:for-each>
                </ul>
            </li>
        </xsl:if>
    </xsl:template>


    <!-- this is called when the front page is put together. intercept the call for normal rendering of community browser that has a front page search sibling (need to match on the sibling or this will break the separate community list page) -->
    <xsl:template match="dri:div[@id='aspect.artifactbrowser.CommunityBrowser.div.comunity-browser'][../dri:div[@id='aspect.discovery.SiteViewer.div.front-page-search']]">
      <!-- render front page search first -->
      <xsl:apply-templates select="../dri:div[@id='aspect.discovery.SiteViewer.div.front-page-search']" mode="do-render"/>
      <!-- then render community list - the mode is used to call the real template -->
      <xsl:apply-templates select="." mode="do-render"/>
    </xsl:template>

    <!-- remove the original front page search box -->
    <xsl:template match="dri:div[@id='aspect.discovery.SiteViewer.div.front-page-search']">
      <!-- do nothing unless we're in "do-render" mode (to avoid duplicates) -->
    </xsl:template>

    <!-- put the front page search back in - copied from lib/xsl/core/elements.xsl in dri2html-alt theme -->
    <xsl:template match="dri:div[@id='aspect.discovery.SiteViewer.div.front-page-search']" mode="do-render">
        <xsl:apply-templates select="dri:head"/>
        <xsl:apply-templates select="@pagination">
            <xsl:with-param name="position">top</xsl:with-param>
        </xsl:apply-templates>
        <form>
            <xsl:call-template name="standardAttributes">
                <xsl:with-param name="class">ds-interactive-div</xsl:with-param>
            </xsl:call-template>
            <xsl:attribute name="action"><xsl:value-of select="@action"/></xsl:attribute>
            <xsl:attribute name="method"><xsl:value-of select="@method"/></xsl:attribute>
            <xsl:if test="@method='multipart'">
                <xsl:attribute name="method">post</xsl:attribute>
                <xsl:attribute name="enctype">multipart/form-data</xsl:attribute>
            </xsl:if>
            <xsl:attribute name="onsubmit">javascript:tSubmit(this);</xsl:attribute>
                        <!--For Item Submission process, disable ability to submit a form by pressing 'Enter'-->
                        <xsl:if test="starts-with(@n,'submit')">
                                <xsl:attribute name="onkeydown">javascript:return disableEnterKey(event);</xsl:attribute>
            </xsl:if>
                        <xsl:apply-templates select="*[not(name()='head')]"/>

        </form>
        <!-- JS to scroll form to DIV parent of "Add" button if jump-to -->
        <xsl:if test="/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='page'][@qualifier='jumpTo']">
          <script type="text/javascript">
            <xsl:text>var button = document.getElementById('</xsl:text>
            <xsl:value-of select="translate(@id,'.','_')"/>
            <xsl:text>').elements['</xsl:text>
            <xsl:value-of select="concat('submit_',/dri:document/dri:meta/dri:pageMeta/dri:metadata[@element='page'][@qualifier='jumpTo'],'_add')"/>
            <xsl:text>'];</xsl:text>
            <xsl:text>
                      if (button != null) {
                        var n = button.parentNode;
                        for (; n != null; n = n.parentNode) {
                            if (n.tagName == 'DIV') {
                              n.scrollIntoView(false);
                              break;
                           }
                        }
                      }
            </xsl:text>
          </script>
        </xsl:if>
        <xsl:apply-templates select="@pagination">
            <xsl:with-param name="position">bottom</xsl:with-param>
        </xsl:apply-templates>
    </xsl:template>


        <!-- put the community list back in - copied from lib/xsl/core/elements.xsl in dri2html-alt theme -->
        <xsl:template match="dri:div[@id='aspect.artifactbrowser.CommunityBrowser.div.comunity-browser']" mode="do-render">
            <xsl:apply-templates select="dri:head"/>
            <xsl:apply-templates select="@pagination">
                <xsl:with-param name="position">top</xsl:with-param>
            </xsl:apply-templates>
            <div>
                <xsl:call-template name="standardAttributes">
                    <xsl:with-param name="class">ds-static-div</xsl:with-param>
                </xsl:call-template>
                <xsl:choose>
                        <!-- does this element have any children -->
                            <xsl:when test="child::node()">
                                    <xsl:apply-templates select="*[not(name()='head')]"/>
                        </xsl:when>
                            <!-- if no children are found we add a space to eliminate self closing tags -->
                            <xsl:otherwise>
                                    &#160;
                            </xsl:otherwise>
                    </xsl:choose>
            </div>
            <xsl:apply-templates select="@pagination">
                <xsl:with-param name="position">bottom</xsl:with-param>
            </xsl:apply-templates>
        </xsl:template>

</xsl:stylesheet>
