import Foundation

enum HTMLTemplateProvider {

    // MARK: - Theme CSS

    static func themeCSS(_ theme: String) -> String {
        switch theme {
        case "github":
            return """
            :root {
                --bg: #ffffff;
                --text: #1F2328;
                --code-bg: #f6f8fa;
                --border: #d0d7de;
                --link: #0969da;
                --blockquote-border: #d0d7de;
                --blockquote-text: #656d76;
                --font-body: -apple-system, "SF Pro Text", system-ui, sans-serif;
                --font-heading: -apple-system, "SF Pro Display", system-ui, sans-serif;
                --font-size: 16px;
                --line-height: 1.5;
                --letter-spacing: 0;
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg: #0d1117;
                    --text: #e6edf3;
                    --code-bg: #161b22;
                    --border: #30363d;
                    --link: #58a6ff;
                    --blockquote-border: #30363d;
                    --blockquote-text: #8b949e;
                }
            }
            h1 { border-bottom: 1px solid var(--border) !important; padding-bottom: 0.3em !important; }
            """
        case "notion":
            return """
            :root {
                --bg: #ffffff;
                --text: #37352f;
                --code-bg: #f7f6f3;
                --border: #e9e9e7;
                --link: #2eaadc;
                --blockquote-border: #e9e9e7;
                --blockquote-text: #787774;
                --font-body: -apple-system, "SF Pro Text", "Hiragino Kaku Gothic ProN", system-ui, sans-serif;
                --font-heading: -apple-system, "SF Pro Display", "Hiragino Kaku Gothic ProN", system-ui, sans-serif;
                --font-size: 16px;
                --line-height: 1.7;
                --letter-spacing: 0;
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg: #191919;
                    --text: #e3e2df;
                    --code-bg: #252525;
                    --border: #363636;
                    --link: #529cca;
                    --blockquote-border: #363636;
                    --blockquote-text: #9b9a97;
                }
            }
            h1 { font-size: 1.875em !important; font-weight: 700 !important; margin-top: 2em !important; }
            h2 { font-size: 1.5em !important; font-weight: 600 !important; border-bottom: none !important; padding-bottom: 0 !important; margin-top: 1.8em !important; }
            h3 { font-size: 1.25em !important; font-weight: 600 !important; margin-top: 1.4em !important; }
            code { font-family: "SFMono-Regular", Menlo, monospace !important; font-size: 0.85em !important; color: #eb5757 !important; background: var(--code-bg) !important; padding: 0.2em 0.4em !important; border-radius: 3px !important; }
            @media (prefers-color-scheme: dark) { code { color: #ff7369 !important; } }
            pre code { color: var(--text) !important; }
            blockquote { border-left: 3px solid var(--text) !important; opacity: 0.7; }
            hr { border-top: 1px solid var(--border) !important; margin: 1.5em 0 !important; }
            a { text-decoration: underline !important; text-underline-offset: 2px !important; }
            a:hover { opacity: 0.7 !important; }
            """
        case "minimal":
            return """
            :root {
                --bg: #fafafa;
                --text: #333333;
                --code-bg: #f0f0f0;
                --border: #e0e0e0;
                --link: #555555;
                --blockquote-border: #cccccc;
                --blockquote-text: #777777;
                --font-body: "Georgia", "Hiragino Mincho ProN", serif;
                --font-heading: "Georgia", "Hiragino Mincho ProN", serif;
                --font-size: 17px;
                --line-height: 2.0;
                --letter-spacing: 0.02em;
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg: #1a1a1a;
                    --text: #d4d4d4;
                    --code-bg: #2a2a2a;
                    --border: #3a3a3a;
                    --link: #999999;
                    --blockquote-border: #444444;
                    --blockquote-text: #888888;
                }
            }
            h1, h2, h3, h4, h5, h6 { font-weight: 400 !important; }
            h2 { border-bottom: none !important; }
            """
        case "technical":
            return """
            :root {
                --bg: #f8f9fa;
                --text: #212529;
                --code-bg: #e9ecef;
                --border: #ced4da;
                --link: #0d6efd;
                --blockquote-border: #6c757d;
                --blockquote-text: #6c757d;
                --font-body: "SF Mono", Menlo, "Hiragino Kaku Gothic ProN", monospace;
                --font-heading: "SF Mono", Menlo, "Hiragino Kaku Gothic ProN", monospace;
                --font-size: 14px;
                --line-height: 1.6;
                --letter-spacing: 0;
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg: #1e1e1e;
                    --text: #d4d4d4;
                    --code-bg: #2d2d2d;
                    --border: #404040;
                    --link: #4fc1ff;
                    --blockquote-border: #555555;
                    --blockquote-text: #969696;
                }
            }
            """
        default: // "default"
            return """
            :root {
                --bg: #FFFBF7;
                --text: #2C2C2C;
                --code-bg: #F5F2F0;
                --border: #E0DCD8;
                --link: #0969DA;
                --blockquote-border: #D0D7DE;
                --blockquote-text: #656D76;
                --font-body: "Hiragino Kaku Gothic ProN", "Hiragino Sans", -apple-system, "SF Pro Text", system-ui, sans-serif;
                --font-heading: "Hiragino Kaku Gothic ProN", "Hiragino Sans", -apple-system, "SF Pro Display", system-ui, sans-serif;
                --font-size: 16px;
                --line-height: 1.8;
                --letter-spacing: 0.03em;
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg: #2D2D2D;
                    --text: #E0E0E0;
                    --code-bg: #383838;
                    --border: #484848;
                    --link: #58A6FF;
                    --blockquote-border: #505050;
                    --blockquote-text: #A0A0A0;
                }
            }
            """
        }
    }

