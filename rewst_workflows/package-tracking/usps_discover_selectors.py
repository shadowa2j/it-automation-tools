#!/usr/bin/env python3
"""
USPS Tracking Page Structure Discovery Script
Run this to dump the rendered HTML and identify CSS selectors for scraping.
"""

import sys
from playwright.sync_api import sync_playwright

def discover_usps_structure(tracking_number: str):
    """Load USPS tracking page and dump rendered HTML for inspection."""
    
    url = f"https://tools.usps.com/go/TrackConfirmAction?tLabels={tracking_number}"
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        page = context.new_page()
        
        print(f"Loading: {url}")
        page.goto(url, wait_until="networkidle")
        
        # Wait a bit for any JS to finish
        page.wait_for_timeout(3000)
        
        # Get the rendered HTML
        html = page.content()
        
        # Save to file for inspection
        with open("/tmp/usps_rendered.html", "w", encoding="utf-8") as f:
            f.write(html)
        
        print(f"\nRendered HTML saved to: /tmp/usps_rendered.html")
        print(f"HTML length: {len(html)} characters")
        
        # Try to find some common tracking-related elements
        print("\n--- Attempting to find tracking elements ---")
        
        # Look for status-related elements
        selectors_to_try = [
            ".tracking-progress-bar-status",
            ".tb-status",
            ".delivery-status",
            ".track-bar-container",
            ".tracking-summary",
            ".status-content",
            ".tb-step",
            "#trackingHistory",
            ".tracking-history",
            ".product-summary",
            ".expected-delivery",
            ".delivery-date"
        ]
        
        for selector in selectors_to_try:
            elements = page.query_selector_all(selector)
            if elements:
                print(f"  FOUND: {selector} ({len(elements)} elements)")
                for i, el in enumerate(elements[:3]):  # Show first 3
                    text = el.inner_text()[:100].replace('\n', ' ')
                    print(f"    [{i}]: {text}...")
        
        browser.close()

if __name__ == "__main__":
    # Use provided tracking number or default test one
    tracking = sys.argv[1] if len(sys.argv) > 1 else "9438340109490000291499"
    discover_usps_structure(tracking)
