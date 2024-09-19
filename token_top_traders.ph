from flask import Flask, request, jsonify
from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support import expected_conditions as EC
import logging
import time  

app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)

def get_data_from_page(url):
    logging.debug('Starting get_data_from_page function.')

    # Set headless to False to view browser window and increase wait times for page load
    options = Options()
    options.headless = True  # Keep browser visible for debugging
    options.add_argument('--disable-gpu')  # Disables GPU hardware acceleration, often helps with stability
    options.add_argument('--no-sandbox')   # Helps in environments like Docker, where sandboxing might cause issues
    options.add_argument('--disable-dev-shm-usage')  # Useful in environments with limited shared memory
    options.add_argument('--remote-debugging-port=9222')  # Adds debugging port for Chrome

    # Start WebDriver instance with these options
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)

    try:
        driver.get(url)
        logging.debug(f'Opened URL: {url}')
        #time.sleep(1)
        wait = WebDriverWait(driver, 10)  # Increased to 10 seconds

        # Define the button XPath and wait for it to be clickable
        button_xpath = '//*[@id="root"]/div/main/div/div/div[2]/div/div[2]/div/div[1]/div[1]/div[1]/div/div[1]/button[2]'
        button = wait.until(EC.element_to_be_clickable((By.XPATH, button_xpath)))
        
        button.click()
        # Now wait for the new content (table) to be loaded after clicking the button
        div_table_xpath = '/html/body/div[1]/div/main/div/div/div[2]/div/div[2]/div/div[1]/div[2]/div[2]'
        div_table = wait.until(EC.visibility_of_element_located((By.XPATH, div_table_xpath)))

        # Optional: Scroll into view if the table might be out of the viewport
        driver.execute_script("arguments[0].scrollIntoView(true);", div_table)

        # Get the HTML content of the table to verify it has loaded correctly
        #html_content = div_table.get_attribute('outerHTML')
        
        rows = wait.until(EC.visibility_of_all_elements_located((By.XPATH, ".//div[contains(@class, 'custom-1nvxwu0')]")))

        data = []

        for i, row in enumerate(rows):
            try:
                if not row.find_elements(By.XPATH, ".//div[contains(@class, 'custom-1e9y0rl')]"):
                    continue

                div_pnl = row.find_element(By.XPATH, ".//div[contains(@class, 'custom-1e9y0rl')]")
                pnl_div = div_pnl.text.strip()

                # Check if the address div exists, and skip if not
                if not row.find_elements(By.XPATH, ".//div[contains(@class, 'custom-1dwgrrr')]/a"):
                    continue

                # If the address div is present, extract the address value
                div_address = row.find_element(By.XPATH, ".//div[contains(@class, 'custom-1dwgrrr')]/a")
                url = div_address.get_attribute('href')
                address = url.split('/')[-1]  # Extract the last part of the URL

                # Append the valid data to the list
                data.append({'address': address, 'pnl': pnl_div})
                logging.debug(f'Row {i} - address={address}, pnl={pnl_div}')

                # Terminate the loop if the data length reaches 5
                if len(data) >= 5:
                    break

            except Exception as e:
                logging.error(f'Error in row {i}: {str(e)}')

    except Exception as e:
        logging.error(f'ddddddError occurred: {str(e)}', exc_info=True)
        logging.error(f'Error occurred: {str(e)}')
        raise
    finally:
        driver.quit() 
    return data


@app.route('/scrap', methods=['GET'])
def scrap():
    token = request.args.get('token')
    if not token:
        return jsonify({'error': 'Token parameter is required'}), 400

    url = f'https://dexscreener.com/solana/{token}?embed=1&theme=dark&info=1'
    logging.debug(f'Received request for token: {token}')
    
    try:
        data = get_data_from_page(url)
        logging.debug(f'Retrieved data: {data}')
        return jsonify(data)
    except Exception as e:
        logging.error(f'Error in /scrap route: {str(e)}')
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True)
