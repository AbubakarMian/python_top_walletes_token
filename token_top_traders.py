from flask import Flask, request, jsonify
from playwright.sync_api import sync_playwright
import logging
import asyncio
import time

app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)

def get_data_from_page(url, limit):
    logging.debug('Starting get_data_from_page function.')

    with sync_playwright() as p:
        #browser = p.chromium.launch(headless=True)
        browser = p.chromium.launch(headless=False, args=[
            '--no-sandbox',  # Disables the sandboxing for security (needed for some server environments)
            '--disable-setuid-sandbox',
            '--disable-blink-features=AutomationControlled',  # Disable automation features to avoid detection
            '--disable-dev-shm-usage',
            '--disable-gpu',  # Disable GPU acceleration,
            '--window-size=1280,720'
        ])

        page = browser.new_page()
        #, wait_until='networkidle'
        #page.set_user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")

        page.goto(url)
        logging.debug(f'Opened URL: {url}')

        button_xpath = '//*[@id="root"]/div/main/div/div/div[2]/div/div[2]/div/div[1]/div[1]/div[1]/div/div[1]/button[2]'
        page.wait_for_selector(button_xpath)
        page.click(button_xpath)
        logging.debug('Button clicked')

        html_content = page.content()
        logging.debug(html_content)
        logging.debug('html end Button clicked')
        # Wait for the new data to load
        div_table_xpath = "//html/body/div[1]/div/main/div/div/div[2]/div/div[2]/div/div[1]/div[2]/div[2]"
        # page.wait_for_selector(div_table_xpath)
        retries = 5
        for attempt in range(retries):
            if page.locator(div_table_xpath).count() > 0:
                
                logging.debug(f'Table found on attempt {attempt + 1}')
                break
            else:
                logging.debug(f'Table not found on attempt {attempt + 1}, retrying in 1 second...')
                page.evaluate(f"document.evaluate('{button_xpath}', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.click();")
                time.sleep(1)
        else:
            logging.error("Table not found after 5 attempts.")
            return []
        
        #page.wait_for_selector("div.custom-1nvxwu0")
        #page.wait_for_selector("div.custom-1nvxwu0", timeout=120000)
        rows = page.locator("div.custom-1nvxwu0")
        logging.debug(f'rows count: {rows.count()}')
        data = []

        for i in range(rows.count()):
            try:
                pnl_div = rows.nth(i).locator('div.custom-1e9y0rl')
                address_div = rows.nth(i).locator('div.custom-1dwgrrr a')

                if pnl_div.count() > 0 and address_div.count() > 0:
                    pnl_value = pnl_div.inner_text().strip()
                    address = address_div.get_attribute('href').split('/')[-1]
                    data.append({'address': address, 'pnl': pnl_value})
                    logging.debug(f'Row {i} - address={address}, pnl={pnl_value}')

                    if len(data) >= limit:
                        break
            except Exception as e:
                logging.error(f'Error in row {i}: {str(e)}')

        browser.close()
    return data


@app.route('/scrap', methods=['GET'])
def scrap():
    token = request.args.get('token')
    limit = request.args.get('limit', 5)

    if not token:
        return jsonify({'error': 'Token parameter is required'}), 400

    try:
        limit = int(limit)
        if limit <= 0:
            raise ValueError('Limit must be a positive integer')
    except ValueError:
        return jsonify({'error': 'Limit must be a valid positive integer'}), 400

    url = f'https://dexscreener.com/solana/{token}?embed=1&theme=dark&info=1'
    logging.debug(f'Received request for token: {token} with limit: {limit}')

    try:
        data = get_data_from_page(url, limit)
        logging.debug(f'Retrieved data: {data}')
        return jsonify(data)
    except Exception as e:
        logging.error(f'Error in /scrap route: {str(e)}')
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
