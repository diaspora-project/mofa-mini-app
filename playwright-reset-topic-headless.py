import os
import re
import sys
import time
from playwright.sync_api import Playwright, sync_playwright, TimeoutError as PlaywrightTimeoutError


def run(playwright: Playwright) -> None:
    # Get credentials and URL from environment
    BASE_URL = os.getenv("TOPIC_BASE_URL", "http://localhost")
    USERNAME = os.getenv("TOPIC_USERNAME")
    PASSWORD = os.getenv("TOPIC_PASSWORD")

    print(f"Using base URL: {BASE_URL}")
    print(f"Username: {USERNAME}")

    if not USERNAME or not PASSWORD:
        raise EnvironmentError(
            "Missing TOPIC_USERNAME or TOPIC_PASSWORD environment variable."
        )

    try:
        # Launch browser in headless mode with additional options
        browser = playwright.chromium.launch(
            headless=True,
            args=['--disable-dev-shm-usage', '--no-sandbox']
        )
        context = browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        )
        page = context.new_page()

        # Set a longer timeout for network operations
        page.set_default_timeout(60000)  # 60 seconds

        # Navigate to login page
        print("\nNavigating to login page...")
        response = page.goto(f"{BASE_URL}/login")
        if not response or response.status != 200:
            raise Exception(f"Failed to load login page. Status: {response.status if response else 'No response'}")

        # Fill login form
        print("Filling login form...")
        username_input = page.get_by_role("textbox", name="Username")
        password_input = page.get_by_role("textbox", name="Password")
        
        # Wait for form elements and fill them
        username_input.wait_for(state="visible")
        password_input.wait_for(state="visible")
        
        username_input.fill(USERNAME)
        password_input.fill(PASSWORD)
        
        # Click the login button
        print("Logging in...")
        page.keyboard.press("Enter")
        time.sleep(5)  # Wait for login to complete
        
        # Navigate to topics page
        print("\nNavigating to topics page...")
        topics_url = f"{BASE_URL}/ui/clusters/diaspora/all-topics?perPage=25&q=mofa_test2"
        response = page.goto(topics_url)
        if not response or response.status != 200:
            raise Exception(f"Failed to load topics page. Status: {response.status if response else 'No response'}")
        
        time.sleep(5)  # Wait for page to load completely
        
        # Try to find the table multiple times
        max_retries = 3
        for attempt in range(max_retries):
            try:
                print(f"Looking for topics (attempt {attempt + 1}/{max_retries})...")
                matching_rows = page.locator(
                    "role=row", has_text=re.compile(r"^mofa_test2[-_]")
                )
                count = matching_rows.count()
                print(f"Found {count} matching topics.")
                break
            except PlaywrightTimeoutError:
                if attempt == max_retries - 1:
                    raise
                print("Retrying...")
                time.sleep(5)

        # Get all topic names first
        topic_names = []
        for i in range(count):
            row = matching_rows.nth(i)
            # Get the second cell which contains the topic name
            topic_name = row.locator("td").nth(1).text_content()
            topic_name = topic_name.strip()  # Remove any whitespace
            topic_names.append(topic_name)

        print("\nTopics to be recreated:")
        for i, name in enumerate(topic_names, 1):
            print(f"{i}. {name}")
        print()

        for i in range(count):
            try:
                topic_name = topic_names[i]
                print(f"\nRecreating topic {i+1}/{count}: {topic_name}")
                row = matching_rows.nth(i)
                
                # Wait for and click dropdown
                dropdown = row.get_by_label("Dropdown Toggle")
                dropdown.wait_for(state="visible", timeout=10000)
                dropdown.click()
                time.sleep(1)
                
                # Wait for and click recreate option
                recreate_option = page.get_by_role("menuitem", name="Recreate Topic").locator("div")
                recreate_option.wait_for(state="visible", timeout=10000)
                recreate_option.click()
                time.sleep(1)
                
                # Wait for and click confirm button
                confirm_button = page.get_by_role("button", name="Confirm")
                confirm_button.wait_for(state="visible", timeout=10000)
                confirm_button.click()
                
                # Wait for operation to complete
                page.wait_for_load_state("networkidle", timeout=30000)
                print(f"✓ Successfully recreated topic {i+1}/{count}: {topic_name}")
                time.sleep(2)
                
            except PlaywrightTimeoutError as e:
                print(f"⚠️  Timeout occurred while processing topic {i+1}/{count}: {topic_name} - {str(e)}")
                continue
            except Exception as e:
                print(f"⚠️  Error processing topic {i+1}/{count}: {topic_name} - {str(e)}")
                continue

    except Exception as e:
        print(f"\n❌ An error occurred: {str(e)}", file=sys.stderr)
        raise
    finally:
        print("\nClosing browser...")
        if 'context' in locals():
            context.close()
        if 'browser' in locals():
            browser.close()


if __name__ == "__main__":
    with sync_playwright() as playwright:
        run(playwright) 