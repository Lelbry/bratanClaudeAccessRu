// claude-proxy.pac
// Системный PAC-скрипт: только домены Anthropic/Claude идут через наш
// туннель (127.0.0.1:8888), весь остальной интернет — напрямую.
// Используется Windows System Proxy, поэтому работает и для Claude
// Desktop (Microsoft Store, без своего exe), и для любых других
// приложений, которые читают системные настройки прокси.

function FindProxyForURL(url, host) {
    var domains = [
        "claude.ai",
        "anthropic.com"
    ];

    for (var i = 0; i < domains.length; i++) {
        var d = domains[i];
        if (host == d || dnsDomainIs(host, "." + d)) {
            // БЕЗ "; DIRECT" fallback: claude.ai / anthropic.com гео-заблокированы
            // из РФ. Если после проксятины поставить DIRECT, то при любом
            // моргании туннеля Chromium (Claude Desktop) молча уходит напрямую
            // через WARP (loc=RU) -> "app-unavailable-in-region", и кеширует
            // это состояние. Лучше честно не открыться, пока туннель не поднят.
            return "PROXY 127.0.0.1:8888";
        }
    }

    return "DIRECT";
}
