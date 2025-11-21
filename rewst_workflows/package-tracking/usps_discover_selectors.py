#!/usr/bin/env python3
"""
USPS Tracking Page Structure Discovery Script v2
Waits longer and tries to bypass basic bot detection.
"""

import sys
from playwright.sync_api import sync_playwright

def discover_usps_structure(tracking_number: str):
    """Load USPS tracking page and dump rendered HTML for inspection."""
    
    url = f"https://tools.usps.com/go/TrackConfirmAction?tLabels={tracking_number}"
    
    with sync_playwright() as p:
        # Use Firefox instead - sometimes works better with anti-bot
        browser = p.firefox.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
            viewport={"width": 1920, "height": 1080},
            locale="en-US",
        )
        page = context.new_page()
        
        print(f"Loading: {url}")
        
        # Navigate and wait for network to settle
        page.goto(url, wait_until="networkidle", timeout=60000)
        
        # Wait longer for JS to execute
        print("Waiting for page to fully render...")
        page.wait_for_timeout(10000)
        
        # Try scrolling to trigger lazy loading
        page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(2000)
        
        # Get the rendered HTML
        html = page.content()
        
        # Save full HTML
        with open("/tmp/usps_rendered.html", "w", encoding="utf-8") as f:
            f.write(html)
        
        print(f"\nRendered HTML saved to: /tmp/usps_rendered.html")
        print(f"HTML length: {len(html)} characters")
        
        # Take a screenshot to see what actually rendered
        page.screenshot(path="/tmp/usps_screenshot.png", full_page=True)
        print("Screenshot saved to: /tmp/usps_screenshot.png")
        
        # Check page title
        title = page.title()
        print(f"Page title: {title}")
        
        # Look for any text content
        body_text = page.inner_text("body")
        print(f"\n--- First 2000 chars of visible text ---")
        print(body_text[:2000] if body_text else "(no text found)")
        
        # Try to find tracking elements with broader selectors
        print("\n--- Searching for elements ---")
        
        selectors_to_try = [
            # Status related
            ".tracking-progress-bar-status",
            ".tb-status", 
            ".delivery-status",
            ".status",
            "[class*='status']",
            "[class*='delivery']",
            "[class*='tracking']",
            # Container related
            ".track-bar-container",
            ".tracking-summary",
            "#tracked-numbers",
            ".product-summary",
            # History related  
            "#trackingHistory",
            ".tracking-history",
            "[class*='history']",
            # Any divs with data
            "div[class*='result']",
            "div[class*='detail']",
            # Text content
            "h1", "h2", "h3",
            ".banner-content",
        ]
        
        for selector in selectors_to_try:
            try:
                elements = page.query_selector_all(selector)
                if elements:
                    print(f"\n  FOUND: {selector} ({len(elements)} elements)")
                    for i, el in enumerate(elements[:2]):
                        text = el.inner_text()[:150].replace('\n', ' ').strip()
                        if text:
                            print(f"    [{i}]: {text}")
            except Exception as e:
                pass
        
        browser.close()

if __name__ == "__main__":
    tracking = sys.argv[1] if len(sys.argv) > 1 else "9438340109490000291499"
    discover_usps_structure(tracking)