    // MARK: - Layout CSS

    static let layoutCSS = """
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: var(--font-body);
        font-size: var(--font-size);
        line-height: var(--line-height);
        letter-spacing: var(--letter-spacing);
        color: var(--text);
        background-color: var(--bg);
        -webkit-font-smoothing: antialiased;
    }

    .markdown-body {
        max-width: none;
        margin: 0;
        padding: 48px 56px;
    }

    h1, h2, h3, h4, h5, h6 {
        font-family: var(--font-heading);
        margin-top: 1.5em;
        margin-bottom: 0.8em;
        letter-spacing: -0.01em;
        line-height: 1.3;
    }

    h1 { font-size: 1.875em; font-weight: 700; border-bottom: none; padding-bottom: 0; margin-top: 1.08em; }
    h2 { font-size: 1.5em; font-weight: 700; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; margin-top: 1.1em; }
    h3 { font-size: 1.25em; font-weight: 600; margin-top: 1em; }
    h4 { font-size: 1em; font-weight: 600; margin-top: 1em; }

    h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }

    p { margin-bottom: 1em; }

    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }

    code {
        font-family: "SF Mono", Menlo, monospace;
        font-size: 0.85em;
        background-color: var(--code-bg);
        padding: 0.2em 0.4em;
        border-radius: 4px;
    }

    pre {
        margin-bottom: 1em;
        padding: 16px;
        background-color: var(--code-bg);
        border-radius: 8px;
        overflow-x: auto;
    }

    pre code {
        padding: 0;
        background: none;
        font-size: 13px;
        line-height: 1.6;
    }

    blockquote {
        margin-bottom: 0.8em;
        padding: 0.25em 1.2em;
        border-left: 3px solid var(--blockquote-border);
        color: var(--blockquote-text);
        font-size: 0.95em;
    }

    blockquote p:last-child { margin-bottom: 0; }

    ul, ol {
        margin-bottom: 0.6em;
        padding-left: 1.7em;
    }

    li { margin-bottom: 0.05em; line-height: 1.6; }
    li > ul, li > ol { margin-bottom: 0; margin-top: 0.05em; }

    hr {
        margin: 2em 0;
        border: none;
        border-top: 1px solid var(--border);
    }

    img {
        max-width: 100%;
        height: auto;
        border-radius: 4px;
    }

    table {
        width: 100%;
        margin-bottom: 1em;
        border-collapse: collapse;
    }

    th, td {
        padding: 8px 12px;
        border: 1px solid var(--border);
        text-align: left;
    }

    th {
        font-weight: 600;
        background-color: var(--code-bg);
    }

    input[type="checkbox"] {
        margin-right: 0.5em;
    }

    .toc-sidebar {
        position: fixed;
        top: 16px;
        right: 12px;
        width: 220px;
        max-height: calc(100vh - 32px);
        overflow-y: auto;
        border-left: 2px solid var(--border);
        padding-left: 10px;
        scrollbar-width: none;
    }

    .toc-sidebar::-webkit-scrollbar {
        display: none;
    }

    .toc-sidebar .toc-title {
        font-weight: 600;
        font-size: 11px;
        margin-bottom: 6px;
        color: var(--text);
        opacity: 0.5;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }

    .toc-sidebar ul {
        list-style: none;
        padding-left: 0;
        margin: 0;
    }

    .toc-sidebar ul ul {
        padding-left: 0.7em;
    }

    .toc-sidebar li {
        margin-bottom: 0;
        line-height: 1.4;
    }

    .toc-sidebar a {
        color: var(--text);
        opacity: 0.4;
        text-decoration: none;
        display: block;
        padding: 1.5px 0;
        transition: opacity 0.15s, color 0.15s;
        font-size: 11px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .toc-sidebar a:hover {
        opacity: 0.8;
        text-decoration: none;
    }

    .toc-sidebar a.active {
        opacity: 1;
        color: var(--link);
        font-weight: 600;
    }

    .markdown-body {
        margin-right: 248px;
    }

    body.toc-hidden .toc-sidebar {
        display: none;
    }

    body.toc-hidden .markdown-body {
        margin-right: 0;
    }

    @media (max-width: 700px) {
        .toc-sidebar { display: none; }
        .markdown-body { margin-right: 0; }
    }

    h1, h2, h3, h4, h5, h6 {
        scroll-margin-top: 1em;
    }

    pre.mermaid {
        background: none;
        border: none;
        padding: 1em 0;
        text-align: center;
    }

    .katex-display {
        margin: 1em 0;
        overflow-x: auto;
    }

    .footnotes {
        margin-top: 2em;
        padding-top: 1em;
        border-top: 1px solid var(--border);
        font-size: 0.9em;
    }

    .footnotes ol {
        padding-left: 1.5em;
    }

    .footnote-ref {
        font-size: 0.75em;
        vertical-align: super;
        line-height: 0;
        text-decoration: none;
    }

    .footnote-backref {
        text-decoration: none;
        margin-left: 0.3em;
    }

    .heading-warnings {
        background: #fff3cd;
        border: 1px solid #ffc107;
        border-radius: 6px;
        padding: 8px 12px;
        margin-bottom: 1em;
        font-size: 0.85em;
    }

    @media (prefers-color-scheme: dark) {
        .heading-warnings {
            background: #3d3200;
            border-color: #665500;
        }
    }

    .heading-warnings summary {
        cursor: pointer;
        font-weight: 600;
        color: #856404;
    }

    @media (prefers-color-scheme: dark) {
        .heading-warnings summary { color: #ffc107; }
    }

    .heading-warnings ul {
        margin-top: 6px;
        padding-left: 1.5em;
        list-style: disc;
    }

    .heading-warnings li {
        margin-bottom: 2px;
    }

    h1, h2, h3, h4, h5, h6 {
        position: relative;
    }

    .section-copy-btn {
        opacity: 0;
        transition: opacity 0.2s, transform 0.15s;
        cursor: pointer;
        background: none;
        border: none;
        padding: 0;
        margin-left: 6px;
        vertical-align: middle;
        line-height: 1;
        display: inline-flex;
        align-items: center;
        color: var(--text);
    }

    .section-copy-btn svg {
        width: 14px;
        height: 14px;
        opacity: 0.35;
        transition: opacity 0.15s;
    }

    h1:hover .section-copy-btn,
    h2:hover .section-copy-btn,
    h3:hover .section-copy-btn,
    h4:hover .section-copy-btn,
    h5:hover .section-copy-btn,
    h6:hover .section-copy-btn {
        opacity: 1;
    }

    .section-copy-btn:hover svg {
        opacity: 0.7;
    }

    .section-copy-btn:active svg {
        transform: scale(0.9);
    }

    .section-copy-btn.copied svg {
        opacity: 1;
        color: var(--link);
    }

    .broken-link {
        color: #dc3545 !important;
        text-decoration: line-through wavy !important;
    }

    /* Front Matter metadata */
    .front-matter {
        margin-bottom: 1.5em;
        border: 1px solid var(--border);
        border-radius: 8px;
        background: color-mix(in srgb, var(--code-bg) 60%, var(--bg));
        font-size: 0.85em;
        overflow: hidden;
    }

    .front-matter details {
        padding: 0;
    }

    .front-matter summary {
        cursor: pointer;
        font-weight: 600;
        font-size: 0.8em;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: var(--text);
        opacity: 0.5;
        padding: 10px 14px;
        user-select: none;
    }

    .front-matter summary:hover {
        opacity: 0.8;
    }

    .front-matter table {
        width: 100%;
        border-collapse: collapse;
        margin: 0;
        border-top: 1px solid var(--border);
    }

    .front-matter th,
    .front-matter td {
        padding: 6px 14px;
        border: none;
        border-bottom: 1px solid color-mix(in srgb, var(--border) 50%, transparent);
        vertical-align: top;
    }

    .front-matter tr:last-child th,
    .front-matter tr:last-child td {
        border-bottom: none;
    }

    .front-matter th {
        width: 120px;
        font-weight: 600;
        font-size: 0.9em;
        color: var(--text);
        opacity: 0.6;
        background: none;
        text-align: right;
        white-space: nowrap;
    }

    .front-matter td {
        color: var(--text);
        opacity: 0.85;
    }

    .front-matter-tag {
        display: inline-block;
        background: color-mix(in srgb, var(--link) 12%, transparent);
        color: var(--link);
        padding: 1px 8px;
        border-radius: 10px;
        font-size: 0.9em;
        margin: 1px 3px 1px 0;
    }

    /* Callout / Admonition */
    .callout {
        margin-bottom: 1em;
        border-radius: 6px;
        border-left: 4px solid;
        overflow: hidden;
    }

    .callout .callout-title {
        font-weight: 600;
        font-size: 0.95em;
        padding: 8px 12px;
        display: flex;
        align-items: center;
        gap: 6px;
    }

    .callout .callout-icon {
        font-size: 1.1em;
        line-height: 1;
    }

    .callout .callout-body {
        padding: 4px 12px 8px 12px;
        font-size: 0.95em;
    }

    .callout .callout-body p:last-child {
        margin-bottom: 0;
    }

    /* Collapsible callout */
    .callout-collapsible details summary {
        cursor: pointer;
        list-style: none;
    }

    .callout-collapsible details summary::-webkit-details-marker {
        display: none;
    }

    .callout-collapsible details summary::after {
        content: "\\25B6";
        font-size: 0.7em;
        margin-left: auto;
        transition: transform 0.2s;
    }

    .callout-collapsible details[open] summary::after {
        transform: rotate(90deg);
    }

    /* NOTE - blue */
    .callout-note {
        border-left-color: #4393e5;
        background: rgba(67, 147, 229, 0.08);
    }
    .callout-note .callout-title { color: #4393e5; }

    /* TIP - green */
    .callout-tip {
        border-left-color: #3fb950;
        background: rgba(63, 185, 80, 0.08);
    }
    .callout-tip .callout-title { color: #3fb950; }

    /* WARNING - yellow */
    .callout-warning {
        border-left-color: #d29922;
        background: rgba(210, 153, 34, 0.08);
    }
    .callout-warning .callout-title { color: #d29922; }

    /* IMPORTANT - purple */
    .callout-important {
        border-left-color: #a371f7;
        background: rgba(163, 113, 247, 0.08);
    }
    .callout-important .callout-title { color: #a371f7; }

    /* CAUTION - red */
    .callout-caution {
        border-left-color: #f85149;
        background: rgba(248, 81, 73, 0.08);
    }
    .callout-caution .callout-title { color: #f85149; }

    @media (prefers-color-scheme: dark) {
        .callout-note { background: rgba(67, 147, 229, 0.12); }
        .callout-tip { background: rgba(63, 185, 80, 0.12); }
        .callout-warning { background: rgba(210, 153, 34, 0.12); }
        .callout-important { background: rgba(163, 113, 247, 0.12); }
        .callout-caution { background: rgba(248, 81, 73, 0.12); }
    }

    /* oEmbed */
    .oembed {
        margin-bottom: 1em;
    }

    .oembed-youtube {
        position: relative;
        display: inline-block;
        max-width: 100%;
    }

    .oembed-youtube-link {
        position: relative;
        display: block;
    }

    .oembed-youtube-link img {
        display: block;
        max-width: 100%;
        height: auto;
        border-radius: 8px;
    }

    .oembed-youtube-play {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        width: 68px;
        height: 48px;
        opacity: 0.8;
        transition: opacity 0.2s;
        filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
    }

    .oembed-youtube-link:hover .oembed-youtube-play {
        opacity: 1;
    }

    .oembed-twitter {
        max-width: 550px;
    }

    .oembed-gist {
        overflow-x: auto;
    }
    """

