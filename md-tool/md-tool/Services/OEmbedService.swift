import Foundation

enum OEmbedService {

    // MARK: - Public

    /// Convert standalone URL lines (wrapped in <p>URL</p>) to embed HTML
    nonisolated static func convert(_ html: String) -> String {
        let pattern = #"<p>(https?://[^\s<]+)</p>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }

        let mutableHTML = NSMutableString(string: html)
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: mutableHTML.length))

        for match in matches.reversed() {
            let urlRange = match.range(at: 1)
            let urlString = (html as NSString).substring(with: urlRange)

            if let embed = embedHTML(for: urlString) {
                mutableHTML.replaceCharacters(in: match.range, with: embed)
            }
        }

        return mutableHTML as String
    }

    // MARK: - Providers

    private nonisolated static func embedHTML(for urlString: String) -> String? {
        if let videoID = youtubeVideoID(from: urlString) {
            return youtubeEmbed(videoID: videoID)
        }
        if let tweetInfo = twitterTweetInfo(from: urlString) {
            return twitterEmbed(user: tweetInfo.user, statusID: tweetInfo.statusID, url: urlString)
        }
        if let gistPath = gistPath(from: urlString) {
            return gistEmbed(path: gistPath, url: urlString)
        }
        return nil
    }

    // MARK: - YouTube

    private nonisolated static func youtubeVideoID(from urlString: String) -> String? {
        // youtube.com/watch?v=ID
        if let range = urlString.range(of: #"(?:youtube\.com/watch\?.*v=)([\w-]{11})"#, options: .regularExpression) {
            let fullMatch = String(urlString[range])
            if let eqIndex = fullMatch.lastIndex(of: "=") {
                return String(fullMatch[fullMatch.index(after: eqIndex)...])
            }
        }
        // youtu.be/ID
        if let range = urlString.range(of: #"youtu\.be/([\w-]{11})"#, options: .regularExpression) {
            let fullMatch = String(urlString[range])
            if let slashIndex = fullMatch.lastIndex(of: "/") {
                return String(fullMatch[fullMatch.index(after: slashIndex)...])
            }
        }
        return nil
    }

    private nonisolated static func youtubeEmbed(videoID: String) -> String {
        """
        <div class="oembed oembed-youtube">
        <a href="https://www.youtube.com/watch?v=\(videoID)" class="oembed-youtube-link">
        <img src="https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg" alt="YouTube video" loading="lazy">
        <svg class="oembed-youtube-play" viewBox="0 0 68 48"><path d="M66.52 7.74c-.78-2.93-2.49-5.41-5.42-6.19C55.79.13 34 0 34 0S12.21.13 6.9 1.55c-2.93.78-4.64 3.26-5.42 6.19C.06 13.05 0 24 0 24s.06 10.95 1.48 16.26c.78 2.93 2.49 5.41 5.42 6.19C12.21 47.87 34 48 34 48s21.79-.13 27.1-1.55c2.93-.78 4.64-3.26 5.42-6.19C67.94 34.95 68 24 68 24s-.06-10.95-1.48-16.26z" fill="red"/><path d="M45 24L27 14v20" fill="white"/></svg>
        </a>
        </div>
        """
    }

    // MARK: - Twitter/X

    private nonisolated static func twitterTweetInfo(from urlString: String) -> (user: String, statusID: String)? {
        let pattern = #"(?:twitter\.com|x\.com)/(\w+)/status/(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: urlString, range: NSRange(location: 0, length: urlString.utf16.count)) else {
            return nil
        }
        let user = (urlString as NSString).substring(with: match.range(at: 1))
        let statusID = (urlString as NSString).substring(with: match.range(at: 2))
        return (user: user, statusID: statusID)
    }

    private nonisolated static func twitterEmbed(user: String, statusID: String, url: String) -> String {
        """
        <div class="oembed oembed-twitter">
        <blockquote class="twitter-tweet"><a href="\(url)">Tweet by @\(user)</a></blockquote>
        </div>
        """
    }

    // MARK: - GitHub Gist

    private nonisolated static func gistPath(from urlString: String) -> String? {
        let pattern = #"gist\.github\.com/([\w-]+/[\w]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: urlString, range: NSRange(location: 0, length: urlString.utf16.count)) else {
            return nil
        }
        return (urlString as NSString).substring(with: match.range(at: 1))
    }

    private nonisolated static func gistEmbed(path: String, url: String) -> String {
        """
        <div class="oembed oembed-gist">
        <script src="https://gist.github.com/\(path).js"></script>
        <noscript><a href="\(url)">View Gist</a></noscript>
        </div>
        """
    }
}
