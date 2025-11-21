#!/usr/bin/env python3
"""
17track.net Tracking Scraper - Discovery Script
Tests if we can scrape tracking data from 17track.net
"""

import sys
from playwright.sync_api import sync_playwright
from playwright_stealth import Stealth

def discover_17track_structure(tracking_number: str):
    """Load 17track page and dump rendered HTML for inspection."""
    
    url = f"https://t.17track.net/en#nums={tracking_number}"
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        context = browser.new_context(
            viewport={"width": 1920, "height": 1080},
            locale="en-US",
        )
        page = context.new_page()
        
        # Apply stealth
        Stealth().apply_stealth_sync(page)
        
        print(f"Loading: {url}")
        
        page.goto(url, wait_until="networkidle", timeout=60000)
        
        # Wait for page to render
        print("Waiting for page to fully render...")
        page.wait_for_timeout(5000)
        
        # Look for a search/track button and click it if needed
        try:
            track_btn = page.query_selector("button[class*='track'], input[type='submit'], .search-btn, #search-btn")
            if track_btn:
                print("Found track button, clicking...")
                track_btn.click()
                page.wait_for_timeout(5000)
        except:
            pass
        
        # Wait longer for results
        page.wait_for_timeout(5000)
        
        # Get the rendered HTML
        html = page.content()
        
        # Save full HTML
        with open("/tmp/17track_rendered.html", "w", encoding="utf-8") as f:
            f.write(html)
        
        print(f"\nRendered HTML saved to: /tmp/17track_rendered.html")
        print(f"HTML length: {len(html)} characters")
        
        # Take a screenshot
        page.screenshot(path="/tmp/17track_screenshot.png", full_page=True)
        print("Screenshot saved to: /tmp/17track_screenshot.png")
        
        # Check page title
        title = page.title()
        print(f"Page title: {title}")
        
        # Look for any text content
        body_text = page.inner_text("body")
        print(f"\n--- First 2000 chars of visible text ---")
        print(body_text[:2000] if body_text else "(no text found)")
        
        # Try to find tracking elements
        print("\n--- Searching for elements ---")
        
        selectors_to_try = [
            "[class*='status']",
            "[class*='track']",
            "[class*='result']",
            "[class*='event']",
            "[class*='detail']",
            "[class*='info']",
            ".carrier",
            ".timeline",
            "h1", "h2", "h3",
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
            except Exception:
                pass
        
        browser.close()

if __name__ == "__main__":
    tracking = sys.argv[1] if len(sys.argv) > 1 else "9438340109490000291499"
    discover_17track_structure(tracking)