    // MARK: - Custom CSS

    static var customCSS: String {
        guard let path = UserDefaults.standard.string(forKey: "customCSSPath"),
              !path.isEmpty,
              let css = try? String(contentsOfFile: path, encoding: .utf8) else {
            return ""
        }
        return css
    }

    // MARK: - Export HTML Template

    static func exportHTMLTemplate(_ body: String, theme: String, showTOC: Bool) -> String {
        let exportCSS = """
        .section-copy-btn { display: none !important; }
        .toc-sidebar { display: none !important; }
        .markdown-body { margin-right: 0 !important; }
        """
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(themeCSS(theme))
        \(layoutCSS)
        \(customCSS)
        \(exportCSS)
        </style>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        </head>
        <body class="toc-hidden">
        <article class="markdown-body">
        \(body)
        </article>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body, {delimiters: [{left: '$$', right: '$$', display: true}, {left: '$', right: '$', display: false}], throwOnError: false});"></script>
        <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true, theme: 'default' });
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Quick Look Template (no KaTeX/Mermaid, default theme, no TOC)

    static func quickLookTemplate(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(themeCSS("default"))
        \(layoutCSS)
        .toc-sidebar { display: none !important; }
        .markdown-body { margin-right: 0 !important; }
        .section-copy-btn { display: none !important; }
        .heading-warnings { display: none !important; }
        </style>
        </head>
        <body class="toc-hidden">
        <article class="markdown-body">
        \(body)
        </article>
        </body>
        </html>
        """
    }
}
